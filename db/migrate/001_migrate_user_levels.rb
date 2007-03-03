class MigrateUserLevels < ActiveRecord::Migration
  def self.up
    execute("UPDATE users SET level = 20 WHERE level = 3")
    execute("UPDATE users SET level = 10 WHERE level = 1")
    execute("UPDATE users SET level = 2 WHERE level < 10")
  end

  def self.down
    execute("UPDATE users SET level = 0 WHERE level = 2")
    execute("UPDATE users SET level = 1 WHERE level = 10")
    execute("UPDATE users SET level = 3 WHERE level = 20")
  end
end
