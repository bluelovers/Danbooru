#include <gd.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>
#include "gheap.h"

/* This is a naive implementation of the fast multiresolution image
 * querying algorithm explained by Jacobs et al.
 */

#define DANBOORU_SQRT2 1.4142135623731
#define DANBOORU_M 40
#define DANBOORU_BIN_SIZE 8
#define DANBOORU_FLOAT_SCALE 255

struct coefficient {
  int x;
  int y;
  float v;
};

static float g_weights[DANBOORU_BIN_SIZE];

static gint compare_coefficients(gconstpointer a, gconstpointer b) {
  struct coefficient * ca = (struct coefficient *)a;
  struct coefficient * cb = (struct coefficient *)b;
  
  if (ca->v > cb->v) {
    return -1;
  } else if (ca->v == cb->v) {
    return 0;
  } 

  return 1;
}

static gint reverse_compare_coefficients(gconstpointer a, gconstpointer b) {
  struct coefficient * ca = (struct coefficient *)a;
  struct coefficient * cb = (struct coefficient *)b;
  
  if (ca->v > cb->v) {
    return 1;
  } else if (ca->v == cb->v) {
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
    a[i] = a[i] / sqrt((float)size);
  }
  
  float * ap = malloc(sizeof(float) * size);
  
  while (size > 1) {
    size = size / 2;
    
    for (i=0; i<size; ++i) {
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
 * 2) <positive> is 1 if the largest positive coefficients are desired,
 *    0 otherwise.
 *
 * POST:
 * 1) Returns an array of size DANBOORU_M containing the DANBOORU_M 
 *    largest positive coefficients found in <m>.
 * 2) The caller is responsible for deallocating the returned array.
 */
static struct coefficient * danbooru_matrix_find_largest_coefficients(struct danbooru_matrix * m, int positive) {
  GHeap * heap = NULL;
  if (positive) {
    heap = g_heap_new(m->n * m->n, compare_coefficients);
  } else {
    heap = g_heap_new(m->n * m->n, reverse_compare_coefficients);
  }
  struct coefficient * coefficients = malloc(sizeof(struct coefficient) * m->n * m->n);
  int i, x, y;

  for (i=0, y=0; y<m->n; ++y) {
    for (x=0; x<m->n; ++x) {
      if ((y != 0 || x != 0) && m->data[(y * m->n) + x] != 0) {
        coefficients[i].x = x;
        coefficients[i].y = y;
        coefficients[i].v = m->data[(y * m->n) + x];
        g_heap_insert(heap, (gpointer)(coefficients + i));
        i += 1;
      }
    }
  }
  
  struct coefficient * largest = malloc(sizeof(struct coefficient) * DANBOORU_M);
  for (i=0; i<DANBOORU_M; ++i) {
    struct coefficient * c = (struct coefficient *)g_heap_remove(heap);
    largest[i].x = c->x;
    largest[i].y = c->y;
    largest[i].v = c->v;
  }

  g_heap_destroy(heap);
  free(coefficients);
    
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

static int select_bin(int x, int y) {
  int max = (x > y) ? x : y;
  return (max > 5) ? 5 : max;
}

int main() {
  struct danbooru_image * img = danbooru_image_load("jpg", "24ad95fd3b39c2631d4976977d4da1b8.jpg");
  danbooru_image_decompose(img);

  struct coefficient * lrpos = danbooru_matrix_find_largest_coefficients(img->r, 1);
  struct coefficient * lgpos = danbooru_matrix_find_largest_coefficients(img->g, 1);
  struct coefficient * lbpos = danbooru_matrix_find_largest_coefficients(img->b, 1);
  
  int i;
  for (i=0; i<DANBOORU_M; ++i) {
    printf("insert into coefficients (post_id, color, bin, v, x, y) values (1, 'r', %d, %d, %d, %d)\n", select_bin(lrpos[i].x, lrpos[i].y), (int)round(DANBOORU_FLOAT_SCALE * lrpos[i].v), lrpos[i].x, lrpos[i].y);
  }

  for (i=0; i<DANBOORU_M; ++i) {
    printf("insert into coefficients (post_id, color, bin, v, x, y) values (1, 'g', %d, %d, %d, %d)\n", select_bin(lgpos[i].x, lgpos[i].y), (int)round(DANBOORU_FLOAT_SCALE * lgpos[i].v), lgpos[i].x, lgpos[i].y);
  }

  for (i=0; i<DANBOORU_M; ++i) {
    printf("insert into coefficients (post_id, color, bin, v, x, y) values (1, 'b', %d, %d, %d, %d)\n", select_bin(lbpos[i].x, lbpos[i].y), (int)round(DANBOORU_FLOAT_SCALE * lbpos[i].v), lbpos[i].x, lbpos[i].y);
  }
  
  free(lrpos);
  free(lgpos);
  free(lbpos);
    
  danbooru_image_destroy(img);
  
  return 0;
}
