module TagMethods
  module RelatedTagMethods
    module ClassMethods
      def find_related(name)
        if name.is_a?(Array) && name.size > 1
          find_related_for_multiple(name.join(" "))
        else
          find_related_for_single(name.to_s)
        end
      end
      
      def find_related_for_single(name)
        tag = Tag.find_by_name(name)

        if tag
          tag.update_related_if_outdated
          tag.related_tag_array
        else
          []
        end
      end
      
      def find_related_for_multiple(names)
        calculator = RelatedTagCalculator.new
        counts = calculator.calculate_from_sample(names)
        calculator.convert_hash_to_array(counts)        
      end
      
      def find_related_by_type(name, type)
        calculator = RelatedTagCalculator.new
        counts = calculator.calculate_from_sample(name, nil, type)
        calculator.convert_hash_to_array(counts)
      end
    end
    
    def self.included(m)
      m.extend(ClassMethods)
    end
    
    def update_related
      calculator = RelatedTagCalculator.new
      counts = calculator.calculate_from_sample(name)
      self.cached_related = calculator.convert_hash_to_string(counts)
      self.cached_related_expires_on = related_cache_expiry.hours.since
    end
    
    def update_related_if_outdated
      if should_update_related?
        update_related
        save
      end
    end
    
    def related_cache_expiry
      if post_count > 0
        base = Math.sqrt(post_count)
      else
        base = 0
      end
      
      if base > 24
        24
      else
        base
      end
    end
    
    def should_update_related?
      cached_related.blank? || cached_related_expires_on < Time.now
    end
    
    def related_tag_array
      cached_related.split(/ /).in_groups_of(2)
    end
  end
end
