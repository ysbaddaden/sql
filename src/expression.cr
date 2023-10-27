require "./operators"

class SQL
  alias Expression = BinaryOperation | UnaryOperation | InOperation | Column | Function | Symbol | ValueType | Raw | Wrap
end
