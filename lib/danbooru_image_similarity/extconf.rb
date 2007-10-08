#!/bin/env ruby

require 'mkmf'

dir_config("glib")
dir_config('glibconfig')
dir_config("gd")

have_header("glib.h")
have_header("gd.h")

have_library("glib")
have_library("gd")

have_func("gdImageCreateFromJpeg", "gd.h")
have_func("gdImageCreateFromGif", "gd.h")
have_func("gdImageCreateFromPng", "gd.h")
have_func("gdImageJpeg", "gd.h")

with_cflags("-O2") {true}

create_makefile("danbooru_image_similarity")
