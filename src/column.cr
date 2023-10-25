require "./operators"

class SQL
  struct Column
    include Operators

    getter table : Table
    getter name : Symbol

    def initialize(@table : Table, @name : Symbol)
    end

    def table_name
      @table.__table_as? || @table.__table_name
    end
  end
end