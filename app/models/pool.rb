class Pool < ActiveRecord::Base
  class PostAlreadyExistsError < Exception; end
  
  belongs_to :user
  validates_uniqueness_of :name
  before_save :normalize_name
  
  def normalize_name
    self.name = self.name.gsub(/\s/, "_")
  end
  
  def pretty_name
    self.name.gsub(/_/, " ")  
  end
  
  def add_post(post_id)
    if PoolPost.find(:first, :conditions => ["pool_id = ? and post_id = ?", self.id, post_id])
      raise PostAlreadyExistsError
    end

    transaction do
      update_attributes(:updated_at => Time.now)
      PoolPost.create(:pool_id => self.id, :post_id => post_id)
    end
  end
  
  def remove_post(post_id)
    PoolPost.destroy_all(["pool_id = ? and post_id = ?", self.id, post_id])
  end
end

class PoolPost < ActiveRecord::Base
  set_table_name "pools_posts"
  belongs_to :post
  belongs_to :pool
end
