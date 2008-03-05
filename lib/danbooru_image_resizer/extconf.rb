#!/bin/env ruby

require 'mkmf'

dir_config("gd")
CONFIG['CC'] = "g++"

have_header("gd.h")

have_library("gd")
have_library("jpeg")
have_library("png")

have_func("gdImageCreateFromGif", "gd.h")
have_func("gdImageJpeg", "gd.h")

with_cflags("-O2 -fno-exceptions -Wall") {true}
#with_cflags("-O0 -g -fno-exceptions -Wall") {true}

create_makefile("danbooru_image_resizer")
