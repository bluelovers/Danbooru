module ArtistMethods
  module NoteMethods
    def self.included(m)
      m.after_save :commit_notes
    end
    
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
end
