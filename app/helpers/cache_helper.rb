module CacheHelper
  def build_cache_key(base, tags, page)
    page = page.to_i
    page = 1 if page < 1

    tags = tags.to_s.downcase.scan(/\S+/).sort
    version_fragment = "v=?"
    tag_fragment = "t=?"
    page_fragment = "p=#{page}"
    global_version = Cache.get("$cache_version").to_i
    expiry = 0
    
    if tags.empty?
      version_fragment = "v=#{global_version}"
    end
    
    if (CONFIG["enable_aggressive_caching"] && page > 10) || tags.any? {|x| x =~ /[*:]/}
      version_fragment = "v=#{global_version}"
      tag_fragment = "t=" + tags.join(",")
      expiry = (rand(4) * 3) * 1.day
    else
      tag_fragment = "t=" + tags.map {|x| x + ":" + Cache.get("tag:#{x}").to_i.to_s}.join(",")
    end
    
    ["#{base}/#{version_fragment}&#{tag_fragment}&#{page_fragment}", expiry]
  end

  def get_cache_key(controller_name, action_name, params)
    case "#{controller_name}/#{action_name}"
    when "post/index"
      build_cache_key("p/i", params[:tags], params[:page])
      
    when "post/atom"
      build_cache_key("p/a", params[:tags], 1)

    when "post/piclens"
      build_cache_key("p/p", params[:tags], params[:page])
      
    else
      nil
    end
  end
end
