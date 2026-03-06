module ApiKit
  module RSpec
    module_function

    def as_indifferent_hash(doc)
      return doc unless ::RSpec.configuration.apikit_indifferent_hash

      if doc.respond_to?(:with_indifferent_access)
        return doc.with_indifferent_access
      end

      JSON.parse(JSON.generate(doc))
    end
  end
end

::RSpec.configure do |config|
  config.add_setting :apikit_indifferent_hash, default: true
end

::RSpec::Matchers.define :have_link do |link|
  match do |actual|
    actual = ApiKit::RSpec.as_indifferent_hash(actual)
    actual.key?('links') && actual['links'].key?(link.to_s) &&
      (!@val_set || actual['links'][link.to_s] == @val)
  end

  chain :with_value do |val|
    @val_set = true
    @val = val
  end
end

::RSpec::Matchers.define :have_links do |*links|
  match do |actual|
    actual = ApiKit::RSpec.as_indifferent_hash(actual)
    return false unless actual.key?('links')

    links.all? { |link| actual['links'].key?(link.to_s) }
  end
end
