# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_01_02_173204) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "documents", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "doc_type", null: false
    t.bigint "entity_id", null: false
    t.integer "fiscal_year", null: false
    t.text "notes"
    t.text "source_url", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["entity_id", "fiscal_year", "doc_type"], name: "index_documents_on_entity_id_and_fiscal_year_and_doc_type", unique: true
    t.index ["entity_id"], name: "index_documents_on_entity_id"
  end

  create_table "entities", force: :cascade do |t|
    t.string "board_selection"
    t.datetime "created_at", null: false
    t.string "executive_selection"
    t.string "fiscal_autonomy"
    t.string "government_structure"
    t.string "kind", default: "city", null: false
    t.string "name"
    t.text "organization_note"
    t.bigint "parent_id"
    t.string "school_legal_type"
    t.string "slug", null: false
    t.string "state", default: "NY", null: false
    t.datetime "updated_at", null: false
    t.index ["board_selection"], name: "index_entities_on_board_selection"
    t.index ["executive_selection"], name: "index_entities_on_executive_selection"
    t.index ["fiscal_autonomy"], name: "index_entities_on_fiscal_autonomy"
    t.index ["government_structure"], name: "index_entities_on_government_structure"
    t.index ["name", "state", "kind"], name: "index_entities_on_name_and_state_and_kind", unique: true
    t.index ["parent_id"], name: "index_entities_on_parent_id"
    t.index ["school_legal_type"], name: "index_entities_on_school_legal_type"
    t.index ["slug"], name: "index_entities_on_slug", unique: true
  end

  create_table "metrics", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.string "label", null: false
    t.string "unit"
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_metrics_on_key", unique: true
  end

  create_table "observations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "document_id", null: false
    t.bigint "entity_id", null: false
    t.integer "fiscal_year", null: false
    t.bigint "metric_id", null: false
    t.text "notes"
    t.string "page_reference", null: false
    t.datetime "updated_at", null: false
    t.decimal "value_numeric", precision: 20, scale: 2
    t.text "value_text"
    t.index ["document_id"], name: "index_observations_on_document_id"
    t.index ["entity_id"], name: "index_observations_on_entity_id"
    t.index ["metric_id"], name: "index_observations_on_metric_id"
  end

  create_table "versions", force: :cascade do |t|
    t.datetime "created_at"
    t.string "event", null: false
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.text "object"
    t.string "whodunnit"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "documents", "entities"
  add_foreign_key "entities", "entities", column: "parent_id"
  add_foreign_key "observations", "documents"
  add_foreign_key "observations", "entities"
  add_foreign_key "observations", "metrics"
end
