require "minitest/autorun"
require "../src/sql"
require "../src/builder/*"

class Minitest::Test
  # Tests assume PostgreSQL by default. Individual tests may test other
  # databases.
  def sql
    SQL.new("postgres://")
  end

  def assert_format(expected_sql : String, expected_args : Array, message = nil, file = __FILE__, line = __LINE__, &)
    {% if flag?(:DEBUG) %}
      puts actual[0]
      puts actual[1].inspect
      puts
    {% end %}
    actual = sql.format { |q| yield q }
    expected = expected_sql.gsub(/\s+/, ' ')
    assert_equal({expected, expected_args}, actual, message, file, line)
  end

  def assert_format(expected : String, message = nil, file = __FILE__, line = __LINE__, &)
    assert_format(expected, [] of SQL::ValueType, message, file, line) { |q| yield q }
  end
end

class SQL
  module Schemas
    # TODO: automatically generate the schemas from the database

    struct Users < Table
      table_name :users

      column :user_id
      column :group_id
      column :email
      column :name
      column :created_at
    end

    struct Groups < Table
      table_name :groups

      column :group_id
      column :name
      column :counter
      column :created_at
      column :updated_at
    end

    protected def users(as name : Symbol? = nil) : Users
      Users.new(name)
    end

    protected def groups(as name : Symbol? = nil) : Groups
      Groups.new(name)
    end
  end
end
