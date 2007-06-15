class Post < ActiveRecord::Base
  before_validation_on_create :auto_download
  before_validation_on_create :generate_hash
  before_validation_on_create :generate_preview
  before_validation_on_create :get_image_dimensions
  before_validation_on_create :move_file
  before_destroy :delete_file
  after_create :update_neighbor_links_on_create
  before_destroy :update_neighbor_links_on_destroy
  attr_accessor :updater_ip_addr
  attr_accessor :updater_user_id
  after_save :commit_tags
  after_save :blank_image_board_sources
  if CONFIG["enable_caching"]
    after_create :expire_cache_on_create
    after_update :expire_cache_on_update
    after_destroy :expire_cache_on_destroy
  end
  attr_accessible :source, :rating, :next_post_id, :prev_post_id, :file, :tags, :is_rating_locked, :is_note_locked, :updater_user_id, :updater_ip_addr, :user_id, :ip_addr

  votable
  image_store
  has_and_belongs_to_many :tags, :order => "name"
  has_many :comments, :order => "id", :conditions => "(is_spam IS NULL OR is_spam = FALSE)"
  has_many :notes, :order => "id desc"
  has_many :tag_history, :class_name => "PostTagHistory", :table_name => "post_tag_histories", :order => "id desc"
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

  def expire_cache_on_create
    Cache.expire(:create_post => self.id, :tags => self.cached_tags)
  end

  def expire_cache_on_update
    Cache.expire(:update_post => self.id, :tags => self.cached_tags)
  end

  def expire_cache_on_destroy
    Cache.expire(:destroy_post => self.id, :tags => self.cached_tags)
  end

  def blank_image_board_sources
    if self.source.to_s =~ /moeboard|\/src\/[1-9]{12,}/
      connection.execute("UPDATE posts SET source = '' WHERE id = #{self.id}")
    end
  end

  def append_tags(t)
    @tag_cache = self.cached_tags + " " + t
  end

  def tags=(t)
    @tag_cache = t || ""
  end

  def rating=(r)
    if r == nil && !self.new_record?
      return
    end

    if self.is_rating_locked?
      self.errors.add "rating", "rating is locked"
      return
    end

    r = r.to_s.downcase[0, 1]

    if %w(q e s).include?(r)
      write_attribute(:rating, r)
    else
      write_attribute(:rating, 'q')
    end
  end

  # commits the tag changes to the database
  def commit_tags
    if @tag_cache == nil
      if self.new_record?
        @tag_cache = "tagme"
      else
        return
      end
    end

    raise "IP address not set" if self.updater_ip_addr == nil

    @tag_cache = Tag.scan_tags(@tag_cache)
    @tag_cache = ["tagme"] if @tag_cache.empty?
    @tag_cache = TagAlias.to_aliased(@tag_cache).uniq
    @tag_cache = TagImplication.with_implied(@tag_cache).uniq

    transaction do
      if (@tag_cache & CONFIG["questionable_tags"]).any? && self.rating == 's'
        connection.execute("UPDATE posts SET rating = 'q' WHERE id = #{self.id}")
      end

      connection.execute("DELETE FROM posts_tags WHERE post_id = #{id}")
      tag_list = []

      @tag_cache.each do |t|
        if t =~ /^rating:(.+)/
          connection.execute(Post.sanitize_sql(["UPDATE posts SET rating = ? WHERE id = ?", $1[0,1], self.id]))
        else
          record = Tag.find_or_create_by_name(t)
          unless tag_list.include?(record.name)
            tag_list << record.name
            connection.execute("INSERT INTO posts_tags (post_id, tag_id) VALUES (#{id}, #{record.id})")
          end
        end
      end
      
      tag_string = tag_list.sort.uniq.join(" ")

      unless connection.select_value("SELECT tags FROM post_tag_histories WHERE post_id = #{id} ORDER BY id DESC LIMIT 1") == tag_string
        PostTagHistory.create(:post_id => self.id, :tags => tag_string, :user_id => self.updater_user_id, :ip_addr => self.updater_ip_addr)
      end
      connection.execute(Post.sanitize_sql(["UPDATE posts SET cached_tags = ? WHERE id = #{id}", tag_string]))
    end
  end

  def file_name
    md5 + "." + file_ext
  end

  def delete_tempfile
    FileUtils.rm_f(tempfile_path)
    FileUtils.rm_f(tempfile_preview_path)
  end

  def tempfile_path
    "#{RAILS_ROOT}/public/data/#{$$}.upload"
  end

  def tempfile_preview_path
    "#{RAILS_ROOT}/public/data/#{$$}-preview.jpg"
  end

