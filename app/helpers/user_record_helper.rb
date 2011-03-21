module UserRecordHelper
  def user_record_score_select(obj, field)
    select(obj, field, [["Positive", 1], ["Neutral", 0], ["Negative", -1]])
  end
end
