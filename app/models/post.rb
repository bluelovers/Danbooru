class Post < ActiveRecord::Base
	before_validation_on_create :auto_download
	before_validation_on_create :generate_hash
	before_validation_on_create :rename_file
	before_validation_on_create :get_image_dimensions
	before_validation_on_create :generate_preview
	before_destroy :delete_file
	after_create :update_neighbor_links_on_create
	before_destroy :update_neighbor_links_on_destroy

	votable
	uses_image_servers :servers => CONFIG["image_servers"] if CONFIG["image_servers"]
	has_and_belongs_to_many :tags, :order => "name"
	has_many :comments, :order => "id", :conditions => "signal_level <> 0"
	has_many :notes, :order => "id desc"
	has_many :tag_history, :class_name => "PostTagHistory", :table_name => "post_tag_histories"
	belongs_to :user

	def self.fast_count(tags = nil)
		if tags.blank?
			return connection.select_value("SELECT row_count FROM table_data WHERE name = 'posts'").to_i
		else
			c = connection.select_value(sanitize_sql(["SELECT post_count FROM tags WHERE name = ?", tags])).to_i
			if c == 0
				return Post.count_by_sql(Post.generate_sql(tags, :count => true))
			else
				return c
			end
		end
	end

	def rating=(r)
		if self.is_rating_locked?
			self.errors.add "rating", "rating is locked"
			return
		end

		r = r.to_s.downcase[0,1]
		if %w(q e s).include?(r)
			write_attribute(:rating, r)
		else
			write_attribute(:rating, 'q')
		end
	end

# Saves the tags to the join table.
	def tag!(tags, user_id = nil, ip_addr = nil)
		tags = "tagme" if tags.blank?
		
		canonical = Tag.scan_tags(tags)
		canonical = Tag.to_aliased(canonical).uniq
		canonical = Tag.with_parents(canonical).uniq

		connection.execute("BEGIN")
		connection.execute("DELETE FROM posts_tags WHERE post_id = #{id}")
		foo = []
		canonical.each do |t|
			if t =~ /^rating:(.+)/
				self.rate!($1)
			else
				hoge = Tag.find_or_create_by_name(t)
				unless foo.include?(hoge.name)
					foo << hoge.name
					connection.execute("INSERT INTO posts_tags (post_id, tag_id) VALUES (#{id}, #{hoge.id})")
				end
			end
		end
		
		foo = foo.sort.uniq.join(" ")

		unless connection.select_value("SELECT tags FROM post_tag_histories WHERE post_id = #{id} ORDER BY id DESC LIMIT 1") == foo
			connection.execute(Post.sanitize_sql(["INSERT INTO post_tag_histories (post_id, tags, user_id, ip_addr) VALUES (#{id}, ?, ?, ?)", foo, user_id, ip_addr]))
		end
		connection.execute(Post.sanitize_sql(["UPDATE posts SET cached_tags = ? WHERE id = #{id}", foo]))
		connection.execute("COMMIT")
	end

	def tempfile_path
		"#{RAILS_ROOT}/public/data/#{$$}.upload"
	end

# Generates a MD5 hash for the file
	def generate_hash
		self.md5 = File.open(tempfile_path, 'rb') {|fp| Digest::MD5.hexdigest(fp.read)}

		if connection.select_value("SELECT 1 FROM posts WHERE md5 = '#{md5}'")
			FileUtils.rm_f(tempfile_path)
			errors.add "md5", "already exists"
			return false
		end
	end

	def rename_file
		FileUtils.mkdir_p(File.dirname(file_path), :mode => 0775)
		FileUtils.mv(tempfile_path, file_path)
		FileUtils.chmod(0775, file_path)
		FileUtils.rm_f(tempfile_path)
	end

	def generate_preview
		return unless image?

		begin
			FileUtils.mkdir_p(File.dirname(preview_path), :mode => 0775)

			unless system("#{RAILS_ROOT}/lib/resizer/resizer #{file_path} #{preview_path}")
				errors.add 'preview', "couldn't be generated"
				return false
			end
		rescue Exception => x
			errors.add 'preview', "couldn't be generated: #{x}"
			return false
		end
	end

# delete_file removes the post and its preview from the file system.
	def delete_file
		FileUtils.rm_f(file_path)
		FileUtils.rm_f(preview_path) if image?
	end

