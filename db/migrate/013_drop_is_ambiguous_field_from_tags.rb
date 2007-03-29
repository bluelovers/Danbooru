class DropIsAmbiguousFieldFromTags < ActiveRecord::Migration
	def self.up
		execute "ALTER TABLE tags DROP COLUMN is_ambiguous"
	end

	def self.down
		execute "ALTER TABLE tags ADD COLUMN is_ambiguous BOOLEAN NOT NULL DEFAULT FALSE"
	end
end
