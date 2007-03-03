=begin

= image_size.rb
measure image (GIF, PNG, JPEG ,,, etc) size
coded by Pure Ruby
["PCX", "PSD", "XPM", "TIFF", "XBM", "PGM", "PBM", "PPM", "BMP", "JPEG", "PNG", "GIF"]

== Install:
$ ruby install.rb
It will install lib/csv.rb to your site_ruby directory such as
/usr/local/lib/ruby/site_ruby/1.6/.

== Methods:
=== new(image)
receive image & measure size.
argument is image String or IO.
cannot use IO included seek.

=== get_type
return type

=== get_height
return height size

=== get_width
return width size

== Class Methods:
=== type
return type list (Array).

== How to

=== argument is String
  require "image_size"
  open("image.gif", "rb") do |fh|
    img = ImageSize.new(fh.read)
  end

=== argument is IO
  require "image_size"
  open("image.gif", "rb") do |fh|
    img = ImageSize.new(fh)
  end

=== get type, width and height
  img = ImageSize.new(fh)
  print "type="{} width=#{img.width} height=#{img.width}\n"

=== Type List
  require "image_size"
  ImageSize.type
   => ["PCX", "PSD", "XPM", "TIFF", "XBM", "PGM", "PBM", "PPM", "BMP", "JPEG", "PNG", "GIF", "OTHER"]

=end
