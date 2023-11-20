class SQL
  class InOperation
    include Operators

    getter lhs : Expression
    getter rhs : Array(ValueType) | Proc(Nil)
    getter operator : String

    def initialize(@lhs, @operator, @rhs)
    end

    def and(other : Expression) : BinaryOperation
      BinaryOperation.new(self, "AND", other)
    end

    def or(other : Expression) : BinaryOperation
      BinaryOperation.new(self, "OR", other)
    end
  end
end
