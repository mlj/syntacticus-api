require 'json'
require 'fileutils'
require 'csv'

require 'colorize'
require 'ruby-progressbar'
require 'proiel'
require 'proiel/valency'

module PROIEL::Printing
  def self.token_in_context(s, t)
    n = s.tokens.each_with_index.find { |x, i| t == x }.last

    before = s.tokens.each_with_index.select { |x, i| i < n }.map { |x, _| x.printable_form }.join.strip
    after  = s.tokens.each_with_index.select { |x, i| i > n }.map { |x, _| x.printable_form }.join.strip

    [self.left_abbrev(before), self.right_abbrev(after)]
  end

  def self.right_abbrev(s)
    s.length > 30 ? s[0, 30].gsub(/\s\w+\s*$/, '...') : s
  end

  def self.left_abbrev(s)
    s.length > 30 ? s[s.length - 30, 30].gsub(/^\s*\w+/, '...') : s
  end
end

# Methods for identifying homographs
module PROIEL::Homographs
  def self.homographs?(lemma1, lemma2)
    if lemma1.is_a?(String) and lemma2.is_a?(String)
      lemma1 == lemma2
    else
      raise ArgumentError, 'lemmas expected'
    end
  end

  def self.set_homographs!(dictionary)
    m = {}

    dictionary.map do |_, entry|
      m[entry[:lemma]] ||= []
      m[entry[:lemma]] << [entry[:lemma], entry[:part_of_speech]].join(',')
    end

    m.values.each do |encoded_lemmas|
      if encoded_lemmas.length > 1
        encoded_lemmas.each do |encoded_lemma|
          dictionary[encoded_lemma][:homographs] = encoded_lemmas.reject { |e| e == encoded_lemma }
        end
      end
    end
  end
end

module PROIEL::CSV
  def self.read_csv(filename, separator: ',', &block)
    raise ArgumentError, 'filename expected' unless filename.is_a?(String)
    raise ArgumentError, 'file not found' unless File.exists?(filename)

    CSV.foreach(filename, headers: true, encoding: 'utf-8', col_sep: separator) do |row|
      yield OpenStruct.new(row.to_h.map { |k, v| [k.downcase, v] }.to_h)
    end
  end
end

# ----

CHRONOLOGY = {}

PROIEL::CSV.read_csv('lib/dates.tsv', separator: "\t") do |row|
  CHRONOLOGY[row.id] = {
    text: PROIEL::Chronology.midpoint(row.text),
  }
end

PROIEL::CSV.read_csv('lib/orv_text_dates_standard.csv', separator: ';') do |row|
  CHRONOLOGY[row.id] = {
    text: PROIEL::Chronology.midpoint(row.composition),
    ms: PROIEL::Chronology.midpoint(row.manuscript),
  }
end

