#include <gd.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "gheap.h"

/* This is a naive implementation of the fast multiresolution image
 * querying algorithm explained by Jacobs et al.
 */

#define DANBOORU_SQRT2 1.4142135623731
#define DANBOORU_M 40
#define DANBOORU_BIN_SIZE 8

static float weights = {1, 1, 1, 1, 1, 1};

static gint compare_floats(gconstpointer a, gconstpointer b) {
  float fa = *((float *)a);
  float fb = *((float *)b);
  
  if (fa > fb) {
    return -1;
  } else if (fa == fb) {
    return 0;
  } 

  return 1;
}

static gint reverse_compare_floats(gconstpointer a, gconstpointer b) {
  float fa = *((float *)a);
  float fb = *((float *)b);
  
  if (fa > fb) {
    return 1;
  } else if (fa == fb) {
    return 0;
  } 

  return -1;
}

struct danbooru_matrix {
  int n;
  float * data;
};

static struct danbooru_matrix * danbooru_matrix_create(int n) {
  struct danbooru_matrix * m = malloc(sizeof(struct danbooru_matrix));
  m->n = n;
  m->data = malloc(sizeof(float) * n * n);
  return m;
}

static void danbooru_matrix_destroy(struct danbooru_matrix * m) {
  free(m->data);
  free(m);
}

/* PRE:
 * 1) <a> points to an array of floating point numbers. Each number should be
 *    in the range of [0, 1].
 * 2) <size> is a power of 2.
 *
 * POST:
 * 1) <a> will be decomposed.
 */
static void danbooru_array_decompose(float * a, int size) {
  int i;
  
  for (i=0; i<size; ++i) {
    a[i] = a[i] / DANBOORU_SQRT2;
  }
  
  float * ap = malloc(sizeof(float) * size);
  
  while (size > 1) {
    size = size / 2;
    
    for (i=0; i<=size-1; ++i) {
      ap[i] = (a[2 * i] + a[1 + (2 * i)]) / DANBOORU_SQRT2;
      ap[size + i] = (a[2 * i] - a[1 + (2 * i)]) / DANBOORU_SQRT2;
    }
    
    for (i=0; i<size; ++i) {
      a[i] = ap[i];
    }
  }
  
  free(ap);
}

/* PRE:
 * 1) <a> points to an array of floating point numbers. This array is a linear 
 *    representation of a square matrix (that is, a matrix with the same number 
 *    of rows as columns).
 * 2) <n> is the number of rows or columns of <a>.
 *
 * POST:
 * 1) <a> will be transposed.
 */
static void danbooru_matrix_transpose(float * a, int n) {
  int size = n * n;
  float * ap = malloc(sizeof(float) * size);
  int i, x, y;
  
  for (y=0; y<n; ++y) {
    for (x=0; x<n; ++x) {
      ap[(x * n) + y] = a[(y * n) + x];
    }
  }
  
  for (i=0; i<size; ++i) {
    a[i] = ap[i];
  }
  
  free(ap);
}

/* PRE:
 * 1) <a> points to an array of floating point numbers. Each number is in the
 *    range [0, 1]. This array is a linear representation of a square matrix.
 * 2) <n> is the number of rows or columns of <a>.
 *
 * POST:
 * 1) <a> will be decomposed.
 */
static void danbooru_matrix_decompose(struct danbooru_matrix * m) {
  int i;
  int n = m->n;
  float * ap;
  
  for (i=0; i<n; ++i) {
    ap = m->data + (n * i);
    danbooru_array_decompose(ap, n);
  }
  
  danbooru_matrix_transpose(m->data, n);
  
  for (i=0; i<n; ++i) {
    ap = m->data + (n * i);
    danbooru_array_decompose(ap, n);
  }
  
  danbooru_matrix_transpose(m->data, n);
}

/* PRE:
 * 1) <m> is a matrix that has at least DANBOORU_M elements.
 *
 * POST:
 * 1) Returns an array of floating point numbers of size DANBOORU_M containing
 *    the DANBOORU_M largest positive coefficients found in <m>.
 * 2) The caller is responsible for deallocating the returned array.
 */
static float * danbooru_matrix_find_largest_positive_coefficients(struct danbooru_matrix * m) {
  GHeap * heap = g_heap_new(m->n * m->n, compare_floats);
  int i, x, y;
  
  for (y=0; y<m->n; ++y) {
    for (x=0; x<m->n; ++x) {
      if (y != 0 || x != 0 && m->data[(y * m->n) + x] != 0) {
        g_heap_insert(heap, (gpointer)(&(m->data[(y * m->n) + x])));
      }
    }
  }
  
  float * largest = malloc(sizeof(float) * DANBOORU_M);
  for (i=0; i<DANBOORU_M; ++i) {
    largest[i] = *((float *)g_heap_remove(heap));
  }

  g_heap_destroy(heap);
    
  return largest;
}

/* PRE:
 * 1) <m> is a matrix containing at least DANBOORU_M elements.
 *
 * POST:
 * 1) Returns an array of floating point numbers of size DANBOORU_M containing
 *    the DANBOORU_M largest negative coefficients found in <m>.
 * 2) The caller is responsible for deallocating the returned array.
 */
