class SQL::Query
  struct Raw
    include Operators

    getter sql : String

    def initialize(@sql)
    end
  end
end
