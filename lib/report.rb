module Report
  def tag_history(name, start_date, end_date)
    if name
      start_date = start_date.strftime("%Y-%m-%d")
      end_date = end_date.strftime("%Y-%m-%d")
      results = ActiveRecord::Base.select_all_sql("SELECT extract(year from posts.created_at) as year, extract(week from posts.created_at) AS week, COUNT(*) AS post_count FROM posts WHERE posts.tags_index @@ to_tsquery('danbooru', E'" + Post.generate_sql_escape_helper([name]).first + "') AND posts.created_at >= '#{start_date}' AND posts.created_at <= '#{end_date}' GROUP BY year, week ORDER BY year, week").map {|x| [x["year"], x["week"], x["post_count"]]}
      
      results.map {|x| [x[0].to_i * 100 + x[1].to_i, x[2].to_i]}
    else
      []
    end
  end

  def usage_by_user(table_name, start, stop, limit, level)
    conds = ["#{table_name}.created_at BETWEEN ? AND ?"]
    params = [start, stop]
    
    if level && level != 0
      conds << "users.level = ?"
      params << level
    end

    users = ActiveRecord::Base.select_all_sql("SELECT users.id, COUNT(*) as change_count FROM #{table_name} JOIN users ON users.id = #{table_name}.user_id WHERE " + conds.join(" AND ") + " GROUP BY users.id ORDER BY change_count DESC LIMIT #{limit}", *params)

    conds << "users.id NOT IN (?)"
    params << users.map {|x| x["id"]}

    other_count = ActiveRecord::Base.connection.select_value(ActiveRecord::Base.sanitize_sql_array(["SELECT COUNT(*) FROM #{table_name} JOIN users ON users.id = #{table_name}.user_id WHERE " + conds.join(" AND "), *params]))
    
    users << {"id" => nil, "change_count" => other_count}
    
    users.each do |user|
      if user["id"]
        user["name"] = User.find_name(user["id"])
      else
        user["name"] = "Other"
      end
      user["change_count"] = user["change_count"].to_i
    end
    
    return add_sum(users)
  end
  
  def tag_updates(start, stop, limit, level)
    users = usage_by_user("post_tag_histories", start, stop, limit, level)
    users.each do |user|
      user["change_count"] = user["change_count"] - Post.count(:all, :conditions => ["created_at BETWEEN ? AND ? AND user_id =?", start, stop, user["user_id"]])
    end
    bottom = users.pop
    users.sort! {|a, b| b["change_count"] <=> a["change_count"]}
    users.push(bottom)
    users
  end
  
  def post_uploads(start, stop, limit, level)
    usage_by_user("posts", start, stop, limit, level)
  end
  
  def wiki_updates(start, stop, limit, level)
    usage_by_user("wiki_page_versions", start, stop, limit, level)
  end
  
  def note_updates(start, stop, limit, level)
    usage_by_user("note_versions", start, stop, limit, level)
  end
  
  def add_sum(users)
    sum = 0
    users.each do |user|
      sum += user["change_count"].to_i
    end
    users.each do |user|
      user["sum"] = sum.to_f
    end
  end
  
  module_function :usage_by_user
  module_function :tag_updates
  module_function :post_uploads
  module_function :wiki_updates
  module_function :note_updates
  module_function :add_sum
  module_function :tag_history
end
