#!/bin/bash

gcc -fno-common -O2 -DHAVE_GLIB_H -DHAVE_GD_H -DHAVE_GDIMAGECREATEFROMJPEG -DHAVE_GDIMAGECREATEFROMGIF -DHAVE_GDIMAGECREATEFROMPNG -DHAVE_GDIMAGEJPEG -I/usr/local/lib/glib/include -I/usr/local/include/glib-1.2 danbooru_image_similarity.c gheap.c -lglib -lgd -o test
