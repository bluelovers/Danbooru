ActionController::Routing::Routes.draw do |map|
  map.connect "", :controller => "static", :action => "index"
  map.connect "post/show/:id/:tag_title", :controller => "post", :action => "show", :requirements => {:id => /\d+/}
  map.connect ":controller/:action/:id.:format", :requirements => {:id => /\d+/}
  map.connect ":controller/:action/:id", :requirements => {:id => /\d+/}
  map.connect ":controller/:action.:format"
end
