class ResetPostScores < ActiveRecord::Migration
  def self.up
    ActiveRecord::Base.connection.execute("SET statement_timeout=0")
    ActiveRecord::Base.connection.execute("UPDATE posts SET score = coalesce((SELECT COUNT(*) FROM favorites f JOIN users u ON u.id = f.user_id WHERE u.level >= 30 AND f.post_id = posts.id), 0)")
  end

  def self.down
  end
end
