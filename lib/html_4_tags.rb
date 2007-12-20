# Override default tag helper to output HTMl 4 code
module ActionView
  module Helpers #:nodoc:
    module TagHelper
      def tag(name, options = nil, open = true)
        "<#{name}#{tag_options(options) if options}" + (open ? ">" : " />")
      end
    end
  end
end