module DictionaryIndexer
  def self.index!(treebank, version, language, sources)
    gid = GlobalIdentifiers.dictionary_gid(treebank, version, language)

    puts "Indexing #{gid}..."

    lemmata = {}
    sources.each do |source|
      source.tokens.each do |token|
        lemmata[token.lemma] = true if token.lemma
      end
    end

    lemma_count = lemmata.count

    d = Dictionary.create!(gid: gid,
                           language: language,
                           license: 'CC BY-NC-SA 4.0',
                           lemma_count: lemma_count)

    puts "Building valency lexica...".green
    lexica = build_valency_lexica(language, sources)

    dictionaries = {}

    puts "Indexing dictionaries...".green
    sources.each do |source|
      index_dictionary(source, dictionaries)
    end

    puts "Looking for homographs...".green
    dictionaries.each do |_, dictionary|
      PROIEL::Homographs.set_homographs!(dictionary)
    end

    puts "Saving dictionaries...".green
    dictionaries.each do |language, dictionary|
      lexicon = lexica[language]
      pbar = ProgressBar.create progress_mark: 'X', remainder_mark: ' ', title: language, total: dictionary.keys.count

      Dictionary.transaction do
        dictionary.sort_by { |_, data| data[:lemma] }.each do |_, data|
          data[:distribution] =
            data[:distribution].map do |s, n|
              { id: s, n: n, chronology: CHRONOLOGY[s] || { text: 0, ms: 0 } }
            end

          data[:glosses] = get_glosses(language, data[:lemma], data[:part_of_speech])

          if data[:part_of_speech] == 'V-'
            valency = lexicon.lookup(data[:lemma], data[:part_of_speech])

            data[:valency] =
              valency.map do |v|
                partitions =
                  v[:tokens].map do |partition, ids|
                    if ids.empty?
                      nil
                    else
                      GLOBAL_STATE[:frame_id] += 1
                      frame_id = GLOBAL_STATE[:frame_id]
                      ids.each { |t| TOKEN_FRAME_MAP[t] = frame_id }

                      [partition, { frame_id: frame_id, n: ids.length } ]
                    end
                  end.compact.to_h

                { arguments: v[:arguments], partitions: partitions }
              end
          end

          d.lemmas.create! lemma: data[:lemma],
            part_of_speech: data[:part_of_speech],
            glosses: data[:glosses].to_json,
            data: data.to_json,
            language: language

          pbar.increment
        end
      end
    end
  end

  private

  def self.index_token_lemma(language, dictionary, token)
    if token.lemma and token.part_of_speech
      encoded_lemma = [token.lemma, token.part_of_speech].join(',')

      dictionary[encoded_lemma] ||= {
        language: language,
        lemma: token.lemma,
        part_of_speech: token.part_of_speech,
        distribution: {},
        glosses: [],
        homographs: [],
        paradigm: {},
      }

      lemma = dictionary[encoded_lemma]

      lemma[:paradigm][token.morphology] ||= {}
      lemma[:paradigm][token.morphology][token.form] ||= 0
      lemma[:paradigm][token.morphology][token.form] += 1

      lemma[:distribution][token.source.id] ||= 0
      lemma[:distribution][token.source.id] += 1
    end
  end


  def self.build_valency_lexica(language, sources)
    {}.tap do |lexica|
      sources.each do |source|
        next unless source.language == language

        lexica[source.language] ||= PROIEL::Valency::Lexicon.new
        lexica[source.language].add_source!(source)
      end
    end
  end

  def self.index_dictionary(source, dictionaries)
    pbar = ProgressBar.create progress_mark: 'X', remainder_mark: ' ', title: source.id, total: source.tokens.count

    dictionary = (dictionaries[source.language] ||= {})

    source.tokens.each do |token|
      index_token_lemma(source.language, dictionary, token)
      pbar.increment
    end
  end
end

# ----

# TODO
ORV_GLOSSES = {}

# TODO
PROIEL::CSV.read_csv('lib/glosses_checked.csv', separator: ';') do |row|
  key = ['orv', row.lemma, row.pos].join(',')
  STDERR.puts "Warning: repeated gloss #{key}" if ORV_GLOSSES.key?(key)
  ORV_GLOSSES[key] = {
    eng: row.gloss,
    rus: row["russian gloss"]
  }
end

# TODO
def get_glosses(language, lemma, part_of_speech)
  key = [language, lemma, part_of_speech].join(',')

  ORV_GLOSSES[key] || {}
end

GLOBAL_STATE = {
  frame_id: nil
}

# TODO
def self.make_schema(tb)
  {}.tap do |schema|
    schema[:information_status] = tb.annotation_schema.information_status_tags.map { |k, v| [k, v.summary] }.to_h
    schema[:relation] = tb.annotation_schema.relation_tags.map { |k, v| [k, v.summary] }.to_h
    schema[:part_of_speech] = tb.annotation_schema.part_of_speech_tags.map { |k, v| [k, v.summary] }.to_h
    tb.annotation_schema.morphology_tags.each do |k, v|
      schema[k] = v.map { |a, b| [a, b.summary] }.to_h
    end
  end
end

# ---------------------


# TODO
TOKEN_FRAME_MAP = {}

module GlobalIdentifiers
  def self.dictionary_gid(treebank, version, language)
    [treebank, version, language].join(':')
  end

  def self.source_gid(treebank, version, source_xml_id)
    [treebank, version, source_xml_id].join(':')
  end

  def self.sentence_gid(treebank, version, source_xml_id, sentence_xml_id)
    [treebank, version, source_xml_id, sentence_xml_id].join(':')
  end

  def self.token_gid(treebank, version, source_xml_id, sentence_xml_id, token_xml_id)
    [treebank, version, source_xml_id, sentence_xml_id, token_xml_id].join(':')
  end
