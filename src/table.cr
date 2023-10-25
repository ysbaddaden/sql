class SQL
  abstract struct Table
    getter __table_name : Symbol
    getter? __table_as : Symbol?

    private def initialize(@__table_name : Symbol, @__table_as : Symbol? = nil)
    end
  end
end
