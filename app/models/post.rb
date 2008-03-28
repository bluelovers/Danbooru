Dir["#{RAILS_ROOT}/app/models/post/**/*.rb"].each {|x| require x}

class Post < ActiveRecord::Base
  has_many :comments, :order => "id"
  has_many :notes, :order => "id desc"
  has_many :tag_history, :class_name => "PostTagHistory", :table_name => "post_tag_histories", :order => "id desc"
  has_one :flag_detail, :class_name => "FlaggedPostDetail"
  belongs_to :user
  
  include PostMethods::TagMethods
  extend PostMethods::SqlMethods
  include PostMethods::CountMethods
  include PostMethods::CommentMethods
  extend PostMethods::ImageStoreMethods
  include PostMethods::VoteMethods
  include PostMethods::SampleMethods
  
  image_store(CONFIG["image_store"])
  
  before_validation_on_create :download_source
  before_validation_on_create :validate_content_type
  before_validation_on_create :generate_hash
  before_validation_on_create :get_image_dimensions
  before_validation_on_create :generate_sample
  before_validation_on_create :generate_preview
  before_validation_on_create :move_file
  before_destroy :delete_file
  before_destroy :update_status_on_destroy
  after_save :commit_tags
  after_create :increment_count
  after_destroy :decrement_count
  attr_accessor :updater_ip_addr
  attr_accessor :updater_user_id
  attr_accessor :old_tags
  
  if CONFIG["enable_caching"]
    include PostMethods::CacheMethods
    after_save :expire_cache
    after_destroy :expire_cache
  end

  if CONFIG["enable_parent_posts"]
    include PostMethods::ParentMethods
    after_save :update_parent
    validate :validate_parent
    before_destroy :give_favorites_to_parent
  end
  
  def self.destroy_with_reason(id, reason, current_user)
    post = Post.find(id)
    post.flag!(reason, current_user)
    post.reload
    post.destroy
  end
  
  def validate_content_type
    unless %w(jpg jpeg png gif swf).include?(self.file_ext.downcase)
      self.errors.add(:file, "is an invalid content type")
      return false
    end
  end
  
  def flag!(reason, creator_id)
    self.update_attributes(:status => "flagged")
    
    if self.flag_detail == nil
      FlaggedPostDetail.create(:post_id => self.id, :reason => reason, :user_id => creator_id, :is_resolved => false)
    else
      self.flag_detail.update_attributes(:reason => reason, :user_id => creator_id)
    end
  end
  
  def approve!
    if self.flag_detail
      self.flag_detail.update_attributes(:is_resolved => true)
    end
    
    self.update_attributes(:status => "active")
  end

  def update_status_on_destroy
    self.update_attributes(:status => "deleted")
    
    if self.flag_detail
      self.flag_detail.update_attributes(:is_resolved => true)
    end
    
    return false
  end

  def favorited_by
    # Cache results
    if @favorited_by.nil?
      @favorited_by = User.find(:all, :joins => "JOIN favorites f ON f.user_id = users.id", :select => "users.name, users.id", :conditions => ["f.post_id = ?", self.id], :order => "lower(users.name)")
    end

    return @favorited_by
  end

  def rating=(r)
    if r == nil && !self.new_record?
      return
    end

    if self.is_rating_locked?
      return
    end

    r = r.to_s.downcase[0, 1]

    @old_rating = self.rating

    if %w(q e s).include?(r)
      write_attribute(:rating, r)
    else
      write_attribute(:rating, 'q')
    end
  end

  def file_name
    md5 + "." + file_ext
  end

  def delete_tempfile
    FileUtils.rm_f(tempfile_path)
    FileUtils.rm_f(tempfile_preview_path)
    FileUtils.rm_f(tempfile_sample_path)
  end

  def tempfile_path
    "#{RAILS_ROOT}/public/data/#{$PROCESS_ID}.upload"
  end

  def tempfile_preview_path
    "#{RAILS_ROOT}/public/data/#{$PROCESS_ID}-preview.jpg"
  end

  def file_size
    File.size(file_path) rescue 0
  end

