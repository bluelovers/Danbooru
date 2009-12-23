module ArtistHelper
  def artist_list_link_to(artist, method)
    artist.__send__(method).split(/,/).map {|x| link_to(h(x.strip), :action => "show", :name => x.strip, :id => nil)}.join(", ")
  end
end
