class RevertEnableAutoCompleteOnUsers < ActiveRecord::Migration
  def self.up
    remove_column "users", "enable_autocomplete`"
  end

  def self.down
    add_column "users", "enable_autocomplete", :boolean, :null => false, :default => true
  end
end
