class SQL::Query
  abstract struct Table
    getter? table_alias : Symbol?

    def self.[](table_alias)
      new table_alias
    end

    def initialize(as @table_alias : Symbol? = nil)
    end

    def self.table_name : Symbol
      raise NotImplementedError.new("{{@type}}.table_name : Symbol")
    end

    abstract def table_name : Symbol

    # Define the name of the underlying table.
    macro table_name(name)
      def self.table_name : Symbol
        {{name.id.symbolize}}
      end

      def table_name : Symbol
        {{name.id.symbolize}}
      end
    end

    # Define a column for the table.
    #
    # TODO: column aliases:
    #
    # ```
    # Groups.id(:gid) => "groups"."id" AS "gid"
    # Groups[:g].id(:gid) => "g"."id" AS "gid"
    # ```
    macro column(name, method_name = nil)
      {% method_name ||= name.underscore %}

      def self.{{method_name.id}}(as aliased : Symbol? = nil) : ::SQL::Query::Column
        ::SQL::Query::Column.new(table_name, {{name.id.symbolize}}, as: aliased)
      end

      def {{method_name.id}}(as aliased : Symbol? = nil) : ::SQL::Query::Column
        ::SQL::Query::Column.new(table_alias? || table_name, {{name.id.symbolize}}, as: aliased)
      end
    end
  end
end
