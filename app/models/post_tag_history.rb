class PostTagHistory < ActiveRecord::Base
  belongs_to :user

  class << self
    def generate_sql(options = {})
      joins = []
      conds = ["TRUE"]
      params = []
      
      if options[:post_id]
        conds << "post_tag_histories.post_id = ?"
        params << options[:post_id]
      end
      
      if options[:user_name]
        joins << "JOIN users ON users.id = post_tag_histories.user_id"
        conds << "users.name = ?"
        params << options[:user_name]
      end
      
      if options[:user_id]
        conds << "post_tag_histories.user_id = ?"
        params << options[:user_id]
      end
      
      joins = joins.join(" ")
      conds = [conds.join(" AND "), *params]
      
      return joins, conds
    end
  end

  def author
    return User.find_name(self.user_id)
  end

  def tag_changes(prev)
    new_tags = tags.scan(/\S+/)
    old_tags = (prev.tags rescue "").scan(/\S+/)

    {
      :added_tags => new_tags - old_tags,
      :removed_tags => old_tags - new_tags,
      :unchanged_tags => new_tags & old_tags,
    }
  end

  def previous
    return PostTagHistory.find(:first, :order => "id DESC", :conditions => ["post_id = ? AND id < ?", post_id, id])
  end

  def to_xml(options = {})
    {:id => id, :post_id => post_id, :tags => tags}.to_xml(options.merge(:root => "tag_history"))
  end

  def to_json(options = {})
    {:id => id, :post_id => post_id, :tags => tags}.to_json(options)
  end
end
