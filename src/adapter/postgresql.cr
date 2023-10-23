require "./adapter"

class SQL
  struct Adapter::PostgreSQL < Adapter
    def prepared_statement_placeholder(value : ValueType) : Nil
      if index = @args.index(value)
        @sql << '$'
        @sql << (index + 1)
      else
        @args << value
        @sql << '$'
        @sql << @args.size
      end
    end
  end

  Adapter.register("postgres", Adapter::PostgreSQL)
  Adapter.register("postgresql", Adapter::PostgreSQL)
end
