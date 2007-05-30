class CreateArtists < ActiveRecord::Migration
  def self.up
    execute(<<-EOS)
     CREATE TABLE artists (
       id SERIAL,
       japanese_name TEXT,
       personal_name TEXT,
       handle_name TEXT,
       circle_name TEXT,
       site_name TEXT,
       site_url TEXT,
       image_url TEXT
     )
    EOS
    execute("CREATE INDEX idx_artists__image_url ON artists (image_url)")
    execute("CREATE INDEX idx_artists__personal_name ON artists (personal_name) WHERE personal_name IS NOT NULL")
    execute("CREATE INDEX idx_artists__handle_name ON artists (handle_name) WHERE handle_name IS NOT NULL")
	artists = Tag.find(:all, :conditions => ["tag_type = ?", Tag.types[:artist]])
    artists.each do |artist|
      personal_name = artist.name

      page = WikiPage.find(:first, :conditions => ["title = ?", personal_name])
      if page && page.body =~ /"Home page":(\S+)/
        site_url = $1
      else
        site_url = nil
      end

      if page && page.body =~ /Japanese name:\s*(\S+)/
        japanese_name = $1
      else
        japanese_name = nil
      end

      image_url = File.dirname(Post.find(:first, :conditions => ["posts.id IN (SELECT pt.post_id FROM posts_tags pt, tags t WHERE t.id = pt.tag_id AND t.name = ?) AND posts.source IS NOT NULL AND posts.source <> ''", personal_name]).source) rescue nil

      Artist.create(:personal_name => personal_name, :site_url => site_url, :image_url => image_url, :japanese_name => japanese_name)
    end
  end

  def self.down
    execute("DROP TABLE artists")
  end
end
