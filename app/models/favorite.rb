class Favorite < ActiveRecord::Base
  def self.build_sql_order_clause(posts_table_alias, post_ids)
    if post_ids.empty?
      return "#{posts_table_alias}.id desc"
    end

    conditions = []
    
    post_ids.each_with_index do |post_id, n|
      conditions << "when #{post_id} then #{n}"
    end
    
    "case #{posts_table_alias}.id " + conditions.join(" ") + " end"
  end
end
