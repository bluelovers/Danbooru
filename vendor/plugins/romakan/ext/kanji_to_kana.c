#include <stdio.h>
#include <stdlib.h>
#include <chasen.h>
#include <ruby.h>

static VALUE romakan_module;

static VALUE romakan_kanji_to_kana(VALUE module, VALUE kanji_string) {
  char * c_kanji_string = StringValueCStr(kanji_string);
  const char * c_kana_string = chasen_sparse_tostr(c_kanji_string);
  return rb_str_new2(c_kana_string);
}

void Init_romakan_kanji_to_kana() {
  char * options[] = {"chasen", "-i", "w", "-F", "%?U/%m/%y/ "};
  chasen_getopt_argv(options, stderr);
  
  romakan_module = rb_define_module("Romakan");
  rb_define_module_function(romakan_module, "kanji_to_kana", romakan_kanji_to_kana, 1);
}
