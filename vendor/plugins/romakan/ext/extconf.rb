#!/bin/env ruby

require 'mkmf'

CONFIG['CC'] = "gcc"

dir_config("chasen")

have_header("chasen.h")

have_library("chasen")

have_func("chasen_getopt_argv", ["stdlib.h", "stdio.h", "chasen.h"])
have_func("chasen_sparse_tostr", ["stdlib.h", "stdio.h", "chasen.h"])

with_cflags("-O2 -fno-exceptions -Wall") {true}

create_makefile("romakan_kanji_to_kana")
