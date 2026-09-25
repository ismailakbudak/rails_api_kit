require 'securerandom'
require 'active_record'
require 'action_controller/railtie'
require 'api_kit'
require 'ransack'
require 'active_model_serializers'

Rails.logger = Logger.new(STDOUT)
Rails.logger.level = ENV['LOG_LEVEL'] || Logger::WARN

ApiKit::RailsApp.install!

ActiveRecord::Base.logger = Rails.logger
ActiveRecord::Base.establish_connection(
  ENV['DATABASE_URL'] || 'sqlite3::memory:'
)

ActiveRecord::Schema.define do
  create_table :users, force: true do |t|
    t.string :first_name
    t.string :last_name
    t.timestamps
  end

  create_table :notes, force: true do |t|
    t.string :title
    t.integer :user_id
    t.integer :quantity
    t.timestamps
  end

  create_table :inventory_items, force: true do |t|
    t.string :name
    t.integer :quantity
    t.timestamps
  end
end


class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  def self.ransackable_associations(auth_object = nil)
    @ransackable_associations ||= reflect_on_all_associations.map { |a| a.name.to_s }
  end

  def self.ransackable_attributes(auth_object = nil)
    @ransackable_attributes ||= column_names + _ransackers.keys + _ransack_aliases.keys + attribute_aliases.keys
  end
end

class User < ApplicationRecord
  has_many :notes
end

class Note < ApplicationRecord
  validates_format_of :title, without: /BAD_TITLE/
  validates_numericality_of :quantity, less_than: 100, if: :quantity?
  belongs_to :user, required: true
end

class RuntimeCustomNote
  include ActiveModel::Model
  include ActiveModel::Serialization

  ATTRIBUTES = %w[id title quantity created_at updated_at user].freeze

  attr_accessor(*ATTRIBUTES.map(&:to_sym))

  def attributes
    ATTRIBUTES.index_with { nil }
  end
end

class CustomNoteSerializer < ActiveModel::Serializer
  attributes :id, :title, :quantity, :created_at, :updated_at
  belongs_to :user
end

class UserSerializer < ActiveModel::Serializer
  attributes :id, :last_name, :created_at, :updated_at, :first_name
  has_many :notes, serializer: CustomNoteSerializer
  belongs_to :custom_note, serializer: CustomNoteSerializer do
    RuntimeCustomNote.new(
      id: 1,
      title: "My",
      quantity: 1,
      created_at: Time.current,
      updated_at: Time.current,
      user: nil
    )
  end

  def first_name
    if @instance_options.dig(:params, :first_name_upcase)
      object.first_name.upcase
    else
      object.first_name
    end
  end
end

# Namespaced model — `model_name.to_s.underscore` is slash-separated
# (`inventory/item`) while `model_name.singular` is not
# (`inventory_item`). The sparse-fieldset type key is the former.
module Inventory
  class Item < ApplicationRecord
    self.table_name = 'inventory_items'
  end

  class ItemSerializer < ActiveModel::Serializer
    attributes :id, :name, :quantity
  end
end

# A row of an aggregation endpoint: a PORO, not an AR record, rendered as
# a plain Array. An empty one gives AMS nothing to infer a root key from.
class ReportRow
  include ActiveModel::Model
  include ActiveModel::Serialization

  attr_accessor :label, :total
end

class ReportRowSerializer < ActiveModel::Serializer
  attributes :label, :total
end

class MyUserSerializer < UserSerializer
  attribute :full_name

  def full_name
    "#{object.first_name} #{object.last_name}"
  end
end

class Dummy < Rails::Application
  # secrets.secret_key_base = '_'
  config.hosts << 'www.example.com' if config.respond_to?(:hosts)

  routes.draw do
    scope defaults: { format: :api } do
      resources :users, only: [ :index, :show ]
      resources :notes, only: [ :update ]
      resources :inventory_items, only: [ :index ]
      resources :reports, only: [ :index ]
    end
  end
end

class BaseApplicationController < ActionController::Base
  def serialize_array(data, options = {})
    options[:adapter] = :attributes
    ActiveModelSerializers::SerializableResource.new(data, options).as_json
  end
end

class UsersController < BaseApplicationController
  include ApiKit::Fetching
  include ApiKit::Filtering
  include ApiKit::Pagination

  def index
    allowed_fields = [
      :first_name, :last_name, :created_at,
      :notes_created_at, :notes_quantity
    ]
    options = { sort_with_expressions: true }

    api_filter(User.all, allowed_fields, options) do |filtered|
      result = filtered.result

      if params[:sort].to_s.include?('notes_quantity')
        render api_paginate: result.group('id').to_a
        return
      end

      result = result.to_a if params[:as_list]

      api_paginate(result) do |paginated|
        render api_paginate: paginated,
              serializer_class: MyUserSerializer
      end
    end
  end

  def show
    render api: User.find(params[:id]),
           serializer_class: MyUserSerializer
  end

  private
  def api_meta(resources)
    {
      many: true,
      pagination: api_pagination_meta(resources)
    }
  end

  def api_serializer_params
    {
      first_name_upcase: params[:upcase]
    }
  end
end

class InventoryItemsController < BaseApplicationController
  include ApiKit::Fetching

  def index
    render api: Inventory::Item.all, serializer_class: Inventory::ItemSerializer
  end
end

class ReportsController < BaseApplicationController
  include ApiKit::Fetching

  def index
    rows =
      if params[:empty]
        []
      else
        [ ReportRow.new(label: 'first', total: 1) ]
      end

    render api: rows, serializer_class: ReportRowSerializer
  end
end

class NotesController < ActionController::Base
  include ApiKit::Fetching
  include ApiKit::Errors

  def update
    raise StandardError.new("tada") if params[:id] == 'tada'

    note = Note.find(params[:id])

    if note.update(note_params)
      render api: note,
             serializer_class: CustomNoteSerializer
    else
      note.errors.add(:title, message: 'has typos') if note.errors.key?(:title)

      render api_errors: note.errors, status: :unprocessable_content
    end
  end

  private

    def note_params
      params.require(:note).permit(:title, :user_id, :quantity, :created_at)
    end

    def api_meta(resources)
      { single: true }
    end
end
