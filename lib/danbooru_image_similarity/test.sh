#!/bin/bash

#gcc -fno-common -Wall -ggdb -DHAVE_GLIB_H -DHAVE_GD_H -DHAVE_GDIMAGECREATEFROMJPEG -DHAVE_GDIMAGECREATEFROMGIF -DHAVE_GDIMAGECREATEFROMPNG -DHAVE_GDIMAGEJPEG -I/usr/local/lib/glib/include -I/usr/local/include/glib-1.2 danbooru_image_similarity.c gheap.c -lglib -lgd -o test

gcc -fno-common -Wall -O2 -DHAVE_GLIB_H -DHAVE_GD_H -DHAVE_GDIMAGECREATEFROMJPEG -DHAVE_GDIMAGECREATEFROMGIF -DHAVE_GDIMAGECREATEFROMPNG -DHAVE_GDIMAGEJPEG -I/usr/local/lib/glib-2.0/include -I/usr/local/include/glib-2.0 -c danbooru_image_similarity.c -o danbooru_image_similarity.o
gcc -fno-common -Wall -O2 -DHAVE_GLIB_H -DHAVE_GD_H -DHAVE_GDIMAGECREATEFROMJPEG -DHAVE_GDIMAGECREATEFROMGIF -DHAVE_GDIMAGECREATEFROMPNG -DHAVE_GDIMAGEJPEG -I/usr/local/lib/glib-2.0/include -I/usr/local/include/glib-2.0 -c gheap.c -o gheap.o
gcc -L/usr/local/lib -lglib-2.0 -lgd -fno-common -Wall -ggdb gheap.o danbooru_image_similarity.o -o test
