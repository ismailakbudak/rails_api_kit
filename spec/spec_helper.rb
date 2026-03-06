require 'bundler/setup'
require 'simplecov'

SimpleCov.start do
  add_group 'Lib', 'lib'
  add_group 'Tests', 'spec'
end
SimpleCov.minimum_coverage 90

require 'dummy'
require 'ffaker'
require 'rspec/rails'
Dir[File.join(__dir__, 'support', '**', '*.rb')].sort.each { |file| require file }

RSpec.configure do |config|
  config.include ApiKit::RSpec

  config.use_transactional_fixtures = true
  config.mock_with :rspec
  config.filter_run_when_matching :focus
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Silence ActiveModelSerializers logs during tests
  if defined?(ActiveModelSerializers)
    ActiveModelSerializers.logger = Logger.new(nil)
  end
end

module RSpecHelpers
  include Dummy.routes.url_helpers

  # Helper to return valid API headers
  #
  # @return [Hash] the relevant content type &co
  def api_headers
    { 'Content-Type': Mime[:json].to_s }
  end

  # Parses and returns a deserialized JSON
  #
  # @return [Hash]
  def response_json
    JSON.parse(response.body)
  end

  # Creates an user
  #
  # @return [User]
  def create_user
    User.create!(
      first_name: FFaker::Name.first_name,
      last_name: FFaker::Name.last_name
    )
  end

  # Creates a note
  #
  # @return [Note]
  def create_note(user = nil)
    Note.create!(
      title: FFaker::Company.name,
      quantity: rand(10),
      user: (user || create_user)
    )
  end
end

module Rails4RequestMethods
  [ :get, :post, :put, :delete ].each do |method_name|
    define_method(method_name) do |path, named_args|
      super(
        path,
        named_args.delete(:params),
        named_args.delete(:headers)
      )
    end
  end
end

RSpec.configure do |config|
  config.include RSpecHelpers, type: :request
  config.include RSpecHelpers, type: :controller
end
