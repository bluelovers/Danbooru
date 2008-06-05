require "action_view/helpers/tag_helper.rb"
require "action_view/helpers/asset_tag_helper.rb"

# Fix a bug in expand_javascript_sources: if the cache file exists, but the server
# is started in development, the old cache will be included among all of the individual
# source files.
module ActionView
  module Helpers
    module AssetTagHelper
      private
      alias_method :orig_expand_javascript_sources, :expand_javascript_sources
      def expand_javascript_sources(sources)
        x = orig_expand_javascript_sources sources
        x.delete("application")
        x
      end
    end
  end
end

# Fix another bug: if the javascript sources are changed, the cache is never
# regenerated.  Call on init.
module AssetCache
  # This is dumb.  How do I call this function without wrapping it in a class?
  class RegenerateJavascriptCache
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::AssetTagHelper
  end

  def clear_js_cache
    # Don't do anything if caching is disabled; we won't use the file anyway, and
    # if we're in a rake script, we'll delete the file and then not regenerate it.
    return if not ActionController::Base.perform_caching

    # Overwrite the file atomically, so nothing breaks if a user requests the file
    # before we finish writing it.
    path = (defined?(RAILS_ROOT) ? "#{RAILS_ROOT}/public" : "public")
    cache_temp = "application-new-#{$PROCESS_ID}" 
    temp = "#{path}/javascripts/#{cache_temp}.js" 
    file = "#{path}/javascripts/application.js"
    File.unlink(temp) if File.exist?(temp)
    c = RegenerateJavascriptCache.new
    c.javascript_include_tag(:all, :cache => cache_temp) 

    FileUtils.mv(temp, file)
  end

  module_function :clear_js_cache
end

