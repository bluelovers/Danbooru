#!/bin/env ruby

require 'mkmf'

CONFIG['CC'] = "gcc"

dir_config("kakasi")

have_header("libkakasi.h")

have_library("kakasi")

have_func("kakasi_close_kanwadict", "libkakasi.h")
have_func("kakasi_getopt_argv", "libkakasi.h")
have_func("kakasi_do", "libkakasi.h")

with_cflags("-O2 -fno-exceptions -Wall") {true}

create_makefile("kakasi")
