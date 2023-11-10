require "./operators"

class SQL
  class Function
    include Operators

    getter name : Symbol
    getter? args : Array(Expression | Symbol)?

    def initialize(@name, @args = nil)
    end

    def over(partition : Builder) : Over
      Over.new(self, partition)
    end
  end

  class Over
    getter fn : Function
    getter partition : Builder

    def initialize(@fn, @partition)
    end
  end
end
