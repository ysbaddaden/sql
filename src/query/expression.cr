require "./operators"

class SQL::Query
  alias ColumnType = Column | Raw | Symbol
  alias Expression = BinaryOperation | UnaryOperation | InOperation | Function | ColumnType | ValueType
end
