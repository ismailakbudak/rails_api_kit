module ApiKit
  # Inclusion and sparse fields support
  module Fetching
    private
      # Extracts and formats sparse fieldsets for Active Model Serializers
      #
      # Ex.: `GET /resource?fields[relationship]=id,created_at`
      #
      # @return [Hash] in Active Model Serializers format
      def api_fields(serializer_class = nil, model_name = nil)
        return unless params[:fields].respond_to?(:each_pair)

        result = []

        if serializer_class
          model_name ||= serializer_class.name.demodulize.delete_suffix("Serializer").underscore
        end

        keys = []
        params[:fields].each do |k, v|
          field_names = v.to_s.split(",").map(&:strip).compact.map(&:to_sym)
          result << { k.to_sym => field_names }
          keys << k
        end

        if model_name && serializer_class && !keys.include?(model_name)
          result << { model_name.to_sym => serializer_class._attributes }
        end

        result
      end

      # Extracts and whitelists allowed includes
      #
      # Ex.: `GET /resource?include=relationship,relationship.subrelationship`
      #
      # @return [Array]
      def api_include
        params["include"].to_s.split(",").map(&:strip).compact
      end
  end
end