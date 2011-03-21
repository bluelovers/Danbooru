module AdminHelper
  def admin_link_to_user(user, positive_or_negative)
    html = ""
    html << link_to(user.name, :controller => "user", :action => "show", :id => user.id)
    if positive_or_negative == :positive
      html << " [" + link_to("+", {:controller => "user_record", :action => :create, :user_id => user.id, :user_record => {:score => 1}}, :target => "_blank") + "]"
      unless user.is_privileged_or_higher?
        html << " [" + link_to("invite", {:controller => "user", :action => "invites", :user => {:name => user.name, :level => CONFIG["user_levels"]["Contributor"]}}, :target => "_blank") + "]"
      end
    else
      html << " [" + link_to("&ndash;", {:controller => "user_record", :action => :create, :user_id => user.id, :user_record => {:score => -1}}, :target => "_blank") + "]"
    end
    html
    
  rescue
    ""
  end
end
