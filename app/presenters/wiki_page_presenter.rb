class WikiPagePresenter < Presenter
  attr_reader :wiki_page, :title
  
  def initialize(template, user, title, version)
    @template = template
    @user = user
    @title = title.downcase
    @wiki_page = WikiPage.find_page(title, version)
    @tag = Tag.find_by_name(title.downcase)
    @posts = Post.find_by_sql(Post.generate_sql(title, :order => "p.id DESC", :limit => 8)).select {|x| x.can_be_seen_by?(@user)}
  end
  
  def html_title
    html = ""    
    html += h(@tag.pretty_type_name) + ": " if @tag
    
    if @wiki_page
      html += h(@wiki_page.pretty_title)
      
      unless @wiki_page.last_version?
        html += %[<span class="old-version">(Version #{@wiki_page.version})</span>]
      end
    else
      html += h(@title.tr("_", " "))
    end
    
    html
  end
  
  def html_body(view_template)
    html = ""
    
    if @wiki_page.nil?
      html += %[<p>No page currently exists.</p>]
    else
      html += view_template.format_text(@wiki_page.body)
    end
    
    tag_alias = TagAlias.find_by_name(@title)
    
    if tag_alias
      tag_alias_link = view_template.link_to(h(tag_alias.alias_name), :controller => "wiki", :action => "show", :title => tag_alias.alias_name)
      html += %[<p>This tag has been aliased to #{tag_alias_link}.</p>]
    end
    
    if @tag
      tags_that_alias_to_wiki = TagAlias.all(:conditions => ["alias_id = ?", @tag.id])
      if tags_that_alias_to_wiki.any?
        tags = tags_that_alias_to_wiki.map(&:name).join(", ")
        html += %[<p>The following are aliased to this tag: #{tags}]
      end
    end
    
    html
  end
  
  def html_posts(view_template)
    html = ""
    
    if @posts.any?
      html += %[<h4>Recent Posts</h4><div style="margin: 1em 0;">]
      html += view_template.render(:partial => "post/posts", :locals => {:posts => @posts})
      html += %[</div>]
    end
    
    html
  end
end