# auto_download automatically downloads from the source url if it's a URL
	def auto_download
		return if !(source =~ /^http/ and file_ext.blank?)

		begin
			img = Net::HTTP.get(URI.parse(source))
			self.file_ext = find_ext(source)
			File.open(tempfile_path, 'wb') do |out|
				out.write(img)
			end
		rescue Exception => x
			FileUtils.rm_f(tempfile_path)
			errors.add "source", "couldn't be opened: #{x}"
			return false
		end
	end

# file= assigns a CGI file to the post. This writes the file to disk and generates a unique file name.
	def file=(f)
		return if f.nil? || f.size == 0

		self.file_ext = find_ext(f.original_filename)

		if f.local_path
			# Large files are stored in the temp directory, so instead of
			# reading/rewriting through Ruby, just rely on system calls to
			# copy the file to danbooru's directory.
			FileUtils.cp(f.local_path, tempfile_path)
		else
			File.open(tempfile_path, 'wb') {|nf| nf.write(f.read)}
		end
	end

	def file_name
		md5 + "." + file_ext
	end

# Returns the absolute path to the post.
	def file_path
		"#{RAILS_ROOT}/public/data/%s/%s/%s" % [md5[0,2], md5[2,2], file_name]
	end

# Returns the URL for the post
	def file_url
		if self.class.method_defined? :file_url_alt
			return file_url_alt()
		end

		"http://" + CONFIG["server_host"] + "/data/%s/%s/%s" % [md5[0,2], md5[2,2], file_name]
	end

# Returns the absolute path to the preview file.
	def preview_path
		if image?
			"#{RAILS_ROOT}/public/data/preview/%s/%s/%s" % [md5[0,2], md5[2,2], md5 + ".jpg"]
		else
			"#{RAILS_ROOT}/public/data/preview/default.png"
		end
	end

# Returns the URL for the preview
	def preview_url
		if self.class.method_defined?(:preview_url_alt)
			return preview_url_alt()
		end

		if image?
			"http://" + CONFIG["server_host"] + "/data/preview/%s/%s/%s" % [md5[0,2], md5[2,2], md5 + ".jpg"]
		else
			"http://" + CONFIG["server_host"] + "/data/preview/default.png"
		end
	end

	def get_image_dimensions
		if image? or flash?
			imgsize = ImageSize.new(File.open(file_path, "rb"))
			self.width = imgsize.get_width
			self.height = imgsize.get_height
		end
	end

# Returns true if the post is an image format that GD can handle.
	def image?
		%w(jpg jpeg gif png).include?(self.file_ext.downcase)
	end

# Returns true if the post is a Flash movie.
	def flash?
		file_ext == "swf"
	end

# Returns the size of the file in bytes (may not be precise)
	def size
		return File.size(file_path)
	end

