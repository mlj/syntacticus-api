#!/usr/bin/env ruby
require 'colorize'
require 'json'
require 'proiel'
require 'proiel/valency'
require 'ruby-progressbar'

TREEBANKS = [
  ['proiel',      20170214, ['../syntacticus-depot/proiel-20170214.xml']],
  ['proiel',      20180408, ['../syntacticus-depot/proiel-20180408.xml']],
]

# FIXME
BLACKLIST = [
  # Lacuna in Gothic NT
  47183, 47184,

  # ? in Armenian NT
  75413, 61271, 61428, 61747, 64309, 61748, 62506,
]

def align(treebank, version, aligned_source, source)
  matrix = PROIEL::Alignment::Builder.compute_matrix(aligned_source, source, BLACKLIST, 'log')

  File.open("#{treebank}-#{version}-#{aligned_source.id}-#{source.id}.tsv", 'w') do |f|
    f.puts %w(original translation).join("\t")
    matrix.each do |h|
      f.puts [h[:original].join(','), h[:translation].join(',')].join("\t")
    end
  end
end

TREEBANKS.each do |(treebank, version, filenames)|
  tb = PROIEL::Treebank.new

  filenames.each do |filename|
    puts "Loading #{filename}"
    tb.load_from_xml(filename)
  end

  tb.sources.each do |source|
    if source.alignment_id
      puts "* Aligning #{source.id}"
      align(treebank, version, tb.find_source(source.alignment_id), source)
      puts
    end
  end
end
