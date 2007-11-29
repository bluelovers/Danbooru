module UserHelper
  def ban_duration_select(obj, field)
    select(obj, field, [["One Day", "one_day"], ["One Week", "one_week"], ["One Month", "one_month"], ["One Year", "one_year"]])
  end
end
