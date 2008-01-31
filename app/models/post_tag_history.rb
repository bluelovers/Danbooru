class PostTagHistory < ActiveRecord::Base
  @disable_versioning = false

  class << self
    attr_accessor :disable_versioning
    
    def report_usage(start, stop, options = {})
      conds = ["created_at BETWEEN ? AND ?"]
      params = [start, stop]

      users = connection.select_all(sanitize_sql(["SELECT user_id, COUNT(*) as change_count FROM post_tag_histories WHERE " + conds.join(" AND ") + " GROUP BY user_id ORDER BY change_count DESC LIMIT 9", *params]))

      conds << "user_id NOT IN (?)"
      params << users.map {|x| x["user_id"]}

      other_count = connection.select_value(sanitize_sql(["SELECT COUNT(*) FROM post_tag_histories WHERE " + conds.join(" AND "), *params]))
      
      users << {"user_id" => nil, "change_count" => other_count}
      
      users.each do |user|
        if user["user_id"]
          user["name"] = User.find(:first, :conditions => ["id = ?", user["user_id"]], :select => "name").name
        else
          user["name"] = "Other"
        end
      end
      
      return users
    end
  end

  def author
    if user_id
      connection.select_value("SELECT name FROM users WHERE id = #{self.user_id}")
    else
      CONFIG["default_guest_name"]
    end
  end

  def to_xml(options = {})
    {:id => id, :post_id => post_id, :tags => tags}.to_xml(options.merge(:root => "tag_history"))
  end

  def to_json(options = {})
    {:id => id, :post_id => post_id, :tags => tags}.to_json(options)
  end
end
