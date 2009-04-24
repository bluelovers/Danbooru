class AddCascadingForeignKeyToArtistUrls < ActiveRecord::Migration
  def self.up
    execute "delete from artist_urls where artist_id not in (select id from artists)"
    remove_foreign_key "artist_urls", "artist_urls_artist_id_fkey"
    add_foreign_key "artist_urls", "artist_id", "artists", "id", :on_delete => :cascade
  end

  def self.down
    remove_foreign_key "artist_urls", "artist_urls_artist_id_fkey"
    add_foreign_key "artist_urls", "artist_id", "artists", "id"
  end
end
