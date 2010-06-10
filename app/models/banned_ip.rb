class BannedIp < ActiveRecord::Base
  belongs_to :creator, :class_name => "User"
  
  def self.is_banned?(ip_addr)
    exists?(["ip_addr = ?", ip_addr])
  end
  
  def self.search_ip_addrs(ip_addrs)
    comments = count_ip_addrs_by_user("comments", ip_addrs)
    tag_changes = count_ip_addrs_by_user("post_tag_histories", ip_addrs)
    notes = count_ip_addrs_by_user("note_versions", ip_addrs)
    pools = count_ip_addrs_by_user("pool_updates", ip_addrs)
    wiki_pages = count_ip_addrs_by_user("wiki_page_versions", ip_addrs)
    
    return {
      "comments" => comments,
      "tag_changes" => tag_changes,
      "notes" => notes,
      "pools" => pools,
      "wiki_pages" => wiki_pages
    }
  end
  
  def self.search_users(user_ids)
    comments = count_users_by_ip_addr("comments", user_ids)
    tag_changes = count_users_by_ip_addr("post_tag_histories", user_ids)
    notes = count_users_by_ip_addr("note_versions", user_ids)
    pools = count_users_by_ip_addr("pool_updates", user_ids)
    wiki_pages = count_users_by_ip_addr("wiki_page_versions", user_ids)
    
    return {
      "comments" => comments,
      "tag_changes" => tag_changes,
      "notes" => notes,
      "pools" => pools,
      "wiki_pages" => wiki_pages
    }
  end
  
  def self.count_users_by_ip_addr(table, user_ids, user_id_field = "user_id")
    select_all_sql("SELECT ip_addr, count(*) FROM #{table} WHERE #{user_id_field} IN (?) GROUP BY ip_addr ORDER BY count(*) DESC", user_ids)
  end
  
  def self.count_ip_addrs_by_user(table, ip_addrs, user_id_field = "user_id")
    select_all_sql("SELECT #{user_id_field}, count(*) FROM #{table} WHERE ip_addr IN (?) GROUP BY #{user_id_field}", ip_addrs)
  end
end
