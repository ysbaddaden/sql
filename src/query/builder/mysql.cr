require "./generic"

module SQL::Query::Builder
  class MySQL < Generic
    @[AlwaysInline]
    protected def quote_character
      '`'
    end

    @[AlwaysInline]
    protected def escaped_quote_character
      %(\\`)
    end
  end

  Builder.register("mysql", MySQL)
end
