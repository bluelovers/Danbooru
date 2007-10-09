#include <ruby.h>
#include <gd.h>
#include <stdio.h>
#include <string.h>

#define DANBOORU_PREVIEW_SIZE 150

static VALUE danbooru_module;

/* PRE-CONDITIONS:
 * 1) file_ext is one of four possible case-sensitive strings: jpg, jpeg, 
 *    gif, or png.
 * 2) read_path is an absolute file path readable by Ruby, pointing to an 
 *    image of one of the above three mime types.
 * 3) write_path is an absolute file path writable by Ruby, where the
 *    generated preview file will be written.
 *
 * POST-CONDITIONS:
 * 1) If no errors were encountered, a JPEG image will be written to the 
 *    write_path. This image will represent a thumbnail view of the file 
 *    given in read_path. A value of 0 will be returned.
 * 2) If any of the parameters could not be converted into a String type,
 *    a value of 1 will be returned.
 * 3) If the image file could not be opened, a value of 2 will be
 *    returned.
 * 4) If the preview file could not be opened, a value of 3 will be
 *    returned.
 * 5) If GD could not open the image file, a value of 4 will be returned.
 */

static VALUE danbooru_resize_image(VALUE module, VALUE file_ext, VALUE read_path, VALUE write_path) {
  VALUE file_ext_string = StringValue(file_ext);
  VALUE read_path_string = StringValue(read_path);
  VALUE write_path_string = StringValue(write_path);
  
  const char * file_ext_cstr = RSTRING(file_ext_string)->ptr;
  const char * read_path_cstr = RSTRING(read_path_string)->ptr;
  const char * write_path_cstr = RSTRING(write_path_string)->ptr;

  if (file_ext_cstr == NULL || read_path_cstr == NULL || write_path_cstr == NULL) {
    return INT2FIX(1);
  }
  
  FILE * read_file = fopen(read_path_cstr, "rb");
  
  if (read_file == NULL) {
    return INT2FIX(2);
  }
  
  FILE * write_file = fopen(write_path_cstr, "wb");
  
  if (write_file == NULL) {
    fclose(read_file);
    return INT2FIX(3);
  }
  
  gdImagePtr img = NULL;
  
  if (!strcmp(file_ext_cstr, "jpg")) {
    img = gdImageCreateFromJpeg(read_file);
  } else if (!strcmp(file_ext_cstr, "gif")) {
    img = gdImageCreateFromGif(read_file);
  } else if (!strcmp(file_ext_cstr, "png")) {
    img = gdImageCreateFromPng(read_file);
  }

  if (img == NULL) {
    fclose(read_file);
    fclose(write_file);
    return INT2FIX(4);
  }

  size_t width = img->sx;
	size_t height = img->sy;
	size_t max = (width > height) ? width : height;
	double scale = (max < DANBOORU_PREVIEW_SIZE) ? 1 : (double)DANBOORU_PREVIEW_SIZE / (double)max;
	width = width * scale;
	height = height * scale;

	gdImagePtr preview = gdImageCreateTrueColor(width, height);
	gdImageCopyResampled(preview, img, 0, 0, 0, 0, width, height, img->sx, img->sy);
	gdImageJpeg(preview, write_file, 95);
	gdImageDestroy(img);
	gdImageDestroy(preview);
	fclose(read_file);
	fclose(write_file);
  return INT2FIX(0);
}

void Init_danbooru_image_resizer() {
  danbooru_module = rb_define_module("Danbooru");
  rb_define_module_function(danbooru_module, "resize_image", danbooru_resize_image, 3);
}