# Generates a MD5 hash for the file
  def generate_hash
    self.md5 = File.open(tempfile_path, 'rb') {|fp| Digest::MD5.hexdigest(fp.read)}

    if connection.select_value("SELECT 1 FROM posts WHERE md5 = '#{md5}'")
      delete_tempfile
      errors.add "md5", "already exists"
      return false
    end
  end

  def generate_preview
    return unless image?

    begin
      unless system("#{RAILS_ROOT}/lib/resizer/resizer #{tempfile_path} #{tempfile_preview_path} #{file_ext}")
        errors.add 'preview', "couldn't be generated"
        return false
      end
    rescue Exception => x
      errors.add 'preview', "couldn't be generated: #{x}"
      return false
    end
  end

# auto_download automatically downloads from the source url if it's a URL
  def auto_download
    return if !(source =~ /^http/ && file_ext.blank?)

    begin
      img = Net::HTTP.get(URI.parse(source))
      self.file_ext = find_ext(source)
      File.open(tempfile_path, 'wb') do |out|
        out.write(img)
      end
    rescue Exception => x
      delete_tempfile
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

  def get_image_dimensions
    if image? or flash?
      imgsize = ImageSize.new(File.open(tempfile_path, "rb"))
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
      connection.execute("UPDATE posts SET prev_post_id = #{prev_post.id} WHERE id = #{self.id}")
      connection.execute("UPDATE posts SET next_post_id = #{self.id} WHERE id = #{prev_post.id}")
    end
  end

  def update_neighbor_links_on_destroy
    prev_post = Post.find(:first, :conditions => ["id < ?", id], :order => "id DESC")
    next_post = Post.find(:first, :conditions => ["id > ?", id], :order => "id ASC")

    if prev_post == nil && next_post == nil
      # do nothing
    elsif prev_post != nil && next_post != nil
      # deleted post is in middle
      connection.execute("UPDATE posts SET next_post_id = #{next_post.id} WHERE id = #{prev_post.id}")
      connection.execute("UPDATE posts SET prev_post_id = #{prev_post.id} WHERE id = #{next_post.id}")
    elsif prev_post == nil
      # no previous post, therefore deleted post is first post
      connection.execute("UPDATE posts SET prev_post_id = NULL WHERE id = #{next_post.id}")
    elsif next_post == nil
      # no next post, therefore deleted post is last post
      connection.execute("UPDATE posts SET next_post_id = NULL WHERE id = #{prev_post.id}")
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

    if CONFIG["enable_tag_blacklists"] && options[:tag_blacklist]
      conditions << "p.id NOT IN (SELECT pt_.post_id FROM posts_tags pt_, tags t_ WHERE pt_.tag_id = t_.id AND t_.name IN (?))"
      params << options[:tag_blacklist]
    end

    if CONFIG["enable_post_thresholds"] && options[:post_threshold]
      conditions << "p.score >= ?"
      params << options[:post_threshold]
    end

    if options[:safe_mode]
      conditions << "p.rating = 's'"
    end

    if CONFIG["enable_user_blacklists"] && options[:user_blacklist]
      conditions << "p.user_id NOT IN (SELECT id FROM users WHERE name IN (?))"
      params << options[:user_blacklist]
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

  def to_json(options = {})
    return generate_attributes(options[:select], :js).to_json
  end

  def to_xml(options = {})
    options[:indent] ||= 2
    xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
    xml.instruct! unless options[:skip_instruct]
    xml.post(generate_attributes(options[:select], :xml))
  end

  protected
  def generate_attributes(select_attributes, escape_method)
    attribs = {}
    attribs[:id] = self.id
    select_attributes ||= %w(tags author file)

    select_attributes.each do |attr|
      case attr
      when "created_at"
      attribs[:created_at] = self.created_at.strftime("%D %T")

      when "source"
      if escape_method == :xml
        attribs[:source] = CGI.escapeHTML(self.source)
      elsif escape_method == :js
        attribs[:source] = self.source.to_escaped_js
      else
        attribs[:source] = source
      end

      when "author"
      if escape_method == :xml
        attribs[:author] = CGI.escapeHTML(self.author)
      elsif escape_method == :js
        attribs[:author] = self.author.to_escaped_js
      else
        attribs[:author] = self.author
      end

      when "score"
      attribs[:score] = self.score

      when "md5"
      attribs[:md5] = self.md5

      when "preview"
      attribs[:preview] = self.preview_url

      when "file"
      attribs[:file] = self.file_url

      when "rating"
      attribs[:rating] = self.pretty_rating

      when "tags"
      if escape_method == :xml
        attribs[:tags] = CGI.escapeHTML(self.cached_tags)
      elsif escape_method == :js
        attribs[:tags] = self.cached_tags.to_escaped_js
      end

      when "next"
      attribs[:next] = self.next_post_id

      when "previous"
      attribs[:previous] = self.prev_post_id

      end
    end

    return attribs
  end

  def find_ext(file_path)
    ext = File.extname(file_path)
    if ext.blank?
      return "txt"
    else
      return ext[1..-1].downcase
    end
  end
end
