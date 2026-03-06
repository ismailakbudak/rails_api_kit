# ApiKit

A lightweight Rails toolkit for building standardized, structured API responses with serialization, error handling, filtering, sorting, and pagination.

> Building clean, consistent APIs shouldn't be rocket science. ApiKit provides simple, powerful modules to get you up and running quickly.

## Features

ApiKit offers a collection of lightweight modules that integrate seamlessly with your Rails controllers:

* **Object serialization** - Powered by Active Model Serializers
* **Error handling** - Standardized error responses for parameters, validation, and generic errors
* **Fetching** - Support for relationship includes and sparse fieldsets
* **Filtering & Sorting** - Advanced filtering and sorting powered by Ransack
* **Pagination** - Built-in pagination support with links and metadata

## Installation

**Requirements:**
- Ruby 3.3.0 or higher
- Rails 8.0 or higher

Add this line to your application's Gemfile:

```ruby
gem "api_kit"
```

And then execute:

    $ bundle install

## Quick Start

### 1. Enable Rails Integration

Add this to an initializer:

```ruby
# config/initializers/api_kit.rb
require "api_kit"

ApiKit::RailsApp.install!
```

This registers the media type and renderers.

### 2. Basic Usage

```ruby
class UsersController < ApplicationController
  include ApiKit::Filtering
  include ApiKit::Pagination

  def index
    allowed_fields = [ :first_name, :last_name, :created_at ]

    api_filter(User.all, allowed_fields) do |filtered|
      api_paginate(filtered.result) do |paginated|
        render api_paginate: paginated
      end
    end
  end

  def show
    user = User.find(params[:id])
    render api: user
  end
end
```

### 3. Create Serializers

```ruby
class UserSerializer < ActiveModel::Serializer
  attributes :id, :first_name, :last_name, :email, :created_at, :updated_at

  has_many :posts
end
```

## Core Modules

### ApiKit::Filtering

Provides powerful filtering and sorting using Ransack:

```ruby
class UsersController < ApplicationController
  include ApiKit::Filtering

  def index
    allowed_fields = [ :first_name, :last_name, :email, :posts_title ]

    api_filter(User.all, allowed_fields) do |filtered|
      render api: filtered.result
    end
  end
end
```

**Example requests:**
```bash
# Filter by first name containing "John"
GET /users?filter[first_name_cont]=John

# Sort by last name descending, then first name ascending
GET /users?sort=-last_name,first_name

# Complex filtering with relationships
GET /users?filter[posts_title_matches_any]=Ruby,Rails&sort=-created_at
```

#### Sorting with Expressions

Enable aggregation expressions for advanced sorting:

```ruby
def index
  allowed_fields = [ :first_name, :posts_count ]
  options = { sort_with_expressions: true }

  api_filter(User.joins(:posts), allowed_fields, options) do |filtered|
    render api: filtered.result.group("users.id")
  end
end
```

```bash
# Sort by post count
GET /users?sort=-posts_count_sum
```

### ApiKit::Pagination

Handles pagination with standardized links:

```ruby
class UsersController < ApplicationController
  include ApiKit::Pagination

  def index
    api_paginate(User.all) do |paginated|
      render api_paginate: paginated
    end
  end

  private

  def api_meta(resources)
    {
      pagination: api_pagination_meta(resources),
      total: resources.respond_to?(:count) ? resources.count : resources.size
    }
  end
end
```

**Example requests:**
```bash
# Get page 2 with 20 items per page
GET /users?page[number]=2&page[size]=20
```

### ApiKit::Fetching

Supports relationship inclusion and sparse fieldsets:

```ruby
class UsersController < ApplicationController
  include ApiKit::Fetching

  def index
    render api: User.all
  end

  private

  def api_include
    # Whitelist allowed includes
    super & [ "posts", "profile" ]
  end
end
```

**Example requests:**
```bash
# Include related posts
GET /users?include=posts

# Sparse fieldsets
GET /users?fields[user]=first_name,last_name
```

### ApiKit::Errors

Standardized error responses for common Rails exceptions:

```ruby
class UsersController < ApplicationController
  include ApiKit::Errors

  def create
    user = User.new(user_params)

    if user.save
      render api: user, status: :created
    else
      render api_errors: user.errors, status: :unprocessable_entity
    end
  end

  def update
    user = User.find(params[:id])

    if user.update(user_params)
      render api: user
    else
      render api_errors: user.errors, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:data).require(:attributes).permit(:first_name, :last_name, :email)
  end

  def render_api_internal_server_error(exception)
    # Custom exception handling (e.g., error tracking)
    # Sentry.capture_exception(exception)
    super(exception)
  end
end
```

**Handled exceptions:**
- `StandardError` → 500 Internal Server Error
- `ActiveRecord::RecordNotFound` → 404 Not Found
- `ActionController::ParameterMissing` → 422 Unprocessable Entity

## Advanced Configuration

### Custom Serializer Resolution

```ruby
class UsersController < ApplicationController
  def index
    render api: User.all, serializer_class: CustomUserSerializer
  end

  private

  def api_serializer_class(resource, is_collection)
    ApiKit::RailsApp.serializer_class(resource, is_collection)
  rescue NameError
    "#{resource.class.name}Serializer".constantize
  end
end
```

### Custom Page Size

```ruby
def api_page_size(pagination_params)
  per_page = pagination_params[:size].to_i
  return 30 if per_page < 1 || per_page > 100
  per_page
end
```

### Serializer Parameters

```ruby
def api_serializer_params
  {
    current_user: current_user,
    include_private: params[:include_private].present?
  }
end
```

## Configuration

### Environment Variables

- `PAGINATION_LIMIT` - Default page size (default: 30)

### Dependencies

This gem leverages these excellent libraries:
- [Active Model Serializers](https://github.com/rails-api/active_model_serializers) - Object serialization
- [Ransack](https://github.com/activerecord-hackery/ransack) - Advanced filtering and sorting

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/iakbudak/api_kit

This project follows the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## Development

After checking out the repo:

```bash
bundle install
bundle exec rspec  # Run tests
bundle exec rubocop  # Check code style
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).