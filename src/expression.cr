class SQL
  alias Expression = BinaryOperation | UnaryOperation | Column | Function | ValueType

  module Operators
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

    def null? : UnaryOperation
      UnaryOperation.new(self, "IS NULL")
    end

    def not_null? : UnaryOperation
      UnaryOperation.new(self, "IS NOT NULL")
    end
  end

  class UnaryOperation
    include Operators

    getter expression : Expression
    getter operator : String

    def initialize(@expression, @operator)
    end
  end

  class BinaryOperation
    include Operators

    getter lhs : Expression
    getter rhs : Expression
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

  class Function
    include Operators

    getter name : Symbol
    getter args : Array(Expression | Symbol)

    def initialize(@name, @args)
    end
  end

  struct Column
    include Operators

    getter name : ColumnName

    def initialize(@name)
    end

    macro method_missing(call)
      if (%name = @name).is_a?(Symbol)
        Column.new({ %name, {{call.name.id.symbolize}} })
      else
        raise "BUG: too many nested levels"
      end
    end
  end
end
