require "./operators"

class SQL
  # TODO: rename as TableColumn or Table::Column
  struct Column
    include Operators

    getter table : Table
    getter name : Symbol

    def initialize(@table : Table, @name : Symbol)
    end

    def table_name
      @table.table_alias? || @table.table_name
    end
  end
end
