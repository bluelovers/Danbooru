class Pool < ActiveRecord::Base  
  belongs_to :user
  attr_protected :user_id, :post_count
  has_and_belongs_to_many :posts
  
  class PostAlreadyExistsError < Exception
  end
  
  class AccessDeniedError < Exception
  end
  
  module UpdateMethods
    def self.included(m)
      m.has_many :updates, :class_name => "PoolUpdate", :order => "pool_updates.id DESC"
      m.__send__ :attr_accessor, :updater_user_id, :updater_ip_addr
      m.after_save :create_update
      
      def create_update
        PoolUpdate.create(:pool_id => id, :user_id => updater_user_id, :ip_addr => updater_ip_addr, :post_ids => pool_posts(true).map {|x| [x.post_id, x.sequence]}.flatten.join(" "))
      end
      
      def revert_to(update_id, user_id, ip_addr)
        self.updater_user_id = user_id
        self.updater_ip_addr = ip_addr
        
        update = PoolUpdate.find(update_id)
        Pool.transaction do
          pool_posts.clear
          update.post_ids.split(" ").in_groups_of(2).each do |post_id, sequence|
            PoolPost.create(:pool_id => id, :post_id => post_id, :sequence => sequence)
          end
          update_attribute :post_count, PoolPost.count(:conditions => ["pool_id = ?", id])
          update_pool_links
        end
      end
    end
  end
  
  module PostMethods
    def self.included(m)
      m.has_many :pool_posts, :order => "sequence", :dependent => :delete_all
    end
    
    def can_be_updated_by?(user)
      is_public? || user.has_permission?(self)
    end
    
    def add_post(post_id, options = {})
      transaction do
        if PoolPost.exists?(["pool_id = ? AND post_id = ?", id, post_id])
          raise PostAlreadyExistsError
        end
        
        if options[:user] && !can_be_updated_by?(options[:user])
          raise AccessDeniedError
        end
        
        seq = options[:sequence] || next_sequence
        PoolPost.create(:pool_id => id, :post_id => post_id, :sequence => seq.to_i)
        update_attribute :post_count, PoolPost.count(:conditions => ["pool_id = ?", id])

        unless options[:skip_update_pool_links]
          update_pool_links
        end
      end
    end

    def remove_post(post_id, options = {})
      transaction do
        if options[:user] && !can_be_updated_by?(options[:user])
          raise AccessDeniedError
        end
        
        if PoolPost.exists?(["pool_id = ? and post_id = ?", id, post_id])
          PoolPost.destroy_all(["pool_id = ? and post_id = ?", id, post_id])
          update_attribute :post_count, PoolPost.count(:conditions => ["pool_id = ?", id])
          update_pool_links
        end
      end
    end
    
    def update_pool_links
      transaction do
        pp = pool_posts(true) # force reload
        pp.each_index do |i|
          pp[i].next_post_id = nil
          pp[i].prev_post_id = nil
          pp[i].next_post_id = pp[i + 1].post_id unless i == pp.size - 1
          pp[i].prev_post_id = pp[i - 1].post_id unless i == 0
          pp[i].save
        end
      end
    end

    def next_sequence
      seq = select_value_sql("SELECT MAX(sequence) FROM pools_posts where pool_id = ?", id)
      
      if seq.nil?
        return 0
      else
        return seq.to_i + 1
      end
    end
  end
  
  module ApiMethods
    def api_attributes
      return {
        :id => id,
        :name => name,
        :created_at => created_at,
        :updated_at => updated_at,
        :user_id => user_id,
        :is_public => is_public,
        :post_count => post_count,
      }
    end
    
    def to_json(*params)
      api_attributes.to_json(*params)
    end

    def to_xml(options = {})
      options[:indent] ||= 2
      xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
      xml.pool(api_attributes) do
        xml.description(description)
        yield options[:builder] if block_given?
      end
    end
  end
  
  module NameMethods
    module ClassMethods
      def find_by_name(name)
        if name =~ /^\d+$/
          find_by_id(name)
        else
          find(:first, :conditions => ["lower(name) = lower(?)", name])
        end
      end
    end
    
    def self.included(m)
      m.extend(ClassMethods)
      m.validates_uniqueness_of :name
      m.before_validation :normalize_name
    end
    
    def normalize_name
      self.name = name.gsub(/\s/, "_")
    end

    def pretty_name
      name.tr("_", " ")
    end
  end
  
  include PostMethods
  include ApiMethods
  include NameMethods
  include UpdateMethods
end

class PoolPost < ActiveRecord::Base
  set_table_name "pools_posts"
  belongs_to :post
  belongs_to :pool
end
