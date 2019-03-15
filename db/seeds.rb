require 'json'
require 'csv'
require 'colorize'
require 'ruby-progressbar'
require 'proiel'
require 'proiel/valency'

TREEBANKS = [
  #['syntacticus', 20180303, Dir['../syntacticus-dictionaries/*.xml']],
  ['syntacticus', 20180920, Dir['../syntacticus-dictionaries/*.xml']],
  ['iswoc',       20160620, Dir['../syntacticus-depot/iswoc-20160620.xml']],
  ['proiel',      20170214, Dir['../syntacticus-depot/proiel-20170214.xml']],
  ['proiel',      20180408, Dir['../syntacticus-depot/proiel-20180408.xml']],
  ['torot',       20170213, Dir['../syntacticus-depot/torot-20170213.xml']],
  ['torot',       20180323, Dir['../syntacticus-depot/torot-20180323.xml']],
  ['torot',       20180919, Dir['../syntacticus-depot/torot-20180919.xml']],
]

# Silence logging during seeding
ActiveRecord::Base.logger.level = :error

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

module PROIEL::CSV
  def self.read_tsv_as_hash(filename, &block)
    {}.tap do |hash|
      read_tsv(filename) do |row|
        key, data = yield row
        hash[key] = data
      end
    end
  end

  def self.read_tsv(filename, &block)
    raise ArgumentError, 'filename expected' unless filename.is_a?(String)
    raise ArgumentError, 'file not found' unless File.exists?(filename)

    CSV.foreach(filename, headers: true, encoding: 'utf-8', col_sep: "\t", quote_char: "\b") do |row|
      yield OpenStruct.new(row.to_h.map { |k, v| [k.downcase, v] }.to_h)
    end
  end

  def self.read_csv(filename, separator: ',', quote_char: '"', &block)
    raise ArgumentError, 'filename expected' unless filename.is_a?(String)
    raise ArgumentError, 'file not found' unless File.exists?(filename)

    CSV.foreach(filename, headers: true, encoding: 'utf-8', col_sep: separator, quote_char: quote_char) do |row|
      yield OpenStruct.new(row.to_h.map { |k, v| [k.downcase, v] }.to_h)
    end
  end
end

CHRONOLOGY = {}
CHRONOLOGY.merge!(PROIEL::CSV.read_from_tsv_as_hash('../syntacticus-extra-data/torot-dates.tsv'))
CHRONOLOGY.merge!(PROIEL::CSV.read_from_tsv_as_hash('../syntacticus-extra-data/proiel-dates.tsv'))

PROIEL::CSV.read_csv('lib/dates.tsv', separator: "\t") do |row|
  CHRONOLOGY[row.id] = {
    t: PROIEL::Chronology.midpoint(row.text),
  }
end

PROIEL::CSV.read_csv('lib/orv_text_dates_standard.csv', separator: ';') do |row|
  CHRONOLOGY[row.id] = {
    t: PROIEL::Chronology.midpoint(row.composition),
    m: PROIEL::Chronology.midpoint(row.manuscript),
  }
end

module DictionaryIndexer
  def self.index!(treebank, version, language, dictionary)
    gid = GlobalIdentifiers.dictionary_gid(treebank, version, language)

    puts "Indexing #{gid}..."

    Dictionary.transaction do
      d = Dictionary.create!(gid: gid, language: dictionary.language, license: 'CC BY-NC-SA 4.0', lemma_count: dictionary.n)

      pbar = ProgressBar.create progress_mark: 'X', remainder_mark: ' ', title: language, total: dictionary.n
      dictionary.lemmata.each do |lemma, x|
        x.each do |part_of_speech, l|
          data = {
            language: language,
            lemma: lemma,
            part_of_speech: part_of_speech,
          }

          data[:distribution] =
            l.distribution.map do |id, n|
              { id: id, n: n, chronology: CHRONOLOGY[id] || { t: 0, m: 0 } }
            end

          unless l.valency.empty?
            data[:valency] = []

            l.valency.each do |frame|
              partitions = {}

              frame[:tokens].each do |t|
                partitions[t[:flags]] ||= []
                partitions[t[:flags]] << t[:idref]
              end

              simplified_partitions =
                partitions.map do |flags, idrefs|
                  GLOBAL_STATE[:frame_id] += 1
                  frame_id = GLOBAL_STATE[:frame_id]
                  idrefs.each { |t| TOKEN_FRAME_MAP[t.to_i] = frame_id }
                  [flags, { frame_id: frame_id, n: idrefs.length } ]
                end.to_h

              data[:valency] << { arguments: frame[:arguments], partitions: simplified_partitions }
            end
          end

          data[:paradigm] = l.paradigm unless l.paradigm.empty?
          data[:homographs] = l.homographs unless l.homographs.empty?
          data[:glosses] = l.glosses unless l.glosses.empty?

          d.lemmas.create! lemma: lemma, part_of_speech: part_of_speech, glosses: l.glosses.to_json, language: language, data: data.to_json

          pbar.increment
        end
      end
    end
  end
end

