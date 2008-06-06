module CacheHelper
  def build_cache_key(base, tags, page, options = {})
    page = page.to_i
    page = 1 if page < 1

    tags = tags.to_s.downcase.scan(/\S+/).sort
    version_fragment = "v=?"
    tag_fragment = "t=?"
    page_fragment = "p=#{page}"
    user_level_fragment = "l=?"
    global_version = Cache.get("$cache_version").to_i
    user = options[:user]
    
    if user
      user_level = user.level
      user_level = CONFIG["user_levels"]["Member"] if user_level < CONFIG["user_levels"]["Member"]
      user_level_fragment = "l=#{user_level}"
    end
    
    if tags.empty? || tags.any? {|x| x =~ /[*:]/}
      version_fragment = "v=#{global_version}"
      tag_fragment = "t=" + tags.join(",") if tags.any?
    else
      tag_fragment = "t=" + tags.map {|x| x + ":" + Cache.get("tag:#{x}").to_i.to_s}.join(",")
    end
    
    ["#{base}/#{version_fragment}&#{tag_fragment}&#{page_fragment}&#{user_level_fragment}", 0]
  end

  def get_cache_key(controller_name, action_name, params, options = {})
    case "#{controller_name}/#{action_name}"
    when "post/index"
      build_cache_key("p/i", params[:tags], params[:page], options)
      
    when "post/atom"
      build_cache_key("p/a", params[:tags], 1, options)

    when "post/piclens"
      build_cache_key("p/p", params[:tags], params[:page], options)
      
    else
      nil
    end
  end
end
