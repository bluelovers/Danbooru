#!/bin/env ruby

require 'mkmf'

have_header("gd.h")

have_library("gd", "gdImageCreateFromJpeg", "gd.h")
have_library("gd", "gdImageCreateFromGif", "gd.h")
have_library("gd", "gdImageCreateFromPng", "gd.h")
have_library("gd", "gdImageDestroy", "gd.h")
have_library("gd", "gdImageCreateTrueColor", "gd.h")
have_library("gd", "gdImageCopyResampled", "gd.h")
have_library("gd", "gdImageJpeg", "gd.h")

create_makefile("danbooru_image_resizer")
