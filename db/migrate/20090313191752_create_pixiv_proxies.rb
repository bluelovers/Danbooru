class CreatePixivProxies < ActiveRecord::Migration
  def self.up
    create_table :pixiv_proxies do |t|

      t.timestamps
    end
  end

  def self.down
    drop_table :pixiv_proxies
  end
end
