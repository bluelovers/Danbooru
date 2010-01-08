module ArtistMethods
  module GroupMethods
    def member_names
      members.map(&:name).join(", ")
    end
  end
end
