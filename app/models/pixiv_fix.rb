class PixivFix
  attr_accessor :post
  
  def initialize(post)
    @post = post
  end
  
  def fix!
    return unless source_is_downloadable?(post)
    
    puts "Testing #{post.source}"
    
    unless post_md5_matches_pixiv_md5?(post)
      puts "- MISMATCH"
      download_file(post)
      strip_pixiv_tags(post)
      # post.save!
    end
  end
  
  def source_is_downloadable?(post)
    return false if post.source !~ /^http:\/\//
    return false if post.source !~ /pixiv\.net/
    url = URI.parse(post.source)
    code = nil

    Net::HTTP.start(url.host, url.port) do |http|
      response = http.head(url.request_uri, http_headers)
      if response.code =~ /^2/
        code = true
      else
        code = false
      end
    end
    
    code
  end
  
  def post_md5_matches_pixiv_md5?(post)
    hashes = []
    
    url = URI.parse(post.source)
    Net::HTTP.start(url.host, url.port) do |http|
      puts "- Hashing"
      response = http.get(url.request_uri, http_headers)
      if response.code =~ /^2/
        hashes << Digest::MD5.hexdigest(response.body)
      elsif source_is_manga_page?(post)
        p = 0

        while true
          source = post.source.sub(/_p\d+\.(jpg|png|gif)$/) {"_p#{p}.#{$1}"}
          page_url = URI.parse(source)
          puts "- Hashing p#{p}"
          response = http.get(page_url.request_uri, http_headers)
          if response.code =~ /^2/
            hashes << Digest::MD5.hexdigest(response.body)
          else
            break
          end
          p += 1
        end
      end
    end

    if hashes.include?(post.md5)
      puts "-- #{post.md5} found in #{hashes.inspect}"
      true
    else
      puts "-- #{post.md5} not found in #{hashes.inspect}"
      false
    end
  end
  
  def source_is_manga_page?(post)
    post.source =~ /\d+_p\d+\.(?:jpg|png|gif)$/
  end
  
  def download_file(post)
    puts "- Downloading"
    puts "-- download_source: #{post.download_source}"
    raise "download failed" if post.errors.any?
    
    puts "-- ensure_tempfile_exists: #{post.ensure_tempfile_exists}"
    puts "-- determine_content_type: #{post.determine_content_type}"
    puts "-- validate_content_type: #{post.validate_content_type}"
    raise "invalid_content_type" if post.errors.any?
    
    puts "-- generate_hash: #{post.generate_hash}"
    raise "duplicate_hash" if post.errors.any?
    
    puts "-- set_image_dimensions: #{post.set_image_dimensions}"
    puts "-- generate_sample: #{post.generate_sample}"
    puts "-- generate_preview: #{post.generate_preview}"
    puts "-- move_file: #{post.move_file}"
    puts "-- distribute_file: #{post.distribute_file}"
  end
  
  def strip_pixiv_tags(post)
    post.tags = post.cached_tags.gsub(/\bpixiv_thumbnail\b|\bmd5_mismatch\b/, "")
  end
  
  def http_headers
    @headers ||= {
      "User-Agent" => "#{CONFIG["app_name"]}/#{CONFIG["version"]}",
      "Referer" => "http://www.pixiv.net"
    }
  end
end
