#include <gd.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define SQRT_OF_TWO 1.4142135623731

void decompose_array(float * array, int size) {
  int i;
  for (i=0; i<size; ++i) {
    array[i] = array[i] / SQRT_OF_TWO;
  }
}

int main() {
  gdImagePtr img = NULL;
  FILE * file = fopen("test.jpg", "rb");
	img = gdImageCreateFromGif(file);
  int c = 0;
  int x = 0;
  
  for (x=0; x<gdImageSX(img); ++x) {
    c = gdImageGetPixel(img, x, 0);
    
    if (gdImageGreen(img, c) > 200) {
      printf("%d\n", gdImageGreen(img, c));
    }
  }
  
  fclose(file);
  
  return 0;
}