module ApiKit
  # Serializer for JSON:API error responses

  class ErrorSerializer
    # The errors to be serialized
    # @return [Array, ActiveModel::Errors] the errors to be serialized
    attr_reader :errors

    # Serialization options
    # @return [Hash] serialization options
    attr_reader :options

    # Initialize the error serializer
    #
    # @param errors [ActiveModel::Errors, Array] errors to serialize
    # @param options [Hash] serialization options
    def initialize(errors, options = {})
      @errors = if errors.is_a?(ActiveModel::Errors)
                  errors.errors
      else
                  Array(errors)
      end
      @options = options
    end

    # Convert errors to JSON format
    #
    # @param args [Array] arguments passed to to_json
    # @return [String] JSON representation of errors
    def to_json(*args)
      { errors: serialized_errors }.to_json(*args)
    end

    private

    # Serialize errors into JSON:API format
    #
    # @return [Array<Hash>] array of serialized error objects
    def serialized_errors
      errors.map do |error|
        if error.is_a?(Array) && error.size == 2
          # Handle [attribute, error_hash] format from rails_app.rb
          serialize_validation_error(error[0], error[1])
        elsif error.is_a?(Hash)
          # Handle direct hash format
          serialize_hash_error(error)
        else
          # Handle generic errors
          serialize_generic_error(error)
        end
      end
    end

    # Serialize validation error from ActiveModel
    #
    # @param attribute [Symbol, String] the attribute with the error
    # @param error [Hash] the error details
    # @return [Hash] serialized error object
    def serialize_validation_error(attribute, error)
      {
        status: error[:status] || "422",
        code: error[:code] || "invalid",
        title: error[:title] || "Error",
        detail: error[:message],
        attribute: attribute
      }.compact
    end

    # Serialize hash-formatted error
    #
    # @param error [Hash] the error hash
    # @return [Hash] serialized error object
    def serialize_hash_error(error)
      {
        status: error[:status] || "422",
        code: error[:code] || "invalid",
        title: error[:title] || "Error",
        detail: error[:detail] || error["detail"]
      }.compact
    end

    # Serialize generic error object
    #
    # @param error [Object] the error object
    # @return [Hash] serialized error object
    def serialize_generic_error(error)
      {
        status: "422",
        code: error.type,
        title: "Error",
        detail: error.full_message,
        attribute: error.attribute
      }
    end
  end
end
