# encoding: UTF-8
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

ActiveRecord::Schema.define(version: 20160417052516) do

  create_table "synced_objects", force: :cascade do |t|
    t.string   "type",             limit: 64
    t.integer  "clab_id"
    t.string   "clab_type",        limit: 32
    t.datetime "clab_last_update"
    t.string   "ext_channel",      limit: 32
    t.string   "ext_type",         limit: 32
    t.string   "ext_id",           limit: 48
    t.datetime "ext_last_update"
    t.integer  "sync_type",                   default: 0
    t.integer  "err_count",                   default: 0
    t.datetime "last_sync"
    t.datetime "last_err"
    t.string   "err_msg"
    t.boolean  "is_ignored",                  default: false
    t.boolean  "is_locked",                   default: false
    t.datetime "locked_at"
  end

end
