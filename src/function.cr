require "./operators"

class SQL
  class Function
    include Operators

    getter name : Symbol
    getter? args : Array(Expression | Symbol)?

    def initialize(@name, @args = nil)
    end
  end
end
