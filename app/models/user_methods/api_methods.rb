module UserMethods
  module ApiMethods
    def api_attributes
      {:name => name, :id => id, :level => level, :created_at => created_at.strftime("%Y-%m-%d %H:%M")}
    end
    
    def to_xml(options = {})
      options[:indent] ||= 2      
      xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
      xml.user(api_attributes) do
        blacklisted_tags_array.each do |t|
          xml.blacklisted_tag(:tag => t)
        end
        
        tag_subscriptions.each do |ts|
          xml.subscription(:name => ts.name) do
            ts.tag_query.scan(/\S+/).each do |tag|
              xml.tag(:name => tag)
            end
          end
        end

        yield options[:builder] if block_given?
      end
    end

    def to_json(*args)
      api_attributes.merge(:blacklisted => blacklisted_tags_array, :subscriptions => tag_subscriptions.inject({}) {|all, x| all[x.name] = x.tag_query; all}).to_json(*args)
    end
  end
end
