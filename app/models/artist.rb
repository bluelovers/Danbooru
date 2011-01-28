class Artist < ActiveRecord::Base
  default_scope :select => "artists.*, coalesce(array_to_string(other_names_array, ', '), '') AS other_names_string"

  module ApiMethods
    def api_attributes
      return {
        :id => id, 
        :name => name, 
        :other_names => other_names,
        :group_name => group_name,
        :urls => artist_urls.map {|x| x.url},
        :is_active => is_active,
        :version => version,
        :updater_id => updater_id
      }
    end

    def to_xml(options = {})
      attribs = api_attributes
      attribs[:urls] = attribs[:urls].join(" ")
      attribs.to_xml(options.merge(:root => "artist"))
    end

    def to_json(*args)
      return api_attributes.to_json(*args)
    end
  end
  
  module GroupMethods
    def member_names
      members.map(&:name).join(", ")
    end
  end
  
  module NoteMethods
    def wiki_page
      WikiPage.find_page(name)
    end

    def notes_locked?
      wiki_page.is_locked? rescue false
    end

    def notes
      wiki_page.body rescue ""
    end

    def notes=(text)
      @notes = text
    end
    
    def commit_notes
      unless @notes.blank?
        if wiki_page.nil?
          WikiPage.create(:title => name, :body => @notes, :ip_addr => updater_ip_addr, :user_id => updater_id)
        elsif wiki_page.is_locked?
          errors.add(:notes, "are locked")
        else
          wiki_page.update_attributes(:body => @notes, :ip_addr => updater_ip_addr, :user_id => updater_id)
        end
      end
    end
  end
  
  module OtherNameMethods
    def initialize_other_names
      if @other_names
        self.other_names_array = "{" + @other_names.split(/,/).map do |x|
          sanitized_name = x.gsub(/\\/, "\\\\\\\\").gsub(/"/, "\\\\\"").strip.gsub(/\s/, "_")
          
          %{"#{sanitized_name}"}
        end.join(",") + "}"
      end
    end
    
    def other_names=(x)
      @other_names = x
    end
    
    def other_names
      if self["other_names_string"]
        self.other_names_string
      else
        nil
      end
    end
  end
  
  module UrlMethods
    module ClassMethods
      def find_all_by_url(url)
        url = ArtistUrl.normalize(url)
        artists = []

        while artists.empty? && url.size > 10
          u = url.gsub(/\/+$/, "") + "/"
          u = u.to_escaped_for_sql_like.gsub(/\*/, '%') + '%'
          artists += Artist.find(:all, :joins => "JOIN artist_urls ON artist_urls.artist_id = artists.id", :conditions => ["artists.is_active = TRUE AND artist_urls.normalized_url LIKE ? ESCAPE E'\\\\'", u], :order => "artists.name", :limit => "5")

          # Remove duplicates based on name
          artists = artists.inject({}) {|all, artist| all[artist.name] = artist ; all}.values
          url = File.dirname(url) + "/"
        end

        if artists.size > 3
          return []
        else
          return artists[0, 20]
        end
      end
    end
    
    def self.included(m)
      m.extend(ClassMethods)
    end
    
    def commit_urls
      if @urls
        artist_urls.clear

        @urls.scan(/\S+/).each do |url|
          artist_urls.create(:url => url)
        end
      end
    end
    
    def urls=(urls)
      @urls = urls
    end
    
    def urls
      @urls || artist_urls.map {|x| x.url}.join("\n")
    end
  end
  
  module VersionMethods
    def initialize_version
      if version.nil?
        self.version = 1
      end
    end

    def create_version
      cached_urls = artist_urls.map {|x| x.normalized_url}.join(" ")
      
      ArtistVersion.create(
        :artist_id => id,
        :version => version,
        :name => name,
        :updater_id => updater_id,
        :cached_urls => cached_urls,
        :is_active => is_active,
        :other_names_array => other_names_array,
        :group_name => group_name
      )
      
      Artist.execute_sql "UPDATE artists SET version = version + 1 WHERE id = #{id}"
    end
  end
  
  include UrlMethods
  include NoteMethods
  include OtherNameMethods
  include GroupMethods
  include ApiMethods
  include VersionMethods
  
  after_save :commit_notes
  before_save :initialize_other_names
  after_save :commit_urls
  has_many :artist_urls, :dependent => :delete_all
  before_save :initialize_version
  after_save :create_version
  has_many :versions, :class_name => "ArtistVersion", :order => "version desc", :dependent => :delete_all
  before_validation :normalize
  validates_uniqueness_of :name
  validates_format_of :name, :with => /\S/
  belongs_to :updater, :class_name => "User", :foreign_key => "updater_id"
  attr_accessor :updater_ip_addr
  has_many :members, :class_name => "Artist", :foreign_key => "group_name", :primary_key => "name"

  def self.normalize(name)
    name.downcase.strip.gsub(/ /, '_')
  end

  def self.find_by_any_name(name)
    first(generate_sql(:name => name))
  end
  
  def self.generate_sql(params)
    b = Nagato::Builder.new do |builder, cond|
      cond.add "is_active = TRUE"
      
      case params[:name]
      when /^http/
        cond.add "id IN (?)", find_all_by_url(params[:name]).map {|x| x.id}
      
      when /name:(.+)/
        stripped_name = Artist.normalize($1).to_escaped_for_sql_like
        cond.add "name LIKE ? ESCAPE E'\\\\'", stripped_name
        
      when /other:(.+)/
        stripped_name = Artist.normalize($1).to_escaped_for_sql_like
        cond.add "? ~~~ ANY (other_names_array)", stripped_name
        
      when /group:(.+)/
        stripped_name = Artist.normalize($1).to_escaped_for_sql_like
        cond.add "group_name LIKE ?", stripped_name
        
      when /./
        stripped_name = Artist.normalize(params[:name]).to_escaped_for_sql_like
        cond.add "name LIKE ? ESCAPE E'\\\\' OR ? ~~~ ANY (other_names_array) OR group_name LIKE ? ", stripped_name, stripped_name, stripped_name
      end
      
      cond.add_unless_blank "id = ?", params[:id]
    end
    
    return b.to_hash
  end
  
  def ban!(current_user)
    Post.transaction do
      Post.find_by_sql(Post.generate_sql(name)).each do |post|
        Post.destroy_with_reason(post.id, "Artist requested removal", current_user)
      end

      update_attribute(:is_banned, true)
    end
  end
  
  def normalize
    self.name = Artist.normalize(name)
  end
  
  def to_s
    return name
  end
  
  def updater_name
    User.find_name(updater_id).tr("_", " ")
  end
  
  def has_tag_alias?
    TagAlias.exists?(["name = ?", name])
  end
  
  def tag_alias_name
    TagAlias.find_by_name(name).alias_name
  end

end
