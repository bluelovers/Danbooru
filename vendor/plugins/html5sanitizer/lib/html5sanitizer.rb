module HTML5Sanitizer
	require 'html5'
	require 'html5/sanitizer'
	include HTML5
	
	def html5sanitize(html_fragment)
	  old_kcode=$KCODE
	  $KCODE="NONE"
		s = HTMLParser.parse_fragment(html_fragment, {:tokenizer => HTMLSanitizer, :encoding => 'utf-8'}).to_s
		$KCODE=old_kcode
		return s
	end
	
	alias hs html5sanitize
	module_function :html5sanitize, :hs
end