end

module TokenIndexer
  def self.index!(treebank, version, source, sentence, token)
    abbrev_text_before, abbrev_text_after = PROIEL::Printing.token_in_context(sentence, token)
    frame_id = TOKEN_FRAME_MAP[token.id]
    source_gid = GlobalIdentifiers.source_gid(treebank, version, source.id)
    sentence_gid = GlobalIdentifiers.sentence_gid(treebank, version, source.id, sentence.id)

    Token.create!(sentence_gid: sentence_gid,
       citation: token.citation,
       language: source.language,
       form: token.form,
       lemma: token.lemma,
       part_of_speech: token.part_of_speech,
       morphology: token.morphology,
       relation: token.relation,
       information_status: token.information_status,
       abbrev_text_before: abbrev_text_before,
       abbrev_text_after: abbrev_text_after,
       frame_id: frame_id
    )
  end
end

module SentenceIndexer
  def self.index!(treebank, version, source, sentence, db_source, prev_sentence, next_sentence)
    gid = GlobalIdentifiers.sentence_gid(treebank, version, source.id, sentence.id)
    previous_sentence_external_id, next_sentence_external_id =
      prev_sentence ? GlobalIdentifiers.sentence_gid(treebank, version, source.id, prev_sentence.id) : nil,
      next_sentence ? GlobalIdentifiers.sentence_gid(treebank, version, source.id, next_sentence.id) : nil
    data = make_sentence(source.language, sentence, previous_sentence_external_id, next_sentence_external_id)
#        svg_graph = PROIEL::Visualization::Graphviz.generate(:classic, s, :svg)

    db_source.sentences.create!({ gid: gid }.merge(data))
  end

  def self.make_sentence(language, sentence, previous_sentence_external_id, next_sentence_external_id)
    token_attributes =
      sentence.tokens.map do |t|
        glosses = get_glosses(language, t.lemma, t.part_of_speech)
        m =
          {
            id: t.id,
            form: t.form,
            lemma: t.lemma,
            part_of_speech: t.part_of_speech,
            morphology: t.morphology,
            head_id: t.head_id,
            relation: t.relation,
          }

        m[:glosses] = glosses unless glosses.empty?
        m[:presentation_after] = t.presentation_after unless t.presentation_after.nil?
        m[:presentation_before] = t.presentation_before unless t.presentation_before.nil?
        m[:empty_token_sort] = t.empty_token_sort unless t.empty_token_sort.nil?
        m[:slashes] = t.slashes unless t.slashes.empty?
        m
      end

    {
      text: sentence.printable_form,
      citation: sentence.citation,
      tokens: token_attributes.to_json,
      language: language,
      previous_gid: previous_sentence_external_id,
      next_gid: next_sentence_external_id,
    }
  end
end

