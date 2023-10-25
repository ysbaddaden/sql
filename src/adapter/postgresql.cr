class SQL
  struct Adapter::PostgreSQL < Adapter
    protected def to_sql_statement_placeholder(value : ValueType) : Nil
      if index = @args.index(value)
        @sql << '$'
        @sql << (index + 1)
      else
        @args << value
        @sql << '$'
        @sql << @args.size
      end
    end

    protected def to_sql_on_conflict(on_conflict : Symbol) : Nil
      if on_conflict == :nothing
        @sql << " ON CONFLICT DO NOTHING"
      else
        raise "Error: expected :nothing or :ignore but got #{on_conflict}"
      end
    end

    protected def to_sql_on_conflict(on_conflict : NamedTuple) : Nil
      if update = on_conflict[:update]?
        to_sql_on_conflict_update(update)
      else
        raise "Error: expected NamedTuple(update:) but got #{on_conflict.class.name}"
      end
    end

    protected def to_sql_on_conflict_update(update : NamedTuple) : Nil
      @sql << " ON CONFLICT DO UPDATE SET "
      to_sql_update_set(update)
    end

    protected def to_sql_on_conflict_update(update : Hash) : Nil
      @sql << " ON CONFLICT DO UPDATE SET "
      to_sql_update_set(update)
    end

    protected def to_sql_on_conflict_update(update : Enumerable(Symbol)) : Nil
      update.each_with_index do |column, i|
        @sql << ", " unless i == 0
        @sql << quote(column)
        @sql << " = "
        @sql << "EXCLUDED."
        @sql << quote(column)
      end
    end
  end

  Adapter.register("postgres", Adapter::PostgreSQL)
  Adapter.register("postgresql", Adapter::PostgreSQL)
end
