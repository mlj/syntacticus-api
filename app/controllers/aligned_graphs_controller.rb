class AlignedGraphsController < ApplicationController
  class GraphAdapter
    attr_reader :left, :right, :alignments

    def initialize(left, right, alignments)
      @id_map = {}
      @left = left.map { |tokens| _tokens(tokens) }

      @id_map = {}
      @right = right.map { |tokens| _tokens(tokens) }

      @alignments = alignments
    end

    def _tokens_with_ids(tokens)
      tokens.map do |t|
        OpenStruct.new.tap do |o|
          o.id = t['id']
          o.relation = t['relation']
          o.form = t['form']
          o.empty_token_sort = t['empty_token_sort']
          o.relation = t['relation']
          o.head_id = t['head_id']
          o.slashes = t['slashes'] || []

          @id_map[o.id] = o
        end
      end
    end

    def _tokens(tokens)
      _tokens_with_ids(tokens).map do |o|
        o.head = @id_map[o.head_id]
        o
      end
    end
  end

  def show
    g = AlignedGraph.find_by_sentence_gid(params[:id])
    data = JSON.parse(g.data)
    sentence1 = data['l']
    sentence2 = data['r']
    alignments = data['a']

    graph = GraphAdapter.new(sentence1, sentence2, alignments)
    image = PROIEL::Visualization::Graphviz.generate('aligned-modern', graph, :svg, direction: params[:direction] || 'TD')
    send_data(image, type: 'image/svg', disposition: 'inline')
  end
end