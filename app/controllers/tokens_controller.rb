class TokensController < ApplicationController
  def index
    tokens = Token

    %i(source language form lemma morphology part_of_speech relation information_status frame_id).each do |attr|
      if params[attr] and params[attr] != ''
        tokens = tokens.where(attr => params[attr])
      end
    end

    # Morphology can be tested for directly and we may already have a where
    # clause for it. If this is the case, we will end up with two where
    # clauses, possibly contradicting each other, but this is expected
    # behaviour so no need to test for it separately. In case we have a
    # where clause for morphology from above but none for person, number
    # etc., the code below will generate a where clause that matches all
    # rows anyway.
    morphology = nil

    %w(person number tense mood voice gender case degree strength inflection).each_with_index do |attr, i|
      if params[attr] and params[attr] != ''
        morphology ||= '__________'
        morphology[i] = params[attr]
      end
    end

    tokens = tokens.where('morphology LIKE ?', morphology) unless morphology.nil?

    #if params[:ids]
    #  ids = params[:ids].split(',').map(&:to_i)
    #  t = t.where('xml_id IN (?)', ids)
    #end

    render json: paginator(tokens, lambda { |token| {
      sentence: token.sentence_gid,
      citation: token.citation,
      language: token.language,
      form: token.form,
      abbrev_text_before: token.abbrev_text_before,
      abbrev_text_after: token.abbrev_text_after,
    }})
  end
end
