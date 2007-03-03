ActionController::Routing::Routes.draw do |map|
	map.connect "", :controller => "static", :action => "index"
	map.connect ":controller/:action/:id"
end