module AlignedSourceIndexer
  # FIXME
  BLACKLIST = [
    # Lacuna in Gothic NT
    47183, 47184,

    # ? in Armenian NT
    75413, 61271, 61428, 61747, 64309, 61748, 62506,
  ]

  def self.index!(treebank, version, alignment, source)
    gid = GlobalIdentifiers.source_gid(treebank, version, alignment.id)

    puts "Indexing alignment of #{gid}..."

    matrix = compute_matrix(alignment, source)

    chunk_ids = []

    html_chunks(treebank, version, alignment, source, matrix) do |data|
      new_chunk = AlignedChunk.create!(source_id: source.id, data: data.to_json)
      chunk_ids << new_chunk.id
    end

    chunk_ids
  end

  def self.html_chunks(treebank, version, alignment, source, matrix, max_chunk_length = 5000)
    last_citation1, last_citation2 = nil, nil

    formatter1 = lambda { |token|
      if token.citation != last_citation1
        last_citation1 = token.citation
        ["<span class=\"citation\">#{token.citation}</span>", token.form].join(' ')
      else
        token.form
      end
    }

    formatter2 = lambda { |token|
      if token.citation != last_citation2
        last_citation2 = token.citation
        ["<span class=\"citation\">#{token.citation}</span>", token.form].join(' ')
      else
        token.form
      end
    }

    chunk, n = [], 0

    matrix.each do |row|
      left =
        row[:original].map do |sentence_id|
          sentence = alignment.treebank.find_sentence(sentence_id)
          gid = GlobalIdentifiers.sentence_gid(treebank, version, alignment.id, sentence.id)
          s = sentence.printable_form(custom_token_formatter: formatter1)
          n += s.length
          [gid, s]
        end

      right =
        row[:translation].map do |sentence_id|
          sentence = source.treebank.find_sentence(sentence_id)
          gid = GlobalIdentifiers.sentence_gid(treebank, version, source.id, sentence.id)
          s = sentence.printable_form(custom_token_formatter: formatter2)
          n += s.length
          [gid, s]
        end

      chunk << [left, right]

      if n > max_chunk_length
        yield chunk
        chunk, n = [], 0
      end
    end

    yield chunk unless chunk.empty?
  end

  # This computes a matrix of original and translation sentences that are
  # aligned. For now, this function does not handle translation sentences that
  # are unaligned (this is tricky to handle robustly!). As the current treebank
  # collection stands this is an issue that *should* not arise so this is for
  # now a reasonable approximation.
  def self.compute_matrix(alignment, source)
    matrix1 = self.group_backwards(alignment, source)
    raise unless matrix1.map { |r| r[:original]    }.flatten.compact == alignment.sentences.map(&:id)

    matrix2 = self.group_forwards(alignment, source)
    raise unless matrix2.map { |r| r[:translation] }.flatten.compact == source.sentences.map(&:id)

    # Verify that both texts are still in the correct sequence
    File.open('log/' + source.id + '1','w') do |f|
      matrix1.map do |x|
        f.puts x.inspect
      end
    end

    File.open('log/' + source.id + '2','w') do |f|
      matrix2.map do |x|
        f.puts x.inspect
      end
    end

    matrix = []
    iter1 = { i: 0, m: matrix1 }
    iter2 = { i: 0, m: matrix2 }

    loop do
      # Take from matrix1 unless we have a translation
      while iter1[:i] < iter1[:m].length and iter1[:m][iter1[:i]][:translation].empty?
        matrix << iter1[:m][iter1[:i]]
        iter1[:i] += 1
      end

      # Take from matrix2 unless we have an original
      while iter2[:i] < iter2[:m].length and iter2[:m][iter2[:i]][:original].empty?
        matrix << iter2[:m][iter2[:i]]
        iter2[:i] += 1
      end

      if iter1[:i] < iter1[:m].length and iter2[:i] < iter2[:m].length
        # Now the two should match provided alignments are sorted the same way,
        # so take one from each. If they don't match outright, we may have a case
        # of swapped sentence orders or a gap (one sentence unaligned in one of
        # the texts surrounded by two sentences that are aligned to the same
        # sentence in the other text). We'll try to repair this by merging bits
        # from the next row in various combinations.
        #
        # When adding to the new mateix, pick original from matrix1 and
        # translation from matrix2 so that the original textual order is
        # preserved
        if repair(matrix, iter1, 0, iter2, 0) or

           repair(matrix, iter1, 1, iter2, 0) or
           repair(matrix, iter1, 0, iter2, 1) or
           repair(matrix, iter1, 1, iter2, 1) or

           repair(matrix, iter1, 2, iter2, 0) or
           repair(matrix, iter1, 0, iter2, 2) or
           repair(matrix, iter1, 2, iter2, 1) or
           repair(matrix, iter1, 1, iter2, 2) or
           repair(matrix, iter1, 2, iter2, 2) or

           repair(matrix, iter1, 3, iter2, 0) or
           repair(matrix, iter1, 0, iter2, 3) or
           repair(matrix, iter1, 3, iter2, 1) or
           repair(matrix, iter1, 1, iter2, 3) or
           repair(matrix, iter1, 3, iter2, 2) or
           repair(matrix, iter1, 2, iter2, 3) or
           repair(matrix, iter1, 3, iter2, 3) or

           repair(matrix, iter1, 4, iter2, 0) or
           repair(matrix, iter1, 0, iter2, 4) or
           repair(matrix, iter1, 4, iter2, 1) or
           repair(matrix, iter1, 1, iter2, 4) or
           repair(matrix, iter1, 4, iter2, 2) or
           repair(matrix, iter1, 2, iter2, 4) or
           repair(matrix, iter1, 4, iter2, 3) or
           repair(matrix, iter1, 3, iter2, 4) or
           repair(matrix, iter1, 4, iter2, 4)
        else
          STDERR.puts iter1[:i], iter1[:m][iter1[:i]].inspect
          STDERR.puts iter2[:i], iter2[:m][iter2[:i]].inspect
          raise
        end
      else
        raise unless iter1[:i] == iter1[:m].length and iter2[:i] == iter2[:m].length
        break
      end
    end

    File.open('log/' + source.id + '3','w') do |f|
      matrix.map do |x|
        f.puts x.inspect
      end
    end

    raise unless matrix.map { |r| r[:original]    }.flatten.compact == alignment.sentences.map(&:id)
    raise unless matrix.map { |r| r[:translation] }.flatten.compact == source.sentences.map(&:id)

    matrix
  end

  def self.repair_merge_cells(iter, delta, field)
    matrix, i = iter[:m], iter[:i]
    (0..delta).map { |j| matrix[i + j][field] }.inject(&:+)
  end

  def self.select_unaligned(iter, delta, field, check_field)
    matrix, i = iter[:m], iter[:i]
    (0..delta).select { |j| matrix[i + j][check_field].empty? }.map { |j| matrix[i + j][field] }.flatten
  end

  def self.repair(matrix, iter1, delta1, iter2, delta2)
    o1 = repair_merge_cells(iter1, delta1, :original)
    o2 = repair_merge_cells(iter2, delta2, :original)

    t1 = repair_merge_cells(iter1, delta1, :translation)
    t2 = repair_merge_cells(iter2, delta2, :translation)

    u1 = select_unaligned(iter1, delta1, :original, :translation)
    u2 = select_unaligned(iter2, delta2, :translation, :original)

    if o1.sort - u1 == o2.sort.uniq and t1.sort.uniq == t2.sort - u2
      unless delta1.zero? and delta2.zero?
        STDERR.puts "Assuming #{delta1 + 1}/#{delta2 + 1} swapped sentence order:"
        STDERR.puts ' * ' + (0..delta1).map { |j| iter1[:m][iter1[:i] + j].inspect }.join(' + ')
        STDERR.puts ' * ' + (0..delta2).map { |j| iter2[:m][iter2[:i] + j].inspect }.join(' + ')
      end

      matrix << { original: o1, translation: t2 }

      iter1[:i] += delta1 + 1
      iter2[:i] += delta2 + 1

      true
    else
      false
    end
  end

  def self.group_forwards(alignment, source)
    # Make an original to translation ID mapping
    mapping = {}

    source.sentences.each do |sentence|
      mapping[sentence.id] = []

      next if BLACKLIST.include?(sentence.id)

      mapping[sentence.id] = sentence.inferred_alignment(alignment).map(&:id)
    end

    # Translate to a pairs of ID arrays, chunk original IDs that share at least
    # one translation ID, then reduce the result so we get an array of m-to-n
    # relations
    mapping.map do |v, k|
      { original: k, translation: [v] }
    end.chunk_while do |x, y|
      !(x[:original] & y[:original]).empty?
    end.map do |chunk|
      chunk.inject do |a, v|
        a[:original] += v[:original]
        a[:translation] += v[:translation]
        a
      end
    end.map do |row|
      { original: row[:original].uniq, translation: row[:translation] }
    end
  end

  def self.group_backwards(alignment, source)
    # Make an original to translation ID mapping
    mapping = {}

    alignment.sentences.each do |sentence|
      mapping[sentence.id] = []
    end

    source.sentences.each do |sentence|
      next if BLACKLIST.include?(sentence.id)

      original_ids = sentence.inferred_alignment(alignment).map(&:id)

      original_ids.each do |original_id|
        mapping[original_id] << sentence.id
      end
    end

    # Translate to a pairs of ID arrays, chunk original IDs that share at least
    # one translation ID, then reduce the result so we get an array of m-to-n
    # relations
    mapping.map do |k, v|
      { original: [k], translation: v }
    end.chunk_while do |x, y|
      !(x[:translation] & y[:translation]).empty?
    end.map do |chunk|
      chunk.inject do |a, v|
        a[:original] += v[:original]
        a[:translation] += v[:translation]
        a
      end
    end.map do |row|
      { original: row[:original], translation: row[:translation].uniq }
    end
  end
