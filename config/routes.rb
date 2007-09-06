ActionController::Routing::Routes.draw do |map|
	map.connect "", :controller => "static", :action => "index"
	map.connect ":controller/:action/:id.:format"
	map.connect ":controller/:action/:id"
	map.connect ":controller/:action.:format"
end
