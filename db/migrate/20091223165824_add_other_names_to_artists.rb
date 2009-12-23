class AddOtherNamesToArtists < ActiveRecord::Migration
  def self.up
    add_column :artists, :other_names_array, "text[]"
    add_column :artist_versions, :other_names_array, "text[]"

    add_index :artists, :other_names_array
    
    execute "create function rlike(text, text) returns bool as 'select $2 like $1' language sql strict immutable"
    execute "create operator ~~~ (procedure = rlike, leftarg = text, rightarg = text, commutator = ~~)"
  end

  def self.down
    remove_column :artists, :other_names_array
    remove_column :artist_versions, :other_names_array
    execute "drop operator ~~~ (text, text)"
    execute "drop function rlike(text, text)"
  end
end
