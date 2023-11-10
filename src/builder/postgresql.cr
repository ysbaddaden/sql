class SQL
  class Builder::PostgreSQL < Builder
    @@positional_arguments = false

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

    protected def to_sql_on_conflict(on_conflict) : Nil
      @sql << " ON CONFLICT"

      case on_conflict
      in Symbol
        to_sql_on_conflict_action(on_conflict)
      in Tuple
        @sql << " ("
        to_sql_column_list(on_conflict[0])
        @sql << ')'
        to_sql_on_conflict_action(on_conflict[1])
      end
    end

    protected def to_sql_on_conflict_action(action : Symbol) : Nil
      if action == :do_nothing
        @sql << " DO NOTHING"
      else
        raise "Error: expected :do_nothing but got #{action.inspect}"
      end
    end

    protected def to_sql_on_conflict_action(action : NamedTuple) : Nil
      if update = action[:do_update_set]?
        @sql << " DO UPDATE SET "
        to_sql_on_conflict_do_update_set(update)
      else
        raise "Error: missing :do_update_set action"
      end
    end

    protected def to_sql_on_conflict_do_update_set(update : NamedTuple) : Nil
      to_sql_update_set(update)
    end

    protected def to_sql_on_conflict_do_update_set(update : Hash) : Nil
      to_sql_update_set(update)
    end

    protected def to_sql_on_conflict_do_update_set(column : Symbol) : Nil
      to_sql_on_conflict_do_update_set({column})
    end

    protected def to_sql_on_conflict_do_update_set(update : Enumerable(Symbol)) : Nil
      update.each_with_index do |column, i|
        @sql << ", " unless i == 0
        @sql << quote(column)
        @sql << " = "
        @sql << "EXCLUDED."
        @sql << quote(column)
      end
    end

    protected def to_sql_on_duplicate_key_update(update) : Nil
      raise "PostgreSQL doesn't support ON DUPLICATE KEY UPDATE clauses"
    end
  end

  Builder.register("postgres", Builder::PostgreSQL)
  Builder.register("postgresql", Builder::PostgreSQL)
end
