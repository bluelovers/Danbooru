module UserMethods
  module TagSubscriptionMethods
    def self.included(m)
      m.has_many :tag_subscriptions, :dependent => :delete_all, :order => "name"
    end
    
    def tag_subscriptions_text=(text)
      User.transaction do
        tag_subscriptions.clear
      
        text.scan(/\S+/).each do |new_tag_subscription|
          tag_subscriptions.create(:tag_query => new_tag_subscription)
        end
      end
    end
    
    def tag_subscriptions_text
      tag_subscriptions.map(&:tag_query).sort.join(" ")
    end
    
    def tag_subscription_posts(limit, name)
      TagSubscription.find_posts(id, name, limit)
    end
  end
end
