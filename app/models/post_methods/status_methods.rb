module PostMethods
  module StatusMethods
    def status=(s)
      return if s == status
      write_attribute(:status, s)
      touch_change_seq!
    end
  
    Post::STATUSES.each do |x|
      define_method("is_#{x}?") do
        return status == x
      end
    end
  end
end
