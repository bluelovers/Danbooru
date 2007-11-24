module HTML5Sanitizer
	require 'html5'
	require 'html5/sanitizer'
	include HTML5
	
	def html5sanitize(html_fragment)
		return HTMLParser.parse_fragment(html_fragment, {:tokenizer => HTMLSanitizer, :encoding => 'utf-8'}).to_s
	end
	
	alias hs html5sanitize
	module_function :html5sanitize, :hs
end
