# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20170711162858) do

  create_table "aligned_chunks", force: :cascade do |t|
    t.integer "source_id"
    t.text "data"
  end

  create_table "chunks", force: :cascade do |t|
    t.integer "source_id"
    t.text "data"
  end

  create_table "dictionaries", force: :cascade do |t|
    t.text "gid"
    t.text "language"
    t.text "license"
    t.integer "lemma_count"
    t.index ["gid"], name: "index_dictionaries_on_gid", unique: true
  end

  create_table "lemmas", force: :cascade do |t|
    t.integer "dictionary_id", null: false
    t.string "language", null: false
    t.string "lemma", null: false
    t.string "part_of_speech", null: false
    t.string "glosses", null: false
    t.string "data", null: false
    t.index ["dictionary_id"], name: "index_lemmas_on_dictionary_id"
    t.index ["language", "lemma", "part_of_speech"], name: "index_lemmas_on_language_and_lemma_and_part_of_speech", unique: true
  end

  create_table "sentences", force: :cascade do |t|
    t.text "gid"
    t.text "previous_gid"
    t.text "next_gid"
    t.text "text"
    t.text "citation"
    t.text "language"
    t.text "tokens"
    t.index ["gid"], name: "index_sentences_on_gid", unique: true
  end

  create_table "sources", force: :cascade do |t|
    t.text "gid"
    t.text "aligned_gid"
    t.text "title"
    t.text "author"
    t.text "language"
    t.text "license"
    t.text "citation"
    t.integer "sentence_count"
    t.integer "token_count"
    t.text "chunks"
    t.text "aligned_chunks"
    t.index ["gid"], name: "index_sources_on_gid", unique: true
  end

  create_table "tokens", force: :cascade do |t|
    t.text "sentence_gid"
    t.text "citation"
    t.text "language"
    t.text "form"
    t.text "lemma"
    t.text "part_of_speech"
    t.text "morphology"
    t.text "relation"
    t.text "information_status"
    t.string "abbrev_text_before"
    t.string "abbrev_text_after"
    t.integer "frame_id"
    t.index ["form"], name: "index_tokes_on_form"
    t.index ["id"], name: "index_tokes_on_id"
    t.index ["lemma"], name: "index_tokes_on_lemma"
    t.index ["morphology"], name: "index_tokes_on_morphology"
    t.index ["part_of_speech"], name: "index_tokes_on_part_of_speech"
  end

end