end

module SourceIndexer
  def self.index!(treebank, version, source, alignment = {})
    gid = GlobalIdentifiers.source_gid(treebank, version, source.id)

    puts "Indexing #{gid}..."

    chunk_ids = []

    html_chunks(treebank, version, source) do |data|
      new_chunk = Chunk.create!(source_id: source.id, data: data.to_json)
      chunk_ids << new_chunk.id
    end

    s = Source.create!(gid: gid,
                       title: source.title,
                       author: source.author,
                       language: source.language,
                       license: source.license || 'CC BY-NC-SA 4.0',
                       citation: source.citation,
                       sentence_count: source.sentences.count,
                       token_count: source.tokens.count,
                       chunks: chunk_ids.to_json,
                       alignment: alignment.to_json)

    pbar = ProgressBar.create progress_mark: 'X', remainder_mark: ' ', title: 'Sentences', total: source.sentences.count

    Sentence.transaction do
      # FIXME: This is subobtimal since it expands the whole sequence of sentences.
      # If there are no sentences, we get [nil, nil], which leads each_cons(3) not to call the block, which is what we want.
      [nil, *source.sentences, nil].each_cons(3) do |prev_sentence, sentence, next_sentence|
        #svg_graph = PROIEL::Visualization::Graphviz.generate(:classic, s, :svg)
        SentenceIndexer.index!(treebank, version, source, sentence, s, prev_sentence, next_sentence)
        pbar.increment
      end
    end

    pbar = ProgressBar.create progress_mark: 'X', remainder_mark: ' ', title: 'Tokens', total: source.sentences.map(&:tokens).map(&:count).sum

    Token.transaction do
      source.sentences.each do |sentence|
        sentence.tokens.each do |token|
          TokenIndexer.index!(treebank, version, source, sentence, token)
          pbar.increment
        end
      end
    end
  end

  def self.html_chunks(treebank, version, source, max_chunk_length = 5000)
    last_citation = nil
    formatter = lambda { |token|
      if token.citation != last_citation
        last_citation = token.citation
        ["<span class=\"citation\">#{token.citation}</span>", token.form].join(' ')
      else
        token.form
      end
    }

    chunk, n = [], 0

    source.divs.each do |div|
      div.sentences.each do |sentence|
        gid = GlobalIdentifiers.sentence_gid(treebank, version, source.id, sentence.id)
        s = sentence.printable_form(custom_token_formatter: formatter)

        chunk << [gid, s]
        n += s.length

        if n > max_chunk_length
          yield chunk
          chunk, n = [], 0
        end
      end
    end

    yield chunk unless chunk.empty?
  end
