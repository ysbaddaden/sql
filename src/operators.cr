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

    def //(other : Expression) : BinaryOperation
      BinaryOperation.new(self, "DIV", other)
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

    def in(&other : Proc(Nil)) : InOperation
      InOperation.new(self, "IN", other)
    end

    def not_in(other : Enumerable) : InOperation
      InOperation.new(self, "NOT IN", [*other] of ValueType)
    end

    def not_in(&other : Proc(Nil)) : InOperation
      InOperation.new(self, "NOT IN", other)
    end

    # Chain a custom binary operator. For example:
    #
    # ```
    # table.col_a.operator("||", table.col_b)     # concat
    # table.json.operator("->>", "path.to.value") # json extract value
    # ```
    #
    # Whenever possible function names will lead to a better reading code, but
    # sometimes a specific operator doesn't have a function counterpart.
    def operator(op : String, rhs : Expression) : BinaryOperation
      BinaryOperation.new(self, op, rhs)
    end
  end
end

require "./functions"
require "./binary_operation"
require "./in_operation"
require "./unary_operation"
