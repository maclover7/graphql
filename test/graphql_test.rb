require 'test_helper'

class SingleLevelQueryTest < Minitest::Test
  def test_basic_query
    assert_equal(
      { :data => { "hello" => "world" } },
      graphql_with(basic_schema).execute('{ hello }')
    )
  end

  def test_type_not_in_schema_query
    e = assert_raises(ArgumentError) do
      graphql_with(basic_schema).execute('{ goodbye }')
    end

    assert_equal(
      "'goodbye' is not in the schema!",
      e.message
    )
  end

  def test_two_root_types_query
    assert_equal(
      { :data => { "hello" => "world", "hello" => "world" } },
      graphql_with(basic_schema).execute('{ hello hello }')
    )
  end

  def test_context_received
    @context = nil

    schema = {
      'hello' => {
        'resolve' => ->(args, context) do
          @context = context
          'world'
        end
      }
    }

    context = { current_user: 'Current User' }

    assert_equal(
      { :data => { "hello" => "world" } },
      graphql_with(schema).execute('{ hello }', context: context)
    )

    assert_equal(context, @context)
  end

  def test_one_arg_received
    @args = nil

    schema = {
      'hello' => {
        'resolve' => ->(args, context) do
          @args = args
          'world'
        end
      }
    }

    assert_equal(
      { :data => { "hello" => "world" } },
      graphql_with(schema).execute('{ hello(id: 1) }')
    )

    assert_equal({ "id" => '1' }, @args)
  end

  def test_multiple_args_received
    @args = nil

    schema = {
      'hello' => {
        'resolve' => ->(args, context) do
          @args = args
          'world'
        end
      }
    }

    assert_equal(
      { :data => { "hello" => "world" } },
      graphql_with(schema).execute('{ hello(id1: 1, id2: 2) }')
    )

    assert_equal({ "id1" => "1", "id2" => "2" }, @args)
  end

  def test_nested_fields_query
    assert_equal(
      { :data => { "user" => { 'name' => "MyUser" } } },
      graphql_with(user_schema).execute('{ user { name } }')
    )
  end

  private

  class User
    def self.find(id)
      User.new
    end

    def name
      'MyUser'
    end
  end

  def basic_schema
    {
      'hello' => {
        'resolve' => ->(args, _context) { 'world' }
      }
    }
  end

  def user_schema
    {
      'user' => {
        'fields' => {
          'name' => {}
        },
        'resolve' => ->(args, _context) { User.new }
      }
    }
  end

  def graphql_with(schema)
    GraphQL.new(schema)
  end
end
