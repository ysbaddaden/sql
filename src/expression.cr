require "./operators"

class SQL
  alias Expression = BinaryOperation | UnaryOperation | Column | Function | Symbol | ValueType | Raw
end
