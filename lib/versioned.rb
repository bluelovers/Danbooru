module ActiveRecord
  module Acts #:nodoc:
    module Versioned #:nodoc:
      def self.append_features(base) # :nodoc:
        super
        base.extend ClassMethods
      end

      # Specify this act if you want to save a copy of the row in a versioned table.  This assumes there is a
      # versioned table ready and that your model has a version field.  This works with optimisic locking if the lock_version
      # column is present as well.
      #
      #   class Page < ActiveRecord::Base
      #     # assumes pages_versions table
      #     acts_as_versioned
      #   end
      #
      #   Example:
      #
      #   page = Page.create(:title => 'hello world!')
      #   page.version       # => 1
      #
      #   page.title = 'hello world'
      #   page.version       # => 2
      #   page.versions.size # => 2
      #
      #   page.revert_to(1)  # using version number
      #   page.title         # => 'hello world!'
      #
      #   page.revert_to(page.versions.last) # using versioned instance
      #   page.title         # => 'hello world'
      module ClassMethods
        # Configuration options are:
        #
        # * <tt>class_name</tt> - versioned model class name (default: PageVersion in the above example)
        # * <tt>table_name</tt> - versioned model table name (default: pages_versions in the above example)
        # * <tt>foreign_key</tt> - foreign key used to relate the versioned model to the original model (default: page_id in the above example)
        # * <tt>type_field</tt> - name of the column to save the model's type value for STI.  (default: versioned_type)
        # * <tt>version_field</tt> - name of the column in the model that keeps the version number (default: version)
        def acts_as_versioned(options = {})
          class_eval <<-EOV
            class << self
              def versioned_class_name
                "#{options[:class_name] || "#{self.to_s}Version"}"
              end

              def versioned_table_name
                "#{options[:table_name] || "#{self.to_s.downcase.pluralize}_versions"}"
              end

              def versioned_foreign_key
                "#{options[:foreign_key] || "#{self.to_s.downcase}_id"}"
              end

              def versioned_type_field
                "#{options[:type_field] || "versioned_type"}"
              end

              def version_field
                "#{options[:version_field] || 'version'}"
              end
            end
          EOV

          class_eval do
            include ActiveRecord::Acts::Versioned::ActMethods

            has_many :versions,
              :class_name => "ActiveRecord::Acts::Versioned::#{versioned_class_name}",
              :foreign_key => "#{versioned_foreign_key}"
            after_save :save_version
          end

          eval <<-EOV
            class ActiveRecord::Acts::Versioned::#{versioned_class_name} < ActiveRecord::Base
              set_table_name "#{versioned_table_name}"
              belongs_to :#{self.to_s.downcase}
            end
          EOV
        end
      end

      module ActMethods
        def self.append_features(base) # :nodoc:
          super
          base.extend ClassMethods
        end

        # Saves a version of the model in the versioned table.  This is called in the after_save callback by default
        def save_version
          new_version = self.next_version

          rev = self.class.versioned_class.new
          self.clone_versioned_model(self, rev)
          rev.version = new_version
          rev.send("#{self.class.versioned_foreign_key}=", self.id)
          rev.save

          self.send("#{self.class.version_field}=", new_version)
          self.update_without_locking_or_callbacks
        end

        # Reverts a model to a given version.  Takes either a version number or an instance of the versioned model
        def revert_to(version)
          if version.is_a?(self.class.versioned_class)
            return false unless version.send(self.class.versioned_foreign_key) == self.id and !version.new_record?
          else
            return unless version = self.class.versioned_class.find(:first,
              :conditions => ["id = ? and #{self.class.versioned_foreign_key} = ?", version.to_s, self.id])
          end
          self.clone_versioned_model(version, self)
          self.send("#{self.class.version_field}=", version.version)
          self.update_without_locking_or_callbacks
        end

        def update_without_locking_or_callbacks
          old_lock_value = ActiveRecord::Base.lock_optimistically
          ActiveRecord::Base.lock_optimistically = false if old_lock_value
          self.update_without_callbacks
          ActiveRecord::Base.lock_optimistically = true if old_lock_value
        end

        # Returns an array of attribute keys that are versioned.  See non_versioned_fields
        def versioned_attributes
          self.attributes.keys.select { |k| !self.class.non_versioned_fields.include?(k) }
        end

        # Clones a model.  Used when saving a new version or reverting a model's version.
        def clone_versioned_model(orig_model, new_model)
          self.versioned_attributes.each do |key|
            new_model.send("#{key}=", orig_model.attributes[key]) if orig_model.attribute_present?(key)
          end

          if orig_model.is_a?(self.class.versioned_class)
            new_model[:type] = orig_model[self.class.versioned_type_field]
          elsif new_model.is_a?(self.class.versioned_class)
            new_model[self.class.versioned_type_field] = orig_model[:type]
          end
        end

        def next_version
          connection.select_one("SELECT MAX(version)+1 AS next_version FROM #{self.class.versioned_table_name} WHERE #{self.class.versioned_foreign_key} = #{self.id}")['next_version'] || 1
        end

        module ClassMethods
          # Returns an array of columns that are versioned.  See non_versioned_fields
          def versioned_columns
            self.columns.select { |c| !non_versioned_fields.include?(c.name) }
          end

          # Returns an instance of the dynamic versioned model
          def versioned_class
            ActiveRecord::Acts::Versioned.const_get(versioned_class_name)
          end

          # An array of fields that are not saved in the versioned table
          def non_versioned_fields
            [self.primary_key, 'type', 'version', 'lock_version', versioned_type_field]
          end

          # Rake migration to create the versioned table using options passed to acts_as_versioned
          def create_versioned_table
            self.transaction do
              self.connection.create_table versioned_table_name do |t|
                t.column versioned_foreign_key, :integer
                t.column :version, :integer
              end

              updated_col = nil
              self.versioned_columns.each do |col|
                updated_col = col if %(updated_at updated_on).include?(col.name) and !updated_col
                self.connection.add_column versioned_table_name, col.name, col.type,
                  :limit => col.limit,
                  :default => col.default
              end

              if type_col = self.columns_hash['type']
                self.connection.add_column versioned_table_name, versioned_type_field, type_col.type,
                  :limit => type_col.limit,
                  :default => type_col.default
              end

              if updated_col.nil?
                self.connection.add_column versioned_table_name, :updated_at, :timestamp
              end
            end
          end
        end
      end
    end
  end
end