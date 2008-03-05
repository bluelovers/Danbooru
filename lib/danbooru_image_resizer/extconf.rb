#!/bin/env ruby

require 'mkmf'

CONFIG['CC'] = "g++"

dir_config("gd")
dir_config("jpeg")
dir_config("png")

ok = true

ok &&= have_header("gd.h")

ok &&= have_library("gd")
ok &&= have_library("jpeg")
ok &&= have_library("png")

ok &&= have_func("gdImageCreateFromGif", "gd.h")
ok &&= have_func("gdImageJpeg", "gd.h")
ok &&= have_func("jpeg_set_quality", ["stdlib.h", "stdio.h", "jpeglib-extern.h"])

if !ok
  raise "Missing prerequisites"
end

with_cflags("-O2 -fno-exceptions -Wall") {true}
#with_cflags("-O0 -g -fno-exceptions -Wall") {true}

create_makefile("danbooru_image_resizer")
