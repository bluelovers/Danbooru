module ArtistMethods
  module OtherNameMethods
    def self.included(m)
      m.before_save :initialize_other_names
    end
    
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
end
