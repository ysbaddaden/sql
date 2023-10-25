class SQL
  class UnaryOperation
    include Operators

    getter expression : Expression
    getter operator : String

    def initialize(@expression, @operator)
    end
  end
end
