require "minitest/autorun"
require "../src/sql"
require "../src/builder/*"

class Minitest::Test
  # Tests assume PostgreSQL by default. Individual tests may test other
  # databases.
  def sql
    SQL.new("postgres://")
  end

  def assert_query(expected_sql : String, expected_args : Array, actual : {String, Array(SQL::ValueType)}, message = nil, file = __FILE__, line = __LINE__)
    {% if flag?(:DEBUG) %}
      puts actual[0]
      puts actual[1].inspect
      puts
    {% end %}
    assert_equal({expected_sql, expected_args}, actual, message, file, line)
  end

  def assert_query(expected : String, actual : {String, Array(SQL::ValueType)}, message = nil, file = __FILE__, line = __LINE__)
    assert_query(expected, [] of SQL::ValueType, actual, message, file, line)
  end
end

class SQL
  module Schemas
    # TODO: automatically generate the schemas from the database

    struct Users < Table
      def initialize(@__table_as = nil)
        @__table_name = :users
      end

      {% for col in %i[user_id group_id email name created_at] %}
        def {{col.id}} : Column
          Column.new(self, {{col}})
        end
      {% end %}
    end

    struct Groups < Table
      def initialize(@__table_as = nil)
        @__table_name = :groups
      end

      {% for col in %i[group_id name created_at] %}
        def {{col.id}} : Column
          Column.new(self, {{col}})
        end
      {% end %}
    end

    @[AlwaysInline]
    def users(as name : Symbol? = nil) : Users
      Users.new(name)
    end

    @[AlwaysInline]
    def groups(as name : Symbol? = nil) : Groups
      Groups.new(name)
    end
  end
end