# Returns either the author's name or the default guest name.
	def author
		if @author
			@author
		elsif user_id
			@author = connection.select_value("SELECT name FROM users WHERE id = #{self.user_id}")
			@author
		else
			CONFIG["default_guest_name"]
		end
	end

	def update_neighbor_links_on_create
		prev_post = Post.find(:first, :conditions => ["id < ?", id], :order => "id DESC")

		if prev_post != nil
			# should only be nil for very first post created
			self.update_attribute(:prev_post_id, prev_post.id)
			prev_post.update_attribute(:next_post_id, id)
		end
	end

	def update_neighbor_links_on_destroy
		prev_post = Post.find(:first, :conditions => ["id < ?", id], :order => "id DESC")
		next_post = Post.find(:first, :conditions => ["id > ?", id], :order => "id ASC")

		if prev_post == nil && next_post == nil
			# do nothing
		elsif prev_post != nil && next_post != nil
			# deleted post is in middle
			prev_post.update_attribute(:next_post_id, next_post.id)
			next_post.update_attribute(:prev_post_id, prev_post.id)
		elsif prev_post == nil
			# no previous post, therefore deleted post is first post
			next_post.update_attribute(:prev_post_id, nil)
		elsif next_post == nil
			# no next post, therefore deleted post is last post
			prev_post.update_attribute(:next_post_id, nil)
		end
	end

	def self.generate_sql__range_helper(arr, field, c, p)
		case arr[0]
		when :eq
			c << "#{field} = ?"
			p << arr[1]

		when :gt
			c << "#{field} >= ?"
			p << arr[1]

		when :lt
			c << "#{field} <= ?"
			p << arr[1]

		when :between
			c << "#{field} BETWEEN ? AND ?"
			p << arr[1]
			p << arr[2]

		else
			# do nothing
		end
	end

	def self.generate_sql(q, options = {})
		unless q.is_a?(Hash)
			q = Tag.parse_query(q)
		end

		conditions = []
		from = ["posts p"]
		params = []

		generate_sql__range_helper(q[:post_id], "p.id", conditions, params)
		generate_sql__range_helper(q[:width], "p.width", conditions, params)
		generate_sql__range_helper(q[:height], "p.height", conditions, params)
		generate_sql__range_helper(q[:score], "p.score", conditions, params)

		if q[:md5].is_a?(String)
			conditions << "p.md5 = ?"
			params << q[:md5]
		end

		if q[:source].is_a?(String)
			conditions << "p.source ILIKE ? ESCAPE '\\\\'"
			params << q[:source]
		end

		if q[:fav].is_a?(String)
			from << "favorites f"
			from << "users u1"
			conditions << "p.id = f.post_id AND f.user_id = u1.id AND lower(u1.name) = lower(?)"
			params << q[:fav]
		end

		if q[:user].is_a?(String)
			from << "users u2"
			conditions << "p.user_id = u2.id AND lower(u2.name) = lower(?)"
			params << q[:user]
		end

		if q[:related].any? || q[:include].any?
			conditions2 = []
			
			if q[:include].any?
				from << "posts_tags pt0"
				from << "tags t0"
				conditions2 << "(p.id = pt0.post_id AND t0.id = pt0.tag_id AND t0.name IN (?))"
				params << (q[:include] + q[:related])
			else
				conditions3 = []

				if q[:related].size == 1
					count = connection.select_value(Post.sanitize_sql(["SELECT post_count FROM tags WHERE name = ?", q[:related][0]])).to_i
					if count < 100
						# 96% of the tags have a post count below 100. it makes sense to optimize for this common case, then.
						# for tags with low post counts, using "p.id in (...)" is much faster than relying on a join.
						conditions3 << "p.id IN (SELECT pt1.post_id FROM posts_tags pt1 WHERE pt1.tag_id = (SELECT id FROM tags WHERE name = ?))"
					else
						# On the other hand, for extremely populated tags (the top 5%) this method is much faster.
						from << "posts_tags pt1"
						conditions3 << "p.id = pt1.post_id AND pt1.tag_id = (SELECT id FROM tags WHERE name = ?)"
					end
				else
					(1..q[:related].size).each {|i| from << "posts_tags pt#{i}"}
					conditions3 << "p.id = pt1.post_id"
					(2..q[:related].size).each {|i| conditions3 << "pt1.post_id = pt#{i}.post_id"}
					(1..q[:related].size).each {|i| conditions3 << "pt#{i}.tag_id = (SELECT id FROM tags WHERE name = ?)"}
				end

				params += q[:related]
				conditions2 << "(" + conditions3.join(" AND ") + ")"
			end

			conditions << "(" + conditions2.join(" OR ") + ")"
		end

		if q[:exclude].any?
			conditions << "p.id NOT IN (SELECT pt_.post_id FROM posts_tags pt_, tags t_ WHERE pt_.tag_id = t_.id AND t_.name IN (?))"
			params << q[:exclude]
		end

		if q[:rating].is_a?(String)
			case q[:rating].downcase
			when "safe"
				conditions << "p.rating = 's'"

			when "questionable"
				conditions << "p.rating = 'q'"

			when "explicit"
				conditions << "p.rating = 'e'"
			end
		end

		if q[:unlocked_rating] == true
			conditions << "p.is_rating_locked = FALSE"
		end

		conditions << "TRUE" if conditions.empty?

		sql = "SELECT "
		
		if options[:count]
			sql << "COUNT(p)"
		else
			sql << "p.*"
		end

		sql << " FROM " + from.join(", ") + " WHERE " + conditions.join(" AND ")

		if options[:order]
			sql << " ORDER BY " + options[:order]
		end

		if options[:limit]
			sql << " LIMIT " + options[:limit].to_s
		end

		if options[:offset]
			sql << " OFFSET " + options[:offset].to_s
		end

		return Post.sanitize_sql([sql, *params])
	end

	def pretty_rating
		case rating
		when "q"
			return "Questionable"

		when "e"
			return "Explicit"

		when "s"
			return "Safe"
		end
	end

	protected
	def find_ext(file_path)
		ext = File.extname(file_path)
		if ext.blank?
			return "txt"
		else
			return ext[1..-1].downcase
		end
	end
end
