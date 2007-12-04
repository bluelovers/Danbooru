#include <ruby.h>
#include <gd.h>
#include <stdio.h>
#include <string.h>

#define DANBOORU_PREVIEW_SIZE 150

static VALUE danbooru_module;
static FILE * log = NULL;

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
  fprintf(log, "----\n"); fflush(log);
  fprintf(log, "Entering resizer\n"); fflush(log);

  const char * file_ext_cstr = StringValueCStr(file_ext);
  const char * read_path_cstr = StringValueCStr(read_path);
  const char * write_path_cstr = StringValueCStr(write_path);
  fprintf(log, "Casted VALUEs to cstrings\n"); fflush(log);

  if (file_ext_cstr == NULL || read_path_cstr == NULL || write_path_cstr == NULL) {
    return INT2FIX(1);
  }
  fprintf(log, "Checked to see if cstrings were null\n"); fflush(log);
  fprintf(log, "file_ext=%s read_path=%s write_path=%s\n", file_ext_cstr, read_path_cstr, write_path_cstr); fflush(log);
  
  FILE * read_file = fopen(read_path_cstr, "rb");
  
  if (read_file == NULL) {
    return INT2FIX(2);
  }
  fprintf(log, "Opened read file\n"); fflush(log);
  
  FILE * write_file = fopen(write_path_cstr, "wb");
  
  if (write_file == NULL) {
    fclose(read_file);
    return INT2FIX(3);
  }
  fprintf(log, "Opened write file\n"); fflush(log);
  
  gdImagePtr img = NULL;
  
  if (!strcmp(file_ext_cstr, "jpg") || !strcmp(file_ext_cstr, "jpeg")) {
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
  fprintf(log, "Loaded read file\n"); fflush(log);

  size_t width = img->sx;
	size_t height = img->sy;
	size_t max = (width > height) ? width : height;
	double scale = (max < DANBOORU_PREVIEW_SIZE) ? 1 : (double)DANBOORU_PREVIEW_SIZE / (double)max;
	width = width * scale;
	height = height * scale;

	gdImagePtr preview = gdImageCreateTrueColor(width, height);
  fprintf(log, "Generated preview\n"); fflush(log);

  if (preview == NULL) {
    gdImageDestroy(img);
    fclose(read_file);
    fclose(write_file);
    return INT2FIX(5);
  }

	gdImageFill(preview, 0, 0, gdTrueColor(255, 255, 255));
  fprintf(log, "Filled preview\n"); fflush(log);

	gdImageCopyResampled(preview, img, 0, 0, 0, 0, width, height, img->sx, img->sy);
  fprintf(log, "Resized preview\n"); fflush(log);

	gdImageJpeg(preview, write_file, 95);
  fprintf(log, "Wrote preview to file\n"); fflush(log);

	gdImageDestroy(img);
	gdImageDestroy(preview);
	fclose(read_file);
	fclose(write_file);
  fprintf(log, "Cleaned up\n"); fflush(log);
 
  return INT2FIX(0);
}

void Init_danbooru_image_resizer() {
  log = fopen("/var/www/sites/miezaru/log/resizer.log", "a");
  danbooru_module = rb_define_module("Danbooru");
  rb_define_module_function(danbooru_module, "resize_image", danbooru_resize_image, 3);
}
