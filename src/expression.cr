require "./operators"

class SQL
  alias ColumnType = Column | Raw | Symbol | Wrap
  alias Expression = BinaryOperation | UnaryOperation | InOperation | Function | ColumnType | ValueType
end
