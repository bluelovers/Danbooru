/*#include <gd.h>*/
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "gheap.h"

/* This is a naive implementation of the fast multiresolution image
 * querying algorithm explained by Jacobs, Finkelstein, and Salesin
 * in their paper of the same name.
 */

#define DANBOORU_SQRT2 1.4142135623731
#define DANBOORU_M 8

static gint compare_floats(gconstpointer a, gconstpointer b) {
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
  int len;
  float * data;
};

static struct danbooru_matrix * danbooru_matrix_create() {
  struct danbooru_matrix * m = malloc(sizeof(struct danbooru_matrix));
  m->len = 0;
  m->data = NULL;
  return m;
}

static void danbooru_matrix_destroy(struct danbooru_matrix * m) {
  free(m->data);
  m->len = 0;
  m->data = NULL;
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
static void danbooru_matrix_decompose(float * a, int n) {
  int i;
  float * ap;
  
  for (i=0; i<n; ++i) {
    ap = a + (n * i);
    danbooru_array_decompose(ap, n);
  }
  
  danbooru_matrix_transpose(a, n);
  
  for (i=0; i<n; ++i) {
    ap = a + (n * i);
    danbooru_array_decompose(ap, n);
  }
  
  danbooru_matrix_transpose(a, n);
}

static struct danbooru_matrix * danbooru_matrix_normalize(int * a, int width, int height) {
  struct danbooru_matrix * m = danbooru_matrix_create();
  int max = (width > height) ? width : height;

  m->len = 1;
  
  while (m->len < max) {
    m->len = m->len * 2;
  }
  
  m->data = malloc(sizeof(float) * m->len * m->len);
  int x, y;
  
  for (y=0; y<m->len; ++y) {
    for (x=0; x<m->len; ++x) {
      if (x >= width || y >= height) {
        m->data[(y * m->len) + x] = 0;
      } else {
        m->data[(y * m->len) + x] = (float)(a[(y * height) + x]) / 255.0;
      }
    }
  }
  
  return m;
}

static float * danbooru_matrix_find_largest_positive_coefficients(struct danbooru_matrix * m) {
  GHeap * heap = g_heap_new(m->len * m->len, compare_floats);
  g_heap_destroy(heap);
  return NULL;
}

static float * danbooru_matrix_find_largest_negative_coefficients(struct danbooru_matrix * m) {
  return NULL;
}

int main() {
  int i;
  int size = 9;
  int x[] = {0, 128, 255, 0, 128, 255, 255, 100, 120};

  struct danbooru_matrix * z = danbooru_matrix_normalize(x, 3, 3);
  printf("n=%d\n", z->len);

  for (i=0; i<16; i+=4) {
    printf("%f %f %f %f\n", z->data[i], z->data[i+1], z->data[i+2], z->data[i+3]);
  }
  
  danbooru_matrix_destroy(z);
  free(z);
  
  return 0;
}
