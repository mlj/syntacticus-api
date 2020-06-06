require 'translate_tags'

class GraphsController < ApplicationController
  class GraphAdapter
    attr_reader :tokens

    def initialize(sentence)
      @sentence = sentence
      @id_map = {}
      @tokens = _tokens
    end

    def _tokens_with_ids
      JSON.parse(@sentence.tokens).map do |t|
        OpenStruct.new.tap do |o|
          o.id = t['id']
          o.relation = t['relation']
          o.form = t['form']
          o.lemma = t['lemma']
          o.part_of_speech = translate_part_of_speech(t['part_of_speech'])
          o.morphology = translate_morphology(t['morphology'])
          o.empty_token_sort = t['empty_token_sort']
          o.relation = t['relation']
          o.head_id = t['head_id']
          o.slashes = t['slashes'] || []

          @id_map[o.id] = o
        end
      end
    end

    def _tokens
      _tokens_with_ids.map do |o|
        o.head = @id_map[o.head_id]
        o
      end
    end
  end

  def show
    sentence = Sentence.find_by_gid(params[:id])

    graph = GraphAdapter.new(sentence)
    image = PROIEL::Visualization::Graphviz.generate(
      params[:layout] || :modern, graph, :svg, direction: params[:direction] || 'TD'
    )
    send_data(image, type: 'image/svg', disposition: 'inline', filename: "#{params[:id]}-aligned.svg")
  end
end
