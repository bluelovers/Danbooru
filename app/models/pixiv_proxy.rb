class PixivProxy < ActiveRecord::Base
	def self.get(url)
		if url =~ /member_illust\.php/ && url =~ /illust_id=/
			get_single(url)
		elsif url =~ /member_illust\.php/ && url =~ /id=/
			get_listing(url)
		elsif url =~ /member\.php/ && url =~ /id=/
			get_profile(url)
		else
			"unknown"
		end
	end
	
	def self.get_profile(url)
		url = URI.parse(url).request_uri
		mech = create_mechanize
		hash = {}
		mech.get(url) do |page|
			hash[:artist] = page.search("div#profile/div/a/img").attr("alt")
			hash[:listing_url] = "/member_illust.php?id=" + url[/id=(\d+)/, 1]
		end
		["profile", hash]
	end
	
	def self.get_single(url)
		url = URI.parse(url).request_uri
		mech = create_mechanize
		hash = {}
		mech.get(url) do |page|
			hash[:artist] = page.search("div#profile/div/a/img").attr("alt")
			hash[:profile_url] = page.search("div#profile/div/a").attr("href")
			hash[:image_url] = page.search("img[border='0']").attr("src").sub("_m.", ".")
			hash[:jp_tags] = page.search("div#tag_area/span#tags/a").map do |node|
				[node.inner_text, node.attribute("href").to_s]
			end
		end
		["single", hash]
	end
	
	def self.get_listing(url)
		mech = create_mechanize
		p = 1
		url = URI.parse(url).request_uri.sub(/&p=\d+/, "") + "&p=1"
		more = true
		images = []
		
		while more
			mech.get(url) do |page|
				links = page.search("div#illust_c4/ul/li/a")
				
				if links.empty?
					more = false
				else
					images += links.map do |node|
						image_src = node.child.attribute("src").to_s
						[image_src, image_src.sub("_s.", "."), node.attribute("href").to_s]
					end
				end
				
				p += 1
				url.sub!(/&p=\d+/, "&p=#{p}")
			end
		end
		
		["listing", images]
	end

	def self.create_mechanize
		mech = WWW::Mechanize.new
		
		mech.get("http://www.pixiv.net") do |page|
			page.form_with(:action => "index.php") do |form|
				form.pixiv_id = "uroobnad"
				form.pass = "uroobnad556"
			end.click_button
		end
		
		mech
	end
end
