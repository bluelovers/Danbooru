class PixivProxy < ActiveRecord::Base
  def self.is_pixiv?(url)
    url =~ /pixiv\.net/
  end
  
	def self.get(url)
	  if url =~ /\/(\d+)(_m)?\.(jpg|jpeg|png|gif)/i
	    url = "http://www.pixiv.net/member_illust.php?mode=medium&illust_id=#{$1}"
	    get_single(url)
		elsif url =~ /member_illust\.php/ && url =~ /illust_id=/
			get_single(url)
    # elsif url =~ /member_illust\.php/ && url =~ /id=/
      # get_listing(url)
    # elsif url =~ /member\.php/ && url =~ /id=/
      # get_profile(url)
		else
      {}
		end
	end
	
	def self.get_profile(url)
		url = URI.parse(url).request_uri
		mech = create_mechanize
		hash = {}
		mech.get(url) do |page|
			hash[:artist] = page.search("a.avatar_m").attr("title").value
			hash[:listing_url] = "/member_illust.php?id=" + url[/id=(\d+)/, 1]
		end
		hash
	end
	
	def self.get_single(url)
		url = URI.parse(url).request_uri
		mech = create_mechanize
		hash = {}
		mech.get(url) do |page|
		  if page.search("a.avatar_m")
  			hash[:artist] = page.search("a.avatar_m").attr("title").value
  			hash[:image_url] = page.search("div.works_display/a/img").attr("src").value.sub("_m.", ".")
  			hash[:profile_url] = page.search("a.avatar_m").attr("href").value
  			hash[:jp_tags] = page.search("span#tags/a").map do |node|
  				[node.inner_text, node.attribute("href").to_s]
  			end.reject {|x| x[0].empty?}
			else
			  hash[:artist] = "?"
  			hash[:image_url] = "?"
  			hash[:profile_url] = "?"
  			hash[:jp_tags] = []
			end
		end
	  hash
	end
	
	def self.create_mechanize
		mech = Mechanize.new
		
		mech.get("http://www.pixiv.net") do |page|
			page.form_with(:action => "/index.php") do |form|
				form.pixiv_id = "uroobnad"
				form.pass = "uroobnad556"
			end.click_button
		end
		
		mech
	end
end
