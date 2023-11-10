require "db"
require "./sql"
require "./information_schema/*"

class SQL
  abstract class InformationSchema
    @@registers = {} of String => InformationSchema.class

    def self.register(name : String, klass : InformationSchema.class)
      @@registers[name] = klass
    end

    def self.fetch(name : String) : InformationSchema.class
      @@registers[name]?.not_nil! "Unknown SQL driver: #{name}"
    end

    def self.fetch(name : Nil) : NoReturn
      name.not_nil! "Unknown SQL driver: #{name}"
    end

    @db : DB::Database

    def self.new(uri : String)
      new URI.parse(uri)
    end

    def initialize(@uri : URI)
      @db = DB.open(@uri)
      @sql = SQL.new(@uri)
    end

    def driver_name : String
      @uri.scheme.not_nil!
    end

    def database_name : String
      if @uri.path.starts_with?('/')
        @uri.path[1..]
      else
        @uri.path
      end
    end

    abstract def tables : Array(Table)
    abstract def columns(table_name : String) : Array(InformationSchema::Column)

    def generate_table_schemas(io : IO) : Nil
      io << "class SQL\n"
      io << "  module TableSchemas\n"

      tables.each_with_index do |table, i|
        klass_name = table.name.camelcase

        io << '\n' unless i == 0
        io << "    struct " << klass_name << " < ::SQL::Table\n"
        io << "      def initialize(@__table_as = nil)\n"
        io << "        @__table_name = :" << table.name << '\n'
        io << "      end\n\n"

        columns(table.name).each_with_index do |column, j|
          method_name = column.name.underscore

          io << '\n' unless j == 0
          io << "      def " << method_name << " : ::SQL::Column\n"
          io << "        ::SQL::Column.new(self, :" << column.name << ")\n"
          io << "      end\n"
        end

        io << "    end\n"
      end

      tables.each_with_index do |table|
        klass_name = table.name.camelcase
        method_name = table.name.underscore

        io << '\n'
        io << "    @[AlwaysInline]\n"
        io << "    def " << method_name << "(as name : Symbol? = nil) : " << klass_name << '\n'
        io << "      " << klass_name << ".new(name)\n"
        io << "    end\n"
      end

      io << "  end\n"
      io << "end\n"
    end
  end
end
