module Danbooru
  def self.pixiv_rewrite(source)
    # Don't download the small version
    if source =~ %r!(/img/.+?/.+?)_[ms].+$!
      match = $1
      source = source.sub(match + "_m", match).sub(match + "_s", match)
    end
    
    if source =~ %r!(\d+_p\d+)\.!
      match = $1
      repl = match.sub(/_p/, "_big_p")
      big_source = source.sub(match, repl)
      if pixiv_http_exists?(big_source)
        source = big_source
      end
    end
    
    url = URI.parse(source)

    return [source, url]
  end
  
  def self.pixiv_http_exists?(source)
    # example: http://img01.pixiv.net/img/as-special/15649262_big_p2.jpg
    exists = false
    uri = URI.parse(source)
    Net::HTTP.start(uri.host, uri.port) do |http|
      headers = {"Referer" => "http://www.pixiv.net", "User-Agent" => "#{CONFIG["app_name"]}/#{CONFIG["version"]}"}
      http.request_head(uri.request_uri, headers) do |res|
        if res.is_a?(Net::HTTPSuccess)
          exists = true
        end
      end
    end
    exists
  end
  
  # Download the given URL, following redirects; once we have the result, yield the request.
  def self.http_get_streaming(source, options = {}, &block)
    max_size = options[:max_size] || CONFIG["max_image_size"]
    max_size = nil if max_size == 0 # unlimited

    limit = 4

    while true
      url = URI.parse(source)

      unless url.is_a?(URI::HTTP)
        raise SocketError, "URL must be HTTP"
      end

      Net::HTTP.start(url.host, url.port) do |http|
        http.read_timeout = 10
    
        headers = {
          "User-Agent" => "#{CONFIG["app_name"]}/#{CONFIG["version"]}"
        }
        
        if source =~ /pixiv\.net/
          headers["Referer"] = "http://www.pixiv.net"
          source, url = pixiv_rewrite(source)
        end
        
        http.request_get(url.request_uri, headers) do |res|
          case res
          when Net::HTTPSuccess then
            if max_size
              len = res["Content-Length"]
              raise SocketError, "File is too large (#{len} bytes)" if len && len.to_i > max_size
            end

            return yield(res)

          when Net::HTTPRedirection then
            if limit == 0 then
              raise SocketError, "Too many redirects"
            end
            source = res["location"]
            limit -= 1
        
          else
            raise SocketError, "HTTP error code: #{res.code} #{res.message}"
          end
        end
      end
    end
  end
end

