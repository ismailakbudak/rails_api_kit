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
          data = ActiveModelSerializers::SerializableResource.new(resource, options).as_json
        else
          data = ActiveModelSerializers::SerializableResource.new([resource], options).as_json[0]
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

    def self.fetch_name(many, resource)
      if many
        if resource.is_a?(ActiveRecord::Relation)
          resource&.model_name&.singular
        else
          resource.first&.model_name&.singular
        end
      else
        resource&.model_name&.singular
      end
    end
  end
end