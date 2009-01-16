namespace :fix do
  desc 'Fix old formatting'
  task :dtext => :environment do
    ActiveRecord::Base.connection.execute("UPDATE comments SET body = replace(body, '<i>', '[i]') WHERE body LIKE '%<i>%'")
    ActiveRecord::Base.connection.execute("UPDATE comments SET body = replace(body, '</i>', '[/i]') WHERE body LIKE '%</i>%'")
    ActiveRecord::Base.connection.execute("UPDATE comments SET body = replace(body, '<b>', '[b]') WHERE body LIKE '%<b>%'")
    ActiveRecord::Base.connection.execute("UPDATE comments SET body = replace(body, '</b>', '[/b]') WHERE body LIKE '%</b>%'")
    ActiveRecord::Base.connection.execute("UPDATE comments SET body = replace(body, '>>', 'comment #') WHERE body LIKE '%>>%'")  
  
    ActiveRecord::Base.connection.execute("UPDATE forum_posts SET body = replace(body, '<b>', '[b]') WHERE body LIKE '%<b>%'")
    ActiveRecord::Base.connection.execute("UPDATE forum_posts SET body = replace(body, '</b>', '[/b]') WHERE body LIKE '%</b>%'")
    ActiveRecord::Base.connection.execute("UPDATE forum_posts SET body = replace(body, '<i>', '[i]') WHERE body LIKE '%<i>%'")
    ActiveRecord::Base.connection.execute("UPDATE forum_posts SET body = replace(body, '</i>', '[/i]') WHERE body LIKE '%</i>%'")
  
    ActiveRecord::Base.connection.execute("UPDATE wiki_pages SET body = replace(body, '<b>', '[b]') WHERE body LIKE '%<b>%'")
    ActiveRecord::Base.connection.execute("UPDATE wiki_pages SET body = replace(body, '</b>', '[/b]') WHERE body LIKE '%</b>%'")
    ActiveRecord::Base.connection.execute("UPDATE wiki_pages SET body = replace(body, '<i>', '[i]') WHERE body LIKE '%<i>%'")
    ActiveRecord::Base.connection.execute("UPDATE wiki_pages SET body = replace(body, '</i>', '[/i]') WHERE body LIKE '%</i>%'")
  
  end
end

