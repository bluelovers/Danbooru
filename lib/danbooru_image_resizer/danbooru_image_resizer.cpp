#include <ruby.h>
#include <stdio.h>
#include <string.h>

#include "PNGReader.h"
#include "GIFReader.h"
#include "JPEGReader.h"
#include "Resize.h"

static VALUE danbooru_module;

static VALUE danbooru_resize_image(VALUE module, VALUE file_ext_val, VALUE read_path_val, VALUE write_path_val, VALUE output_width_val, VALUE output_height_val, VALUE output_quality_val)
{
	const char * file_ext = StringValueCStr(file_ext_val);
	const char * read_path = StringValueCStr(read_path_val);
	const char * write_path = StringValueCStr(write_path_val);
	int output_width = NUM2INT(output_width_val);
	int output_height = NUM2INT(output_height_val);
	int output_quality = NUM2INT(output_quality_val);

	FILE *read_file = fopen(read_path, "rb");
	if(read_file == NULL)
		rb_raise(rb_eIOError, "can't open %s\n", read_path);

	FILE *write_file = fopen(write_path, "wb");
	if(write_file == NULL)
	{
		fclose(read_file);
		rb_raise(rb_eIOError, "can't open %s\n", write_path);
	}

	bool ret = false;
	char error[1024];
	JPEGCompressor *Compressor = NULL;
	Resizer *resizer = NULL;
	Reader *Reader = NULL;

	if (!strncmp(file_ext, "jpg", 3) || !strncmp(file_ext, "jpeg", 4))
		Reader = new JPEG;
	else if (!strncmp(file_ext, "gif", 3))
		Reader = new GIF;
	else if (!strncmp(file_ext, "png", 3))
		Reader = new PNG;
	else
	{
		strncpy(error, "unknown filetype", 1024);
		goto cleanup;
	}

	Compressor = new JPEGCompressor(write_file);
	if(Compressor == NULL)
	{
		strncpy(error, "out of memory", 1024);
		goto cleanup;
	}

	resizer = new Resizer(Compressor);
	if(resizer == NULL || Reader == NULL)
	{
		strncpy(error, "out of memory", 1024);
		goto cleanup;
	}

	resizer->SetDest(output_width, output_height, output_quality);
	ret = Reader->Read(read_file, resizer, error);

cleanup:
	delete Reader;
	delete resizer;
	delete Compressor;

	fclose(read_file);
	fclose(write_file);

	if(!ret)
		rb_raise(rb_eException, "%s", error);

	return INT2FIX(0);
}

extern "C" void Init_danbooru_image_resizer() {
  danbooru_module = rb_define_module("Danbooru");
  rb_define_module_function(danbooru_module, "resize_image", (VALUE(*)(...))danbooru_resize_image, 6);
}
