class ChangeArtistsA < ActiveRecord::Migration
	def self.up
		artists = Artist.find(:all)

		Artist.transaction do
			execute "ALTER TABLE artists ADD PRIMARY KEY (id)"
			execute "ALTER TABLE artists ADD COLUMN alias_id INTEGER REFERENCES artists ON DELETE SET NULL"
			execute "ALTER TABLE artists ADD COLUMN group_id INTEGER REFERENCES artists ON DELETE SET NULL"
			execute "ALTER TABLE artists RENAME COLUMN site_url TO url_a"
			execute "ALTER TABLE artists RENAME COLUMN image_url TO url_b"
			execute "ALTER TABLE artists ADD COLUMN url_c TEXT"
			execute "ALTER TABLE artists ADD COLUMN name TEXT NOT NULL DEFAULT ''"
			execute "ALTER TABLE artists ALTER COLUMN name DROP DEFAULT"

			artists.each do |artist|
				reference_name = artist.name

				execute ActiveRecord::Base.sanitize_sql(["INSERT INTO artists (name, url_a, url_b) VALUES (?, ?, ?)", reference_name, artist.site_url, artist.image_url])

				%w(personal_name handle_name circle_name japanese_name).each do |n|
					name = artist.send(n)

					if ActiveRecord::Base.connection.select_value(ActiveRecord::Base.sanitize_sql(["SELECT 1 FROM artists WHERE name = ?", name])) == nil
						if !name.blank? && name != reference_name
							execute ActiveRecord::Base.sanitize_sql(["INSERT INTO artists (name, alias_id) VALUES (?, (SELECT id FROM artists WHERE name = ?))", name, reference_name])
						end
					end
				end
			end
		end
	end

	def self.down
		raise ActiveRecord::IrreversibleMigration.new
	end
end
