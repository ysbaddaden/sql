class SQL
  class Builder::MySQL < Builder
    @@quote_character = '`'
  end

  Builder.register("mysql", Builder::MySQL)
end
