class Artist < ActiveRecord::Base
  default_scope :select => "artists.*, coalesce(array_to_string(other_names_array, ', '), '') AS other_names_string"

  include ArtistMethods::UrlMethods
  include ArtistMethods::NoteMethods
  include ArtistMethods::OtherNameMethods
  include ArtistMethods::GroupMethods
  include ArtistMethods::ApiMethods
  include ArtistMethods::VersionMethods
  
  before_validation :normalize
  validates_uniqueness_of :name
  belongs_to :updater, :class_name => "User", :foreign_key => "updater_id"
  attr_accessor :updater_ip_addr
  has_many :members, :class_name => "Artist", :foreign_key => "group_name", :primary_key => "name"

  def self.normalize(name)
    name.downcase.strip.gsub(/ /, '_')
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

  def self.find_by_name(name)
    first(generate_sql(name))
  end
  
  def self.generate_sql(name)
    b = Nagato::Builder.new do |builder, cond|
      cond.add "is_active = TRUE"
      
      case name        
      when /^http/
        cond.add "id IN (?)", find_all_by_url(name).map {|x| x.id}
        
      else
        stripped_name = Artist.normalize(name).to_escaped_for_sql_like
        cond.add "name LIKE ? ESCAPE E'\\\\' OR ? ~~~ ANY (other_names_array) OR group_name LIKE ?", stripped_name, stripped_name, stripped_name
      end
    end
    
    return b.to_hash
  end
end
