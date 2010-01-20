class Note < ActiveRecord::Base
  include ActiveRecord::Acts::Versioned

  belongs_to :post
  before_save :blank_body
  acts_as_versioned :order => "updated_at DESC"
  after_save :update_post
  
  module LockMethods
    def self.included(m)
      m.validate :post_must_not_be_note_locked
    end
    
    def post_must_not_be_note_locked
      if is_locked?
        errors.add_to_base "Post is note locked"
        return false
      end
    end
    
    def is_locked?
      if select_value_sql("SELECT 1 FROM posts WHERE id = ? AND is_note_locked = ?", post_id, true)
        return true
      else
        return false
      end
    end
  end
  
  module ApiMethods
    def api_attributes
      return {
        :id => id, 
        :created_at => created_at, 
        :updated_at => updated_at, 
        :creator_id => user_id, 
        :x => x, 
        :y => y, 
        :width => width, 
        :height => height, 
        :is_active => is_active, 
        :post_id => post_id, 
        :body => body, 
        :version => version
      }
    end

    def to_xml(options = {})
      api_attributes.to_xml(options.merge(:root => "note"))
    end

    def to_json(*args)
      return api_attributes.to_json(*args)
    end
  end
  
  include LockMethods
  include ApiMethods
  
  def blank_body
    self.body = "(empty)" if body.blank?
  end

  # TODO: move this to a helper
  def formatted_body
    body.gsub(/<tn>(.+?)<\/tn>/m, '<br><p class="tn">\1</p>').gsub(/\n/, '<br>')
  end

  def update_post
    active_notes = select_value_sql("SELECT 1 FROM notes WHERE is_active = ? AND post_id = ? LIMIT 1", true, post_id)
    
    if active_notes
      execute_sql("UPDATE posts SET last_noted_at = ? WHERE id = ?", updated_at, post_id)
    else
      execute_sql("UPDATE posts SET last_noted_at = ? WHERE id = ?", nil, post_id)
    end
  end

  def author
    User.find_name(user_id)
  end
  
  def self.undo_changes_by_user(user_id)
    transaction do  
      notes = Note.all(:joins => "join note_versions nv on nv.note_id = notes.id", :select => "distinct notes.*", :conditions => ["nv.user_id = ?", user_id])
      
      NoteVersion.destroy_all(["user_id = ?", user_id])
      notes.each do |note|
        first = note.versions.first
        if first
          note.revert_to!(first.version)
        end
      end
    end
  end
  
  def self.generate_sql(params)
    b = Nagato::Builder.new do |builder, cond|
      if !params[:query].blank?
        query = params[:query].scan(/\S+/).join(" & ")        
        cond.add "text_search_index @@ plainto_tsquery(?)", query
      end
      
      if params[:status] == "Active"
        cond.add "is_active = true"
      elsif params[:status] == "Deleted"
        cond.add "is_active = false"
      end
    end

    return b.to_hash
  end
end