static float * danbooru_matrix_find_largest_negative_coefficients(struct danbooru_matrix * m) {
  GHeap * heap = g_heap_new(m->n * m->n, reverse_compare_floats);
  int i, j;
  
  for (i=0; i<m->n; ++i) {
    if (i == 0) {
      j = 1;
    } else {
      j = 0;
    }
    
    for (; j<m->n; ++j) {
      g_heap_insert(heap, (gpointer)(&(m->data[(i * m->n) + j])));
    }
  }
  
  float * largest = malloc(sizeof(float) * DANBOORU_M);
  for (i=0; i<DANBOORU_M; ++i) {
    largest[i] = *((float *)g_heap_remove(heap));
  }

  g_heap_destroy(heap);
  
  return largest;
}

struct danbooru_image {
  int n;
  struct danbooru_matrix * r;
  struct danbooru_matrix * g;
  struct danbooru_matrix * b;
};

static struct danbooru_image * danbooru_image_create(int w, int h) {
  int max = (w > h) ? w : h;
  int n = 1;
  
  while (n < max) {
    n = n * 2;
  }
  
  struct danbooru_image * img = malloc(sizeof(struct danbooru_image));
  img->n = n;
  img->r = danbooru_matrix_create(n);
  img->g = danbooru_matrix_create(n);
  img->b = danbooru_matrix_create(n);
  
  return img;
}

static void danbooru_image_destroy(struct danbooru_image * img) {
  danbooru_matrix_destroy(img->r);
  danbooru_matrix_destroy(img->g);
  danbooru_matrix_destroy(img->b);
  free(img);
}

static void danbooru_image_print(struct danbooru_image * img) {
  int x, y;
  int n = img->n;
  
  printf("Red\n");
  for (y=0; y<5; ++y) {
    for (x=0; x<5; ++x) {
      printf("%f ", img->r->data[(y * n) + x]);
    }
    printf("\n");
  }

  printf("\n\nGreen\n");
  for (y=0; y<5; ++y) {
    for (x=0; x<5; ++x) {
      printf("%f ", img->g->data[(y * n) + x]);
    }
    printf("\n");
  }

  printf("\n\nBlue\n");
  for (y=0; y<5; ++y) {
    for (x=0; x<5; ++x) {
      printf("%f ", img->b->data[(y * n) + x]);
    }
    printf("\n");
  }
}

static struct danbooru_image * danbooru_image_load(const char * ext, const char * filename) {
  gdImagePtr img = NULL;
  FILE * f = fopen(filename, "rb");
  
  if (f == NULL) {
    return NULL;
  }
  
  if (!strcmp(ext, "jpg")) {
    img = gdImageCreateFromJpeg(f);
  } else if (!strcmp(ext, "gif")) {
    img = gdImageCreateFromGif(f);
  } else if (!strcmp(ext, "png")) {
    img = gdImageCreateFromPng(f);
  }
  
  if (img == NULL) {
    return NULL;
  }
  
  int w = gdImageSX(img);
  int h = gdImageSY(img);
  struct danbooru_image * db_img = danbooru_image_create(w, h);
  int n = db_img->n;
  int x, y;
  
  for (y=0; y<n; ++y) {
    for (x=0; x<n; ++x) {
      if (x < n && y < n) {
        db_img->r->data[(y * n) + x] = ((float)gdImageRed(img, gdImageGetPixel(img, x, y))) / 255.0;
        db_img->g->data[(y * n) + x] = ((float)gdImageGreen(img, gdImageGetPixel(img, x, y))) / 255.0;
        db_img->b->data[(y * n) + x] = ((float)gdImageBlue(img, gdImageGetPixel(img, x, y))) / 255.0;
      } else {
        db_img->r->data[(y * n) + x] = 0;
        db_img->g->data[(y * n) + x] = 0;
        db_img->b->data[(y * n) + x] = 0;
      }
    }
  }
  
  fclose(f);
  gdImageDestroy(img);
  
  return db_img;
}

static void danbooru_image_decompose(struct danbooru_image * img) {
  danbooru_matrix_decompose(img->r);
  danbooru_matrix_decompose(img->g);
  danbooru_matrix_decompose(img->b);
}

static int rank_query() {
  // For the given combination of weights, m, and bin size, find the ranking
  // between images O and T.
}

int main() {
  struct danbooru_image * img = danbooru_image_load("jpg", "ff762c08286035b25202f78485f13725.jpg");
  danbooru_image_decompose(img);

  float * lrpos = danbooru_matrix_find_largest_positive_coefficients(img->r);
  float * lgpos = danbooru_matrix_find_largest_positive_coefficients(img->g);
  float * lbpos = danbooru_matrix_find_largest_positive_coefficients(img->b);
  
  int i;
  for (i=0; i<DANBOORU_M; ++i) {
    printf("R%d: %f\n", i, lrpos[i]);
  }

  for (i=0; i<DANBOORU_M; ++i) {
    printf("G%d: %f\n", i, lgpos[i]);
  }

  for (i=0; i<DANBOORU_M; ++i) {
    printf("G%d: %f\n", i, lgpos[i]);
  }
  
  free(lrpos);
  free(lgpos);
  free(lbpos);
    
  danbooru_image_destroy(img);
  
  return 0;
}
