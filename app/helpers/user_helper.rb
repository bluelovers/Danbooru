module UserHelper
  def user_level_select_tag(name, options = {})
    choices = CONFIG["user_levels"].to_a.sort_by {|x| x[1]}
    choices.unshift ["", ""]
    select_tag(name, options_for_select(choices, params[name].to_i), options)
  end
  
  def upload_limit_formula(user)
    upload_limit = user.upload_limit
    
    if upload_limit.nil?
      base = 10
      approved = Post.count(:conditions => ["user_id = ? and status = ?", user.id, "active"])
      deleted = Post.count(:conditions => ["user_id = ? and status = ?", user.id, "deleted"])
      pending = Post.count(:conditions => ["user_id = ? and status = ?", user.id, "pending"])
      total = base + (approved / 10) - (deleted / 4) - pending
      "base:#{base} + approved:(#{approved} / 10) - deleted:(#{deleted} / 4) - pending:#{pending} = #{total}"
    else
      base = upload_limit
      pending = Post.count(:conditions => ["user_id = ? and status = ?", user.id, "pending"])
      total = base - pending
      "base:#{base} - pending:#{pending} = #{total}"
    end
  end
end
