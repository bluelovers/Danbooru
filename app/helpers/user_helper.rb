module UserHelper
  def user_level_select_tag(name, options = {})
    choices = CONFIG["user_levels"].to_a.sort_by {|x| x[1]}
    choices.unshift ["", ""]
    select_tag(name, options_for_select(choices), options)
  end
  
  def upload_limit_formula(user)
    base = user.base_upload_limit
    approved = Post.count(:conditions => ["user_id = ? and status = ?", user.id, "active"])
    deleted = Post.count(:conditions => ["user_id = ? and status = ?", user.id, "deleted"])
    pending = Post.count(:conditions => ["user_id = ? and status = ?", user.id, "pending"])
    total = base + (approved / 10) - (deleted / 4) - pending
    "#{base} + (#{approved} / 10) - (#{deleted} / 4) - #{pending} = #{total}"
  end
end
