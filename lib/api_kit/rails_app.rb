require "ostruct"

# Rails integration
module ApiKit
  module RailsApp
    API_PAGINATE_METHODS_MAPPING = {
      meta: :api_meta,
      links: :api_pagination,
      fields: :api_fields,
      include: :api_include,
      params: :api_serializer_params
    }

    API_METHODS_MAPPING = {
      meta: :api_meta,
      fields: :api_fields,
      include: :api_include,
      params: :api_serializer_params
    }

    # Updates the mime types and registers the renderers
    #
    # @return [NilClass]
    def self.install!
      return unless defined?(::Rails)

      parser = ActionDispatch::Request.parameter_parsers[:json]
      ActionDispatch::Request.parameter_parsers[:api] = parser

      self.add_renderer!
      self.add_errors_renderer!
    end


    # Adds the error renderer
    #
    # @return [NilClass]
    def self.add_errors_renderer!
      ActionController::Renderers.add(:api_errors) do |resource, options|
        self.content_type ||= Mime[:json]

        many = ApiKit::RailsApp.is_collection?(resource, options[:is_collection])
        resource = [ resource ] unless many

        ApiKit::ErrorSerializer.new(resource, options).to_json
      end
    end

    # Adds the default renderer
    #
    # @return [NilClass]
    def self.add_renderer!
      ActionController::Renderers.add(:api_paginate) do |resource, options|
        self.content_type ||= Mime[:json]

        result = {}
        API_PAGINATE_METHODS_MAPPING.to_a[0..1].each do |opt, method_name|
          next unless respond_to?(method_name, true)
          result[opt] ||= send(method_name, resource)
        end

        # If it's an empty collection, return it directly.
        many = ApiKit::RailsApp.is_collection?(resource, options[:is_collection])

        API_PAGINATE_METHODS_MAPPING.to_a[2..-1].each do |opt, method_name|
          options[opt] ||= send(method_name) if respond_to?(method_name, true)
        end

        if options[:serializer_class]
          serializer_class = options[:serializer_class]
        else
          serializer_class = ApiKit::RailsApp.serializer_class(resource, many)
        end

        options[:fields] = api_fields(serializer_class, ApiKit::RailsApp.fetch_name(many, resource))
        options[:adapter] = :attributes
        options[:each_serializer] = serializer_class
        ApiKit::RailsApp.assign_collection_root!(options, resource, serializer_class) if many
        data = ActiveModelSerializers::SerializableResource.new(resource, options).as_json
        result[:data] = data
        result.to_json
      end

      ActionController::Renderers.add(:api) do |resource, options|
        self.content_type ||= Mime[:json]

        result = {}
        API_METHODS_MAPPING.to_a[0..0].each do |opt, method_name|
          next unless respond_to?(method_name, true)
          result[opt] ||= send(method_name, resource)
        end

        # If it's an empty collection, return it directly.
        many = ApiKit::RailsApp.is_collection?(resource, options[:is_collection])

        API_METHODS_MAPPING.to_a[1..-1].each do |opt, method_name|
          options[opt] ||= send(method_name) if respond_to?(method_name, true)
        end

        if options[:serializer_class]
          serializer_class = options[:serializer_class]
        else
          serializer_class = ApiKit::RailsApp.serializer_class(resource, many)
        end

        # Use Active Model Serializers properly with fallback
        options[:fields] = api_fields(serializer_class, ApiKit::RailsApp.fetch_name(many, resource))
        options[:adapter] = :attributes
        options[:each_serializer] = serializer_class
        if many
          ApiKit::RailsApp.assign_collection_root!(options, resource, serializer_class)
          data = ActiveModelSerializers::SerializableResource.new(resource, options).as_json
        else
          data = ActiveModelSerializers::SerializableResource.new([ resource ], options).as_json[0]
        end
        result[:data] = data
        result.to_json
      end
    end

    # Checks if an object is a collection
    #
    # @param resource [Object] to check
    # @param force_is_collection [NilClass] flag to overwrite
    # @return [TrueClass] upon success
    def self.is_collection?(resource, force_is_collection = nil)
      return force_is_collection unless force_is_collection.nil?

      resource.respond_to?(:size) && !resource.respond_to?(:each_pair)
    end

    # Resolves resource serializer class
    #
    # @return [Class]
    def self.serializer_class(resource, is_collection)
      klass = resource.class
      klass = resource.first.class if is_collection

      "#{klass.name}Serializer".constantize
    end

    # Resolves the model name used as the sparse-fieldset type key
    #
    # Mirrors `ActiveModel::Serializer#json_key`, which AMS uses to look a
    # type up in the fieldset: `object.class.model_name.to_s.underscore`.
    # NOT `model_name.singular` — that tr()s the namespace separator to an
    # underscore (`manufacturing_work_order`), so for a namespaced model the
    # key never matched, the primary type went unconstrained, and AMS fell
    # through to the pluralised collection key whose value is an empty list:
    # every attribute of the primary resource was silently dropped.
    #
    # @param many [Boolean] indicates whether the resource is a collection
    # @param resource [Object] serialized resource or collection
    # @return [String, nil] model name when available
    def self.fetch_name(many, resource)
      record = many ? collection_model(resource) : resource
      model_name = record&.model_name
      model_name && model_name.to_s.underscore
    end

    # Root key for a collection AMS cannot infer one for
    #
    # `AMS::CollectionSerializer#json_key` reads the root from its first
    # element, or from a named collection (`ActiveRecord::Relation` answers
    # `#name` through its klass). An EMPTY plain Array offers neither, so it
    # raises `CannotInferRootKeyError` the moment sparse fieldsets are
    # requested. Aggregation endpoints that render POROs hit exactly that.
    #
    # Returns nil whenever AMS can infer the key itself, so a collection that
    # already works keeps its own root and item serializers keep their
    # `json_key`.
    #
    # @param resource [Object] the collection being serialized
    # @param serializer_class [Class, NilClass] serializer for its members
    # @return [String, nil] pluralised root key, or nil to leave it to AMS
    def self.collection_root(resource, serializer_class)
      return nil unless resource.respond_to?(:empty?) && resource.empty?
      return nil if resource.respond_to?(:name)

      name = serializer_name(serializer_class)
      name && name.pluralize
    end

    # Sets the collection root only when AMS could not work one out
    #
    # @param options [Hash] render options, mutated in place
    # @param resource [Object] the collection being serialized
    # @param serializer_class [Class, NilClass] serializer for its members
    # @return [NilClass]
    def self.assign_collection_root!(options, resource, serializer_class)
      return if options[:root]

      root = collection_root(resource, serializer_class)
      options[:root] = root if root
      nil
    end

    # Resolves the type name a serializer class stands for
    #
    # @param serializer_class [Class, NilClass] e.g. `V1::UserSerializer`
    # @return [String, nil] e.g. `"user"`
    def self.serializer_name(serializer_class)
      name = serializer_class && serializer_class.name
      name && name.demodulize.delete_suffix("Serializer").underscore
    end

    # Resolves the record a collection's model name should come from
    #
    # @param resource [Object] the collection
    # @return [Object, NilClass] a record responding to `model_name`
    def self.collection_model(resource)
      return resource if resource.is_a?(ActiveRecord::Relation)

      resource.respond_to?(:first) ? resource.first : nil
    end
  end
end
