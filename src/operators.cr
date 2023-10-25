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
  end
end

require "./function"
require "./binary_operation"
require "./unary_operation"
