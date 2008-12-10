#!/usr/bin/env ruby

require 'cgi'

module DText
  def parse_inline(str)
    str = CGI.escapeHTML(str)
    str.gsub!(/\[\[.+?\]\]/m) do |tag|
      tag = tag[2..-3]
      if tag =~ /^(.+?)\|(.+)$/
        tag = $1
        name = $2
        '<a href="/wiki/show?title=' + CGI.escape(CGI.unescapeHTML(tag)) + '">' + name + '</a>'
      else
        '<a href="/wiki/show?title=' + CGI.escape(CGI.unescapeHTML(tag)) + '">' + tag + '</a>'
      end
    end
    str.gsub!(/\{\{.+?\}\}/m) do |tag|
      tag = tag[2..-3]
      '<a href="/post/index?tags=' + CGI.escape(CGI.unescapeHTML(tag)) + '">' + tag + '</a>'
    end
    str.gsub!(/post #(\d+)/m, '<a href="/post/show/\1">post #\1</a>')
    str.gsub!(/forum #(\d+)/m, '<a href="/forum/show/\1">forum #\1</a>')
    str.gsub!(/comment #(\d+)/m, '<a href="/forum/show/\1">comment #\1</a>')
    str.gsub!(/pool #(\d+)/m, '<a href="/pool/show/\1">post #\1</a>')
    str.gsub!(/\n/m, "<br>")
    str.gsub!(/(\w+ said:)/m, '<em>\1</em>')
    str.gsub!("[b]", "<strong>")
    str.gsub!("[/b]", "</strong>")
    str.gsub!("[i]", "<em>")
    str.gsub!("[/i]", "</em>")
    str.gsub!(/\[spoilers?\]/m, '<a href="#" class="spoiler">')
    str.gsub!(/\[\/spoilers?\]/m, '</a>')
    str.gsub!(/(https?:\/\/[a-zA-Z0-9_\-#~%.,:;\(\)\[\]$@!&=+?\/]+)/m) do |link|
      if link =~ /([;,.!?\)\]])$/
        link.chop!
        ch = $1
      else
        ch = ""
      end

      '<a href="' + link + '">' + link + '</a>' + ch
    end
    str
  end

  def parse_list(str)
    html = ""
    layout = []
    nest = 0

    str.split(/\n/).each do |line|
      if line =~ /^\s*(\*+) (.+)/
        nest = $1.size
        content = parse_inline($2)
      else
        content = parse_inline(line)
      end

      if nest > layout.size
        html += "<ul>"
        layout << "ul"
      end

      while nest < layout.size
        elist = layout.pop
        if elist
          html += "</#{elist}>"
        end
      end

      html += "<li>#{content}</li>"
    end

    while layout.any?
      elist = layout.pop
      html += "</#{elist}>"
    end

    html
  end

  def parse(str)
    # Make sure quote tags are surrounded by newlines
    str.gsub!(/\s*\[quote\]\s*/m, "\n\n[quote]\n\n")
    str.gsub!(/\s*\[\/quote\]\s*/m, "\n\n[/quote]\n\n")
    str.gsub!(/(?:\r?\n){3,}/, "\n\n")
    str.strip!
    blocks = str.split(/(?:\r?\n){2}/)
    
    html = blocks.map do |block|
      case block
      when /^(h[1-6])\.\s*(.+)$/
        tag = $1
        content = $2
        "<#{tag}>" + parse_inline(content) + "</#{tag}>"

      when /^\s*\*+ /
        parse_list(block)
        
      when "[quote]"
        '<blockquote>'
        
      when "[/quote]"
        '</blockquote>'

      else
        '<p>' + parse_inline(block) + "</p>"
      end
    end

    html.join("")
  end
  
  module_function :parse_inline
  module_function :parse_list
  module_function :parse
end

