#include <gd.h>
#include <stdio.h>
#include <string.h>

/*
 * Usage:
 * resizer /path/to/input /path/to/output
 *
 * Supported Image Types:
 * - JPEG
 * - GIF
 * - PNG
 * - WBMP
 *
 * Returns:
 * - 0: Success
 * - 1: Unknown file extension
 * - 2: Error opening input file
 * - 3: Error opening output file
 * - 4: Error reading input file
 *
 * Assumptions:
 * - This program guesses the image type based on the file
 *   extension. If the extension is incorrect, this program
 *   will fail.
 *
 */

#define DIMENSION 150

int main(int argc, char * argv[]) {
	const char * in = argv[1];
	const char * out = argv[2];
	const char * ext = strrchr(in, '.');
	FILE * in_file = fopen(in, "rb");
	FILE * out_file = fopen(out, "wb");

	if (NULL == in_file) {
		return 2;
	}

	if (NULL == out_file) {
		fclose(in_file);
		return 3;
	}

	gdImagePtr img = NULL;

	if (!strcmp(ext, ".jpg") || !strcmp(ext, ".jpeg")) {
		img = gdImageCreateFromJpeg(in_file);
	} else if (!strcmp(ext, ".gif")) {
		img = gdImageCreateFromGif(in_file);
	} else if (!strcmp(ext, ".png")) {
		img = gdImageCreateFromPng(in_file);
	} else if (!strcmp(ext, ".bmp")) {
		img = gdImageCreateFromWBMP(in_file);
	} else {
		return 1;
	}

	if (NULL == img) {
		return 4;
	}

	size_t width = img->sx;
	size_t height = img->sy;
	size_t max = (width > height) ? width : height;
	double scale = (max < DIMENSION) ? 1 : (double)DIMENSION / (double)max;
	width = width * scale;
	height = height * scale;

	gdImagePtr preview = gdImageCreateTrueColor(width, height);
	gdImageCopyResampled(preview, img, 0, 0, 0, 0, width, height, img->sx, img->sy);
	gdImageJpeg(preview, out_file, 95);

	gdImageDestroy(img);
	gdImageDestroy(preview);
	fclose(in_file);
	fclose(out_file);

	return 0;
}
