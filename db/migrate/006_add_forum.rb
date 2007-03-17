class AddForum < ActiveRecord::Migration
  def self.up
    execute(<<-EOS)
      CREATE TABLE forum_posts (
        id SERIAL,
        created_at TIMESTAMP NOT NULL,
        updated_at TIMESTAMP NOT NULL,
        parent_id INTEGER REFERENCES forum_posts ON DELETE CASCADE,
        user_id INTEGER NOT NULL REFERENCES users ON DELETE CASCADE,
        body TEXT NOT NULL,
        category INTEGER NOT NULL DEFAULT 1,
        response_count INTEGER NOT NULL DEFAULT 0
      )
    EOS
  end

  def self.down
  end
end
