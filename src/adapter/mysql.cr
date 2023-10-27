class SQL
  struct Adapter::MySQL < Adapter
    QUOTE_CHARACTER = '`'

    protected def to_sql_on_conflict(on_conflict : NamedTuple) : Nil
      if update = on_duplicate_key[:update]?
        to_sql_on_duplicate_key_update(update)
      else
        raise "Error: expected NamedTuple(update:) but got #{on_conflict.class.name}"
      end
    end

    protected def to_sql_on_duplicate_key_update(update : NamedTuple) : Nil
      @sql << " ON DUPLICATE KEY UPDATE "
      to_sql_update_set(update)
    end

    protected def to_sql_on_duplicate_key_update(update : Hash) : Nil
      @sql << " ON DUPLICATE KEY UPDATE "
      to_sql_update_set(update)
    end

    protected def to_sql_on_duplicate_key_update(update : Enumerable(Symbol)) : Nil
      update.each_with_index do |column, i|
        @sql << ", " unless i == 0
        @sql << quote(column)
        @sql << " = VALUES("
        @sql << quote(column)
        @sql << ')'
      end
    end

    protected def to_sql_returning(_x) : NoReturn
      raise "MySQL doesn't support RETURNING statements"
    end
  end

  Adapter.register("mysql", Adapter::MySQL)
end
