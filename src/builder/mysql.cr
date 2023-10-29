class SQL
  struct Builder::MySQL < Builder
    @@quote_character = '`'

    protected def to_sql_on_conflict(on_conflict) : Nil
      raise "MySQL doesn't support ON CONFLICT clauses"
    end

    protected def to_sql_on_duplicate_key_update(update : Hash) : Nil
      @sql << " ON DUPLICATE KEY UPDATE "
      to_sql_update_set(update)
    end

    protected def to_sql_on_duplicate_key_update(update : NamedTuple) : Nil
      @sql << " ON DUPLICATE KEY UPDATE "
      to_sql_update_set(update)
    end

    protected def to_sql_on_duplicate_key_update(update : Symbol) : Nil
      to_sql_on_duplicate_key_update({update})
    end

    protected def to_sql_on_duplicate_key_update(update : Enumerable(Symbol)) : Nil
      @sql << " ON DUPLICATE KEY UPDATE "

      update.each_with_index do |column, i|
        @sql << ", " unless i == 0
        to_sql column
        @sql << " = VALUES("
        to_sql column
        @sql << ')'
      end
    end

    protected def to_sql_returning(_x) : NoReturn
      raise "MySQL doesn't support RETURNING clauses"
    end
  end

  Builder.register("mysql", Builder::MySQL)
end
