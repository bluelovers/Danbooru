class PostTagHistory < ActiveRecord::Base
  @disable_versioning = false
  belongs_to :user

  class << self
    attr_accessor :disable_versioning
    
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

  def to_xml(options = {})
    {:id => id, :post_id => post_id, :tags => tags}.to_xml(options.merge(:root => "tag_history"))
  end

  def to_json(options = {})
    {:id => id, :post_id => post_id, :tags => tags}.to_json(options)
  end
end
