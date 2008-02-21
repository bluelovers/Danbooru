module RedHillConsulting::ForeignKeyMigrations::ActiveRecord::ConnectionAdapters
  module AbstractAdapter
    def self.included(base)
      base.class_eval do
        alias_method_chain :initialize, :foreign_key_migrations
      end
    end

    def initialize_with_foreign_key_migrations(*args)
      initialize_without_foreign_key_migrations(*args)
      self.class.class_eval do
        alias_method_chain :add_column, :foreign_key_migrations
      end
    end

    def add_column_with_foreign_key_migrations(table_name, column_name, type, options = {})
      add_column_without_foreign_key_migrations(table_name, column_name, type, options)
      references = ActiveRecord::Base.references(table_name, column_name, options)
      add_foreign_key(table_name, column_name, references.first, references.last, options) if references
    end
  end
end
