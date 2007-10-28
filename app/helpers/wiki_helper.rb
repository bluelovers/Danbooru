module WikiHelper
  def wikilize(text)
    fmt = sanitize(text)

    fmt.gsub!(/\[\[(.+?)\]\]/) do
      match = $1

      if match =~ /(.+?)\|(.+)/
        link_to h($2), :controller => "wiki", :action => "show", :title => $1.gsub(/\s/, '_').downcase
      else
        link_to h(match), :controller => "wiki", :action => "show", :title => match.gsub(/\s/, '_').downcase
      end
    end

    textilize(fmt)
  end

  def linked_from(to)
    links = to.find_pages_that_link_to_this.map do |page|
      link_to(page.pretty_title, :controller => "wiki", :action => "show", :title => page.title)
    end.join(", ")

    links.empty? ? "None" : links
  end
end
