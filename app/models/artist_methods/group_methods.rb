module ArtistMethods
  module GroupMethods
    def members
      @members ||= Artist.all(:conditions => ["group_name = ?", name])
    end
    
    def member_names
      members.map(&:name).join(", ")
    end
  end
end
