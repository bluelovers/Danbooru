class Pool < ActiveRecord::Base
  class PostAlreadyExistsError < Exception; end
  
  belongs_to :user
  validates_uniqueness_of :name
  before_save :normalize_name
  has_many :pool_posts, :class_name => "PoolPost", :order => "sequence"
  
  def self.find_by_name(name)
    if name =~ /^\d+$/
      find_by_id(name)
    else
      find(:first, :conditions => ["lower(name) = lower(?)", name])
    end
  end
  
  def normalize_name
    self.name = self.name.gsub(/\s/, "_")
  end
  
  def pretty_name
    self.name.gsub(/_/, " ")
  end
  
  def add_post(post_id, options = {})
    transaction do
      if PoolPost.find(:first, :conditions => ["pool_id = ? and post_id = ?", self.id, post_id])
        raise PostAlreadyExistsError
      end
      seq = options.fetch(:sequence, next_id)
      Cache.expire(:post_id => post_id)
      update_attributes(:updated_at => Time.now)
      PoolPost.create(:pool_id => self.id, :post_id => post_id, :sequence => seq.to_i)
      self.increment(:post_count)
      self.save!

      if !options.fetch(:skip_update_pool_links, false)
        self.update_pool_links
      end
    end
  end
  
  def remove_post(post_id)
    transaction do
      return unless PoolPost.find(:first, :conditions => ["pool_id = ? and post_id = ?", self.id, post_id])

      Cache.expire(:post_id => post_id)
      update_attributes(:updated_at => Time.now)
      PoolPost.destroy_all(["pool_id = ? and post_id = ?", self.id, post_id])
      self.decrement(:post_count)
      self.save!

      self.update_pool_links
    end
  end

  def update_pool_links
    transaction do
      pp = self.pool_posts
      pp.each_index do |i|
        pp[i].next_post_id = nil
        pp[i].prev_post_id = nil
        pp[i].next_post_id = pp[i + 1].post_id unless i == pp.size - 1
        pp[i].prev_post_id = pp[i - 1].post_id unless i == 0
        pp[i].save
      end
    end
  end

  def next_id()
    i = connection.select_value("SELECT MAX(sequence) FROM pools_posts where pool_id=#{self.id}")
    if i.nil?
      return 0
    else
      return i.to_i + 1
    end
  end

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

  def to_xml(options = {})
    options[:indent] ||= 2
    xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
    xml.pool(api_attributes) do
      xml.description(description)
      yield options[:builder]
    end
  end
end

class PoolPost < ActiveRecord::Base
  set_table_name "pools_posts"
  belongs_to :post
  belongs_to :pool
end