end

TREEBANKS = [
  ['proiel', 20170214, Dir[File.join('..', 'proiel-treebank', '*.xml')]],
  ['iswoc',  20160620, Dir[File.join('..', 'iswoc-treebank',  '*.xml')]],
  ['torot',  20170213, Dir[File.join('..', 'torot-treebank',  '*.xml')]],
]

TREEBANKS.each do |(treebank, version, filenames)|
  tb = PROIEL::Treebank.new

  filenames.each_with_index do |filename, i|
    puts "Loading #{filename}..."
    tb.load_from_xml(filename)
  end

  GLOBAL_STATE[:frame_id] = Token.maximum(:frame_id) || 0
  puts "Initialising with #{GLOBAL_STATE.inspect}"

  tb.sources.group_by(&:language).each do |language, sources|
    DictionaryIndexer.index!(treebank, version, language, sources)
  end

  tb.sources.each do |source|
    if source.alignment_id
      aligned_source = tb.find_source(source.alignment_id)
      aligned_chunk_ids = AlignedSourceIndexer.index!(treebank, version, aligned_source, source)

      SourceIndexer.index!(treebank, version, source,
                           {
                             gid: GlobalIdentifiers.source_gid(treebank, version, aligned_source.id),
                             title: aligned_source.title,
                             author: aligned_source.author,
                             language: aligned_source.language,
                             chunk_ids: aligned_chunk_ids,
                           })
    else
      SourceIndexer.index!(treebank, version, source)
    end
  end
end
