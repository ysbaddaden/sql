class SQL
  module Operators
    def +(other : Expression) : BinaryOperation
      BinaryOperation.new(self, "+", other)
    end

    def -(other : Expression) : BinaryOperation
      BinaryOperation.new(self, "-", other)
    end

    def *(other : Expression) : BinaryOperation
      BinaryOperation.new(self, "*", other)
    end

    def /(other : Expression) : BinaryOperation
      BinaryOperation.new(self, "/", other)
    end

    def <(other : Expression) : BinaryOperation
      BinaryOperation.new(self, "<", other)
    end

    def <=(other : Expression) : BinaryOperation
      BinaryOperation.new(self, "<=", other)
    end

    def ==(other : Expression) : UnaryOperation | BinaryOperation
      if other.nil?
        UnaryOperation.new(self, "IS NULL")
      else
        BinaryOperation.new(self, "=", other)
      end
    end

    def !=(other : Expression) : UnaryOperation | BinaryOperation
      if other.nil?
        UnaryOperation.new(self, "IS NOT NULL")
      else
        BinaryOperation.new(self, "<>", other)
      end
    end

    def >=(other : Expression) : BinaryOperation
      BinaryOperation.new(self, ">=", other)
    end

    def >(other : Expression) : BinaryOperation
      BinaryOperation.new(self, ">", other)
    end

    def like(other : String) : BinaryOperation
      BinaryOperation.new(self, "LIKE", other)
    end

    def in(other : Enumerable) : InOperation
      InOperation.new(self, "IN", [*other] of ValueType)
    end

    def not_in(other : Enumerable) : InOperation
      InOperation.new(self, "NOT IN", [*other] of ValueType)
    end
  end
end

require "./function"
require "./binary_operation"
require "./in_operation"
require "./unary_operation"
