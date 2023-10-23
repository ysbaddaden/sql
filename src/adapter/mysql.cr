require "./adapter"

# TODO: consider enabling MySQL ANSI mode by default

class SQL
  struct Adapter::MySQL < Adapter
    QUOTE_CHARACTER = '`'

    def on_conflict_do_ignore_statement : Nil
      # TODO: consider a dull update (ON DUPLICATE KEY UPDATE id = id)
      raise NotImplementedError.new("MySQL only supports ON DUPLICATE KEY UPDATE (it doesn't implement IGNORE)")
    end

    def on_conflict_do_update_statement(update : Hash) : Nil
      @sql << " ON DUPLICATE KEY UPDATE SET "
      update_statement(update)
    end

    def on_conflict_do_update_statement(update : Enumerable(Symbol)) : Nil
      @sql << " ON DUPLICATE KEY UPDATE SET "

      update.each_with_index do |column_name, i|
        @sql << ", " unless i == 0
        quote(column_name)
        @sql << " = "
        @sql << "VALUES("
        quote(column_name)
        @sql << ')'
      end
    end
  end

  Adapter.register("mysql", Adapter::MySQL)
end