class Glosses
  def initialize
    @glosses = {}
  end

  def load!(language, filename)
    new_glosses =
      PROIEL::CSV.read_tsv_as_hash(filename) do |row|
        [key(language, row.lemma, row.part_of_speech), row]
      end

    @glosses.merge!(new_glosses)
  end

  def get(language, lemma, part_of_speech)
    @glosses[key(language, lemma, part_of_speech)] || {}
  end

  private

  def key(language, lemma, part_of_speech)
    [language, lemma, part_of_speech].map(&:to_s).join(',')
  end
end

# TODO
ORV_GLOSSES = Glosses.new
ORV_GLOSSES.load!(:orv, '../syntacticus-extra-data/orv-glosses.tsv')

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
       citation: token.citation || source.citation,
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

def make_token_attributes(sentence, language = nil)
  sentence.tokens.map do |t|
    glosses = language ? ORV_GLOSSES.get(language, t.lemma, t.part_of_speech) : nil

    m = {
        id: t.id,
        form: t.form,
        lemma: t.lemma,
        part_of_speech: t.part_of_speech,
        morphology: t.morphology,
        head_id: t.head_id,
        relation: t.relation,
      }

    m[:glosses] = glosses unless glosses.nil? or glosses.empty?
    m[:presentation_after] = t.presentation_after unless t.presentation_after.nil?
    m[:presentation_before] = t.presentation_before unless t.presentation_before.nil?
    m[:empty_token_sort] = t.empty_token_sort unless t.empty_token_sort.nil?
    m[:slashes] = t.slashes unless t.slashes.empty?
    m
  end
end

module SentenceIndexer
  def self.index!(treebank, version, source, sentence, db_source, prev_sentence, next_sentence)
    gid = GlobalIdentifiers.sentence_gid(treebank, version, source.id, sentence.id)
    previous_sentence_external_id, next_sentence_external_id =
      prev_sentence ? GlobalIdentifiers.sentence_gid(treebank, version, source.id, prev_sentence.id) : nil,
      next_sentence ? GlobalIdentifiers.sentence_gid(treebank, version, source.id, next_sentence.id) : nil
    data = make_sentence(source.language, sentence, previous_sentence_external_id, next_sentence_external_id)

    db_source.sentences.create!({ gid: gid }.merge(data))
  end

  def self.make_sentence(language, sentence, previous_sentence_external_id, next_sentence_external_id)
    token_attributes = make_token_attributes(sentence, language)

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
  def self.index!(treebank, version, alignment, source)
    matrix = []

    CSV.foreach("#{treebank}-#{version}-#{source.alignment_id}-#{source.id}.tsv", headers: true, col_sep: "\t", header_converters: :symbol) do |row|
      matrix << row.to_h.map { |k, v| [k, (v || '').split(',').map(&:to_i)] }.to_h
    end

    chunk_ids = []

    html_chunks(treebank, version, alignment, source, matrix) do |data|
      new_chunk = AlignedChunk.create!(source_id: source.id, data: data.to_json)
      chunk_ids << new_chunk.id
    end

    graph_pairs(treebank, version, alignment, source, matrix) do |data, sentence_gids|
      sentence_gids.each do |sentence_gid|
        AlignedGraph.create!(sentence_gid: sentence_gid, data: data.to_json)
      end
    end

    chunk_ids
  end

  def self.graph_pairs(treebank, version, alignment, source, matrix)
    matrix.each do |row|
      left =
        row[:original].map do |sentence_id|
          sentence = alignment.treebank.find_sentence(sentence_id)
          gid = GlobalIdentifiers.sentence_gid(treebank, version, alignment.id, sentence.id)
          token_attributes = make_token_attributes(sentence)
          # FIXME: we don't need all these attributes in token_attributes
          token_attributes
        end

      right =
        row[:translation].map do |sentence_id|
          sentence = source.treebank.find_sentence(sentence_id)
          gid = GlobalIdentifiers.sentence_gid(treebank, version, source.id, sentence.id)
          token_attributes = make_token_attributes(sentence)
          # FIXME: we don't need all these attributes in token_attributes
          token_attributes
        end

      token_alignments = []

      row[:translation].each do |sentence_id|
        sentence = source.treebank.find_sentence(sentence_id)
        token_alignments += sentence.tokens.select(&:alignment_id).map { |t| [t.alignment_id, t.id] }
      end

      sentence_ids = row[:translation].map { |sentence_id| GlobalIdentifiers.sentence_gid(treebank, version, source.id, sentence_id) }

      yield [{ l: left, r: right, a: token_alignments }, sentence_ids]
    end
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

TREEBANKS.each do |(treebank, version, filenames)|
  tb = PROIEL::Treebank.new

  filenames.each_with_index do |filename, i|
    puts "Loading #{filename}..."
    tb.load_from_xml(filename)
  end

  GLOBAL_STATE[:frame_id] = Token.maximum(:frame_id) || 0
  puts "Initialising with #{GLOBAL_STATE.inspect}"

  tb.dictionaries.each do |dictionary|
    DictionaryIndexer.index!(treebank, version, dictionary.language, dictionary)
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
