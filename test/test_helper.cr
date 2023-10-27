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

      def id : Column
        Column.new(self, :id)
      end

      def group_id : Column
        Column.new(self, :group_id)
      end

      def email : Column
        Column.new(self, :email)
      end

      def name : Column
        Column.new(self, :name)
      end

      def created_at : Column
        Column.new(self, :created_at)
      end
    end

    struct Groups < Table
      def initialize(@__table_as = nil)
        @__table_name = :groups
      end

      def id : Column
        Column.new(self, :id)
      end

      def name : Column
        Column.new(self, :name)
      end
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
