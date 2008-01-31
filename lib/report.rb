module Report
  def usage_by_user(table_name, start, stop)
    conds = ["created_at BETWEEN ? AND ?"]
    params = [start, stop]

    users = ActiveRecord::Base.connection.select_all(ActiveRecord::Base.sanitize_sql(["SELECT user_id, COUNT(*) as change_count FROM #{table_name} WHERE " + conds.join(" AND ") + " GROUP BY user_id ORDER BY change_count DESC LIMIT 9", *params]))

    conds << "user_id NOT IN (?)"
    params << users.map {|x| x["user_id"]}

    other_count = ActiveRecord::Base.connection.select_value(ActiveRecord::Base.sanitize_sql(["SELECT COUNT(*) FROM #{table_name} WHERE " + conds.join(" AND "), *params]))
    
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
  
  module_function :usage_by_user
end