# Generates a MD5 hash for the file
  def generate_hash
    unless File.exists?(tempfile_path)
      errors.add(:file, "not found")
      return false
    end
    
    self.md5 = File.open(tempfile_path, 'rb') {|fp| Digest::MD5.hexdigest(fp.read)}

    if connection.select_value("SELECT 1 FROM posts WHERE md5 = '#{md5}'")
      delete_tempfile
      errors.add "md5", "already exists"
      return false
    else
      return true
    end
  end

  def generate_preview
    return true unless image?
    return true unless (self.width && self.height)
    
    unless File.exists?(tempfile_path)
      errors.add(:file, "not found")
      return false
    end

    size = Danbooru.reduce_to({:width=>self.width, :height=>self.height}, {:width=>150, :height=>150})

    # Generate the preview from the new sample if we have one to save CPU, otherwise from the image.
    if File.exists?(tempfile_sample_path)
      path, ext = tempfile_sample_path, "jpg"
    else
      path, ext = tempfile_path, file_ext
    end

    begin
      Danbooru.resize(ext, path, tempfile_preview_path, size, 95)
    rescue Exception => x
      errors.add "preview", "couldn't be generated (#{x})"
      return false
    end

    return true
  end

# automatically downloads from the source url if it's a URL
  def download_source
    if source =~ /^http:\/\// && file_ext.blank?
      begin
        url = URI.parse(source)
        res = Net::HTTP.start(url.host, url.port) do |http|
          http.read_timeout = 10
          http.get(url.request_uri)
        end
        
        raise "HTTP error code: #{res.code} #{res.message}" unless res.code == "200"
        
        self.file_ext = content_type_to_file_ext(res.content_type) || find_ext(source)
        File.open(tempfile_path, 'wb') do |out|
          out.write(res.body)
        end

        if self.source.to_s =~ /moeboard|\/src\/\d{12,}|urnc\.yi\.org/
          self.source = "Image board"
        end

        return true
      rescue Exception => x
        delete_tempfile
        errors.add "source", "couldn't be opened: #{x}"
        return false
      end
    end
  end

# file= assigns a CGI file to the post. This writes the file to disk and generates a unique file name.
  def file=(f)
    return if f.nil? || f.size == 0

    self.file_ext = content_type_to_file_ext(f.content_type) || find_ext(f.original_filename)

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
    return User.find_name(self.user_id)
  end

  def self.find_by_tags(tags, options = {})
    return find_by_sql(Post.generate_sql(tags, options))
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
  
  def api_attributes
    return {
      :id => id, 
      :tags => cached_tags, 
      :created_at => created_at, 
      :creator_id => user_id, 
      :source => source, 
      :score => score, 
      :md5 => md5, 
      :file_url => file_url, 
      :preview_url => preview_url, 
      :preview_width => preview_dimensions()[0],
      :preview_height => preview_dimensions()[1],
      :sample_url => sample_url,
      :sample_width => sample_width || width,
      :sample_height => sample_height || height,
      :rating => rating, 
      :has_children => has_children, 
      :parent_id => parent_id, 
      :status => status,
      :width => width,
      :height => height
    }
  end

  def to_json(options = {})
    return api_attributes.to_json(options)
  end

  def to_xml(options = {})
    return api_attributes.to_xml(options.merge(:root => "post"))
  end

  def find_ext(file_path)
    ext = File.extname(file_path)
    if ext.blank?
      return "txt"
    else
      return ext[1..-1].downcase
    end
  end

  def content_type_to_file_ext(content_type)
    content_type = content_type.chomp

    case content_type
    when "image/jpeg"
      return "jpg"

    when "image/gif"
      return "gif"

    when "image/png"
      return "png"

    when "application/x-shockwave-flash"
      return "swf"

    else
      nil
    end
  end
  
  def delete_from_database
    connection.execute("delete from posts where id = #{self.id}")
  end
  
  def active_notes
    self.notes.select {|x| x.is_active?}
  end
  
  def is_flagged?
    self.status == "flagged"
  end
  
  def is_pending?
    self.status == "pending"
  end
  
  def is_deleted?
    self.status == "deleted"
  end
  
  def is_active?
    self.status == "active"
  end
  
  def can_view?(user)
    return CONFIG["can_see_post"].call(user, self)
  end
  
  def can_be_seen_by?(user)
    return can_view?(user)
  end
  
  def preview_dimensions
    if self.image? && !self.is_deleted?
      dim = Danbooru.reduce_to({:width => self.width, :height => self.height}, {:width => 150, :height => 150})
      return [dim[:width], dim[:height]]
    else
      return [150, 150]
    end
  end
end
