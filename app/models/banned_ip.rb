class BannedIp < ActiveRecord::Base
  belongs_to :creator, :class_name => "User"
  
  def self.is_banned?(ip_addr)
    exists?(["ip_addr = ?", ip_addr])
  end
  
  def self.search(user_ids)
    comments = count_by_ip_addr("comments", user_ids)
    tag_changes = count_by_ip_addr("post_tag_histories", user_ids)
    notes = count_by_ip_addr("note_versions", user_ids)
    pools = count_by_ip_addr("pool_updates", user_ids)
    wiki_pages = count_by_ip_addr("wiki_page_versions", user_ids)
    
    return {
      "comments" => comments,
      "tag_changes" => tag_changes,
      "notes" => notes,
      "pools" => pools,
      "wiki_pages" => wiki_pages
    }
  end
  
  def self.count_by_ip_addr(table, user_ids, user_id_field = "user_id")
    select_all_sql("SELECT ip_addr, count(*) FROM #{table} WHERE #{user_id_field} IN (?) GROUP BY ip_addr ORDER BY count(*) DESC", user_ids)
  end
end
