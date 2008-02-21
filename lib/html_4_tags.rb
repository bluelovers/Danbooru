# Override default tag helper to output HTMl 4 code
module ActionView
  module Helpers #:nodoc:
    module TagHelper
      def tag(name, options = nil, open = true, escape = true)
        "<#{name}#{tag_options(options, escape) if options}" + (open ? ">" : " />")
      end
    end
    
    module AssetTagHelper
      def stylesheet_tag(source, options)
        tag("link", { "rel" => "stylesheet", "type" => Mime::CSS, "media" => "screen", "href" => html_escape(path_to_stylesheet(source)) }.merge(options), true, false)
      end
    end
    
    class InstanceTag
      def tag(name, options = nil, open = true, escape = true)
        "<#{name}#{tag_options(options, escape) if options}" + (open ? ">" : " />")
      end
    end
  end
end
