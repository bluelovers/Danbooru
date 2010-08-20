module ForumHelper
  def auto_link_tag_changes(forum_topic, text)
    if @current_user.is_admin?
      text = text.gsub(/tag alias:\s*(\S+) -+(?:>|&gt;) (\S+)/i) do
        %{Tag Alias: #{$1} -> #{$2} [<a href="/tag_alias/index?from_name=#{$1}&to_name=#{$2}&reason=See+forum+%23#{forum_topic.id}">create</a>]}
      end
    
      text = text.gsub(/tag implication:\s*(\S+) -+(?:>|&gt;) (\S+)/i) do
        %{Tag Implication: #{$1} -> #{$2} [<a href="/tag_implication/index?from_name=#{$1}&to_name=#{$2}&reason=See+forum+%23#{forum_topic.id}">create</a>]}
      end
    end
    
    text
  end
end
