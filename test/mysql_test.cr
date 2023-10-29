require "./test_helper"

class MysqlTest < Minitest::Test
  def sql
    SQL.new("mysql://")
  end

  def test_select
    skip "todo: write one big select query"
  end

  def test_on_duplicate_key_update
    assert_query(%(INSERT INTO `users` (`name`, `email`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `name` = VALUES(`name`)), ["John", "john.doe@example.org"], sql.insert do
      {
        into:                    users,
        values:                  {name: "John", email: "john.doe@example.org"},
        on_duplicate_key_update: {:name},
      }
    end)

    assert_query(%(INSERT INTO `users` (`name`, `email`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `name` = VALUES(`name`)), ["John", "john.doe@example.org"], sql.insert do
      {
        into:                    users,
        values:                  {name: "John", email: "john.doe@example.org"},
        on_duplicate_key_update: :name,
      }
    end)

    assert_query(%(INSERT INTO `users` (`name`, `email`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `name` = ?), ["John", "john.doe@example.org", "John"], sql.insert do
      {
        into:                    users,
        values:                  {name: "John", email: "john.doe@example.org"},
        on_duplicate_key_update: {name: "John"},
      }
    end)

    assert_query(%(INSERT INTO `users` (`email`, `name`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `name` = ?), ["jane.doe@example.org", "jane", "John"], sql.insert do
      {
        into:                    users,
        values:                  {email: "jane.doe@example.org", name: "jane"},
        on_duplicate_key_update: {users.name => "John"},
      }
    end)
  end

  def test_on_conflict_do_nothing
    assert_raises do
      sql.insert do
        {
          into:        users,
          values:      {email: "jane.doe@example.org"},
          on_conflict: :do_nothing,
        }
      end
    end
  end

  def test_on_conflict_do_update_set
    assert_raises do
      sql.insert do
        {
          into:        users,
          values:      {email: "jane.doe@example.org"},
          on_conflict: {:email, {do_update_set: {count: column(:count) + 1}}},
        }
      end
    end
  end

  def test_returning
    assert_raises do
      sql.insert do
        {
          into:      users,
          values:    {email: "jane.doe@example.org"},
          returning: :*,
        }
      end
    end

    assert_raises do
      sql.update do
        {
          update:    users,
          set:       {email: "jane.doe@example.org"},
          returning: :*,
        }
      end
    end
  end
end
