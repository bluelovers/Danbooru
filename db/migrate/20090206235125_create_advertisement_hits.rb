class CreateAdvertisementHits < ActiveRecord::Migration
  def self.up
    create_table :advertisement_hits do |t|
      t.column :advertisement_id, :integer
      t.timestamps
    end

    add_index :advertisement_hits, :advertisement_id
    add_index :advertisement_hits, :created_at
    execute "ALTER TABLE advertisement_hits ADD COLUMN ip_addr INET"
  end

  def self.down
    drop_table :advertisement_hits
  end
end
