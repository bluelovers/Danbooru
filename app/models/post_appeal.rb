class PostAppeal < ActiveRecord::Base
  attr_accessor :note
  validates_uniqueness_of :post_id, :scope => :user_id
  before_validation :merge_note
  belongs_to :user
  belongs_to :post
  
  def merge_note
    if !note.blank?
      self.reason = "#{reason}: #{note}"
    end
  end
end
