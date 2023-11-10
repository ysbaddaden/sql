class SQL
  class UnaryOperation
    include Operators

    getter expression : Expression
    getter operator : String

    def initialize(@expression, @operator)
    end

    def and(other : Expression) : BinaryOperation
      BinaryOperation.new(self, "AND", other)
    end

    def or(other : Expression) : BinaryOperation
      BinaryOperation.new(self, "OR", other)
    end
  end
end
