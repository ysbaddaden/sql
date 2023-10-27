require "./operators"

class SQL
  # TODO: rename as Column
  struct Wrap
    include Operators

    getter name : Symbol

    def initialize(@name : Symbol)
    end
  end
end
