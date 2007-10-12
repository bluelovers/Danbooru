#include <gd.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>
#include "gheap.h"

/* This is a naive implementation of the fast multiresolution image
 * querying algorithm explained by Jacobs et al.
 */

#define DANBOORU_M 40
#define DANBOORU_BIN_SIZE 5
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

static G_GNUC_MALLOC struct danbooru_matrix * danbooru_matrix_create(int n) {
  struct danbooru_matrix * m = g_try_new(struct danbooru_matrix, 1);
  
  if (m == NULL) {
    return NULL;
  }
  
  m->n = n;
  m->data = g_try_new(float, n * n);
  
  if (m->data == NULL) {
    g_free(m);
    return NULL;
  }
  
  return m;
}

static void danbooru_matrix_destroy(struct danbooru_matrix * m) {
  if (m != NULL) {
    g_free(m->data);
    g_free(m);
  }
}

/* PRE:
 * 1) <a> points to an array of floating point numbers. Each number should be
 *    in the range of [0, 1].
 * 2) <size> is a power of 2.
 *
 * POST:
 * 1) <a> will be decomposed.
 * 2) 0 is returned if no errors were encountered, 1 otherwise.
 */
static int danbooru_array_decompose(float * a, int size) {
  int i;
  
  for (i=0; i<size; ++i) {
    a[i] = a[i] / sqrt((float)size);
  }
  
  float * ap = g_try_new(float, size);
  
  if (ap == NULL) {
    return 1;
  }
  
  while (size > 1) {
    size = size / 2;
    
    for (i=0; i<size; ++i) {
      ap[i] = (a[2 * i] + a[1 + (2 * i)]) / G_SQRT2;
      ap[size + i] = (a[2 * i] - a[1 + (2 * i)]) / G_SQRT2;
    }
    
    for (i=0; i<size; ++i) {
      a[i] = ap[i];
    }
  }
  
  g_free(ap);
  return 0;
}

/* PRE:
 * 1) <a> points to an array of floating point numbers. This array is a linear 
 *    representation of a square matrix (that is, a matrix with the same number 
 *    of rows as columns).
 * 2) <n> is the number of rows or columns of <a>.
 *
 * POST:
 * 1) <a> will be transposed.
 * 2) 0 is returned if no errors were encountered, 1 otherwise.
 */
static int danbooru_matrix_transpose(float * a, int n) {
  int size = n * n;
  float * ap = g_try_new(float, size);
  
  if (ap == NULL) {
    return 1;
  }
  
  int i, x, y;
  
  for (y=0; y<n; ++y) {
    for (x=0; x<n; ++x) {
      ap[(x * n) + y] = a[(y * n) + x];
    }
  }
  
  for (i=0; i<size; ++i) {
    a[i] = ap[i];
  }
  
  g_free(ap);
  return 0;
}

/* PRE:
 * 1) <a> points to an array of floating point numbers. Each number is in the
 *    range [0, 1]. This array is a linear representation of a square matrix.
 * 2) <n> is the number of rows or columns of <a>.
 *
 * POST:
 * 1) <a> will be decomposed.
 * 2) 0 is returned if no errors were encountered, 1 otherwise.
 */
static int danbooru_matrix_decompose(struct danbooru_matrix * m) {
  int i;
  int n = m->n;
  float * ap;
  
  for (i=0; i<n; ++i) {
    ap = m->data + (n * i);
    if (danbooru_array_decompose(ap, n) == 1) {
      return 1;
    }
  }
  
  if (danbooru_matrix_transpose(m->data, n) == 1) {
    return 1;
  }
  
  for (i=0; i<n; ++i) {
    ap = m->data + (n * i);
    if (danbooru_array_decompose(ap, n) == 1) {
      return 1;
    }
  }
  
  if (danbooru_matrix_transpose(m->data, n) == 1) {
    return 1;
  }
  
  return 0;
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
static G_GNUC_MALLOC struct coefficient * danbooru_matrix_find_largest_coefficients(struct danbooru_matrix * m, int positive) {
  GHeap * heap = NULL;
  
  if (positive) {
    heap = g_heap_new(m->n * m->n, compare_coefficients);
  } else {
    heap = g_heap_new(m->n * m->n, reverse_compare_coefficients);
  }
  
  if (heap == NULL) {
    return NULL;
  }
  
  struct coefficient * coefficients = g_try_new(struct coefficient, m->n * m->n);
  
  if (coefficients == NULL) {
    g_heap_destroy(heap);
    return NULL;
  }
  
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
  
  int largest_size = MIN(DANBOORU_M, i);
  struct coefficient * largest = g_try_new(struct coefficient, largest_size);
  
  if (largest == NULL) {
    g_heap_destroy(heap);
    g_free(coefficients);
    return NULL;
  }
  
  for (i=0; i<largest_size; ++i) {
    struct coefficient * c = (struct coefficient *)g_heap_remove(heap);
    largest[i].x = c->x;
    largest[i].y = c->y;
    largest[i].v = c->v;
  }

  g_heap_destroy(heap);
  g_free(coefficients);
    
  return largest;
}

struct danbooru_image {
  int n;
  struct danbooru_matrix * r;
  struct danbooru_matrix * g;
  struct danbooru_matrix * b;
};

static G_GNUC_MALLOC struct danbooru_image * danbooru_image_create(int w, int h) {
  int max = MAX(w, h);
  int n = 1;
  
  while (n < max) {
    n = n * 2;
  }
  
  struct danbooru_image * img = g_try_new(struct danbooru_image, 1);
  
  if (img == NULL) {
    return NULL;
  }
  
  img->n = n;
  img->r = danbooru_matrix_create(n);
  img->g = danbooru_matrix_create(n);
  img->b = danbooru_matrix_create(n);

  if (img->r == NULL || img->g == NULL || img->b == NULL) {
    g_free(img->r);
    g_free(img->g);
    g_free(img->b);
    g_free(img);
    return NULL;
  }
  
  return img;
}

static void danbooru_image_destroy(struct danbooru_image * img) {
  danbooru_matrix_destroy(img->r);
  danbooru_matrix_destroy(img->g);
  danbooru_matrix_destroy(img->b);
  g_free(img);
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

static G_GNUC_MALLOC struct danbooru_image * danbooru_image_load(const char * ext, const char * filename) {
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
    fclose(f);
    return NULL;
  }
  
  int w = gdImageSX(img);
  int h = gdImageSY(img);
  struct danbooru_image * db_img = danbooru_image_create(w, h);
  
  if (db_img == NULL) {
    gdImageDestroy(img);
    fclose(f);
    return NULL;
  }
  
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
  
  gdImageDestroy(img);
  fclose(f);
  
  return db_img;
}

static void danbooru_image_decompose(struct danbooru_image * img) {
  danbooru_matrix_decompose(img->r);
  danbooru_matrix_decompose(img->g);
  danbooru_matrix_decompose(img->b);
}

static int danbooru_rank_query() {
  // For the given combination of weights, m, and bin size, find the ranking
  // between images O and T.
  return 0;
}

static int danbooru_select_bin(int x, int y) {
  int max = MAX(x, y);
  return MIN(DANBOORU_BIN_SIZE, max);
}

static int danbooru_normalize_float(float f) {
  return (int)(round(f * DANBOORU_FLOAT_SCALE));
}

static void danbooru_generate_coefficient_sql(FILE * f, const char * filename, const char * ext, int post_id) {
  struct danbooru_image * img = danbooru_image_load(ext, filename);
  
  if (img == NULL) {
    fprintf(stderr, "Error loading %s\n", filename);
    return;
  }
  
  danbooru_image_decompose(img);

  struct coefficient * lrpos = danbooru_matrix_find_largest_coefficients(img->r, 1);
  struct coefficient * lgpos = danbooru_matrix_find_largest_coefficients(img->g, 1);
  struct coefficient * lbpos = danbooru_matrix_find_largest_coefficients(img->b, 1);
  
  int i;
  for (i=0; i<DANBOORU_M; ++i) {
    fprintf(f, "insert into coefficients (post_id, color, bin, v, x, y) values (%d, 'r', %d, %d, %d, %d);\n", post_id, danbooru_select_bin(lrpos[i].x, lrpos[i].y), danbooru_normalize_float(lrpos[i].v), lrpos[i].x, lrpos[i].y);
  }

  for (i=0; i<DANBOORU_M; ++i) {
    fprintf(f, "insert into coefficients (post_id, color, bin, v, x, y) values (%d, 'g', %d, %d, %d, %d);\n", post_id, danbooru_select_bin(lgpos[i].x, lgpos[i].y), danbooru_normalize_float(lgpos[i].v), lgpos[i].x, lgpos[i].y);
  }

  for (i=0; i<DANBOORU_M; ++i) {
    fprintf(f, "insert into coefficients (post_id, color, bin, v, x, y) values (%d, 'b', %d, %d, %d, %d);\n", post_id, danbooru_select_bin(lbpos[i].x, lbpos[i].y), danbooru_normalize_float(lbpos[i].v), lbpos[i].x, lbpos[i].y);
  }
  
  g_free(lrpos);
  g_free(lgpos);
  g_free(lbpos);
    
  danbooru_image_destroy(img);
}

int main() {
  FILE * dump = fopen("coefs.sql", "w");

if (1) {
  danbooru_generate_coefficient_sql(dump, "images/0de7b8829918019e1815cd67ba7caea6.jpg", "jpg", 133318);
  danbooru_generate_coefficient_sql(dump, "images/4ee47f72143ab619b020fd246a92d00d.jpg", "jpg", 11543);
  danbooru_generate_coefficient_sql(dump, "images/c732aa2d5d8a123bfdd532052ad21d49.jpg", "jpg", 26145);
  danbooru_generate_coefficient_sql(dump, "images/864475e40524d3c9187312737733efa7.jpg", "jpg", 8839);
  danbooru_generate_coefficient_sql(dump, "images/a965699202dea749fd17b88ed4b0006a.jpg", "jpg", 116164);
  danbooru_generate_coefficient_sql(dump, "images/f3e1a773883edb78e1fb6ae3dcbc3555.gif", "gif", 98703);
  danbooru_generate_coefficient_sql(dump, "images/b9861b26880373958f9f49c154112f19.jpg", "jpg", 44964);
  danbooru_generate_coefficient_sql(dump, "images/04aff328853ee0225746a0b570078268.jpg", "jpg", 13028);
  danbooru_generate_coefficient_sql(dump, "images/44492b91041f47ad11b42f084f1ca765.jpg", "jpg", 36936);
  danbooru_generate_coefficient_sql(dump, "images/e77a9e21f38b5ba4372e3eb5d5f9dd3a.jpg", "jpg", 72666);
  danbooru_generate_coefficient_sql(dump, "images/f438c6f2f1015ad1237654f77bb82ea8.gif", "gif", 74421);
  danbooru_generate_coefficient_sql(dump, "images/394d83b9226c9bc0cb5d88d4a086c060.jpg", "jpg", 135576);
  danbooru_generate_coefficient_sql(dump, "images/18a5b4e3813c443dd7917fbdfaef0e8c.jpg", "jpg", 89710);
  danbooru_generate_coefficient_sql(dump, "images/796b9cea74a381878b49bf25d0d4a180.jpg", "jpg", 80392);
  danbooru_generate_coefficient_sql(dump, "images/81f0f4c020a2ac3735543a1a3875f323.jpg", "jpg", 101907);
  danbooru_generate_coefficient_sql(dump, "images/6c660af4f6067ce181892bf763ca9e09.jpg", "jpg", 83646);
  danbooru_generate_coefficient_sql(dump, "images/7cbe53df4f7515fdf11ef922634e8f5e.jpg", "jpg", 110591);
  danbooru_generate_coefficient_sql(dump, "images/95d2abfbbf86a42048d7ceaa3758d55a.jpg", "jpg", 28832);
  danbooru_generate_coefficient_sql(dump, "images/8d47987ecc1e8ee94f1b78928bd676e0.jpg", "jpg", 83606);
  danbooru_generate_coefficient_sql(dump, "images/09991ed092a25b76178b96df07853199.jpg", "jpg", 28207);
  danbooru_generate_coefficient_sql(dump, "images/8eee77c7685c57243145ee9085eae440.jpg", "jpg", 135617);
  danbooru_generate_coefficient_sql(dump, "images/8f68d6b79505623628acbe06b0a65dea.jpg", "jpg", 125209);
  danbooru_generate_coefficient_sql(dump, "images/2b5b9907e36269d7b8ad5afbf7c2614a.jpg", "jpg", 43205);
  danbooru_generate_coefficient_sql(dump, "images/eee0db3a5e7ceb42ca6b0c6b8432eb5f.jpg", "jpg", 9843);
  danbooru_generate_coefficient_sql(dump, "images/0f59340e50f2f590362f59e38edc1f47.jpg", "jpg", 40267);
  danbooru_generate_coefficient_sql(dump, "images/a23297b12d82534f2acc6a76ffb39295.jpg", "jpg", 134914);
  danbooru_generate_coefficient_sql(dump, "images/158da4d228172a377d8b4cc12d8cfe8c.jpg", "jpg", 133308);
  danbooru_generate_coefficient_sql(dump, "images/e381faf56781f4e59f6e60b53159ebe8.jpg", "jpg", 80615);
  danbooru_generate_coefficient_sql(dump, "images/046f9c005bd5e17645c9cfe324db6d3e.jpg", "jpg", 87575);
  danbooru_generate_coefficient_sql(dump, "images/c83b25bbfc0dd6a51c0aa6da358942eb.jpg", "jpg", 58810);
  danbooru_generate_coefficient_sql(dump, "images/af9e294e012d937fa9d4446552cfd7c9.jpg", "jpg", 95689);
  danbooru_generate_coefficient_sql(dump, "images/c0a7e5f9567dc4c098334d9be2d47b5c.jpg", "jpg", 118468);
  danbooru_generate_coefficient_sql(dump, "images/a0fd44601e93f405cdd9d50c99d5b399.jpg", "jpg", 114509);
  danbooru_generate_coefficient_sql(dump, "images/c1cab6a28faf57b33f075dd55629ad23.jpg", "jpg", 56417);
  danbooru_generate_coefficient_sql(dump, "images/a651e00b45721b5b90d529371485847b.jpg", "jpg", 122325);
  danbooru_generate_coefficient_sql(dump, "images/4e7579a5a42357e4a74932bbd7c34374.jpg", "jpg", 84990);
  danbooru_generate_coefficient_sql(dump, "images/eddd0dd76a8273e4b577594d5913f01c.jpg", "jpg", 95711);
  danbooru_generate_coefficient_sql(dump, "images/d3d43c430d7538b005471d0add26685e.png", "png", 20848);
  danbooru_generate_coefficient_sql(dump, "images/334eb828a136ebb284ff330ddf44c423.jpg", "jpg", 128911);
  danbooru_generate_coefficient_sql(dump, "images/479650ecaad328fde22b895c6ce96561.jpg", "jpg", 73305);
  danbooru_generate_coefficient_sql(dump, "images/be0267695d1094a5c92172579d6ceefc.jpg", "jpg", 123924);
  danbooru_generate_coefficient_sql(dump, "images/19bf369023080c779517a53d349b18e8.jpg", "jpg", 41737);
  danbooru_generate_coefficient_sql(dump, "images/817d6a94426c71c29833653cc0d4e8e4.jpg", "jpg", 115282);
  danbooru_generate_coefficient_sql(dump, "images/95ef9cd74a502197bcbfe72757702e05.jpg", "jpg", 50373);
  danbooru_generate_coefficient_sql(dump, "images/9c23f05a33295134eefa44ef01bb050d.jpg", "jpg", 62310);
  danbooru_generate_coefficient_sql(dump, "images/2846581a93798d4a1d2527a496ab82e9.png", "png", 127745);
  danbooru_generate_coefficient_sql(dump, "images/0f20b07f0437542bef4b18cb6309241d.gif", "gif", 41689);
  danbooru_generate_coefficient_sql(dump, "images/a7c2270ef3738812d9548b36ff140c6e.jpg", "jpg", 59243);
  danbooru_generate_coefficient_sql(dump, "images/cd20f074e6a80c50ea3312ca296d1fe7.jpg", "jpg", 31318);
  danbooru_generate_coefficient_sql(dump, "images/85b6c5cb85fd38719848861c4bd9e82b.gif", "gif", 120021);
  danbooru_generate_coefficient_sql(dump, "images/57fb4b68b15202476b6d6e480d1c1319.jpg", "jpg", 14821);
  danbooru_generate_coefficient_sql(dump, "images/38e780bdd1adc38573f00bf986d73ae9.jpeg", "jpg", 122491);
  danbooru_generate_coefficient_sql(dump, "images/751d8fa25459e4b508809fac1b85d0bf.jpg", "jpg", 63397);
  danbooru_generate_coefficient_sql(dump, "images/6f00e0dbec231d870a7f58f541e62f7e.jpg", "jpg", 76474);
  danbooru_generate_coefficient_sql(dump, "images/c68fda92915b85e4f6623edaac22c941.jpg", "jpg", 1100);
  danbooru_generate_coefficient_sql(dump, "images/5f8026bcb35976e6f97fb6909df5d9c5.jpg", "jpg", 125398);
  danbooru_generate_coefficient_sql(dump, "images/a2c397c527e5f30778261ea2f485888e.gif", "gif", 13036);
  danbooru_generate_coefficient_sql(dump, "images/dba71a5b0865dc5b0e60c80f2da431fc.jpg", "jpg", 21933);
  danbooru_generate_coefficient_sql(dump, "images/dd5889f6831e36ee71e93a2324df8b48.jpg", "jpg", 30096);
  danbooru_generate_coefficient_sql(dump, "images/c756d22fe13be458d859bed379e28b90.jpg", "jpg", 71743);
  danbooru_generate_coefficient_sql(dump, "images/e3ba9781553bd23e007ccc5218130065.png", "png", 996);
  danbooru_generate_coefficient_sql(dump, "images/e92363cf2ed9eac7d39d4dc0ad6f7e38.jpg", "jpg", 117533);
  danbooru_generate_coefficient_sql(dump, "images/c050f50ae71730791323c38d6e5fbf9e.jpg", "jpg", 13042);
  danbooru_generate_coefficient_sql(dump, "images/4187d2f3b0796a27464f52715e3dd83a.jpg", "jpg", 47042);
  danbooru_generate_coefficient_sql(dump, "images/2cd7265e92b52d97e74ee8bc1fa00a17.jpg", "jpg", 11561);
  danbooru_generate_coefficient_sql(dump, "images/b0d5ca065217cbd9ccab8c5e41e08288.jpg", "jpg", 2081);
  danbooru_generate_coefficient_sql(dump, "images/f4ec2f87a56c1b6616a4f6efaad7ab9e.jpg", "jpg", 106812);
  danbooru_generate_coefficient_sql(dump, "images/6025945322d72cb74a8e2dfeffb3d46d.jpg", "jpg", 94916);
  danbooru_generate_coefficient_sql(dump, "images/64d23a8a511ec8f0c82ef6467711e214.jpg", "jpg", 1803);
  danbooru_generate_coefficient_sql(dump, "images/934116e0af7ebcb3e2e8550551a50114.jpg", "jpg", 104617);
  danbooru_generate_coefficient_sql(dump, "images/a26ab9b31956d1e027c5b7053d7159b7.jpg", "jpg", 132279);
  danbooru_generate_coefficient_sql(dump, "images/48b4b5cb9531ed7754253bc3c6c71f4f.jpg", "jpg", 4035);
  danbooru_generate_coefficient_sql(dump, "images/4ba989554cb5e57c5964a63261d258d6.jpg", "jpg", 69332);
  danbooru_generate_coefficient_sql(dump, "images/0c09382120a64f044013fb59982f0973.jpg", "jpg", 55348);
  danbooru_generate_coefficient_sql(dump, "images/c5b0de94aa85f1512d3b33aae71b192c.jpg", "jpg", 48208);
  danbooru_generate_coefficient_sql(dump, "images/86826e047e909d18dfda7bbe39e4f1d5.jpg", "jpg", 18030);
  danbooru_generate_coefficient_sql(dump, "images/38a5ded050761fa9f314d54293b131cc.jpg", "jpg", 82903);
  danbooru_generate_coefficient_sql(dump, "images/31f980f7688d4f3482150c6a24e08c0e.jpg", "jpg", 112619);
  danbooru_generate_coefficient_sql(dump, "images/3d53f1f5e5028dd488d9e73eebd7a804.jpg", "jpg", 23066);
  danbooru_generate_coefficient_sql(dump, "images/943ea2d09d90d83ef16150d3801d8902.jpg", "jpg", 76022);
  danbooru_generate_coefficient_sql(dump, "images/3f2f0de315bf3966a742a83061693971.jpg", "jpg", 98570);
  danbooru_generate_coefficient_sql(dump, "images/2d24bbbe1bbcf3f43755ebec8dfafb6f.jpg", "jpg", 15100);
  danbooru_generate_coefficient_sql(dump, "images/83e45484584cba420f11e1d6d11af18d.png", "png", 49737);
  danbooru_generate_coefficient_sql(dump, "images/f1b27fbf0003999db04fbf9fb83a3ea3.png", "png", 31925);
  danbooru_generate_coefficient_sql(dump, "images/4a2d478a9b524e057e677958986e4fa7.jpg", "jpg", 85388);
  danbooru_generate_coefficient_sql(dump, "images/349abb4bb5c203f05c8120e73232451a.jpg", "jpg", 94162);
  danbooru_generate_coefficient_sql(dump, "images/ddc784babbaafacc838adb7d1c82795b.jpg", "jpg", 35257);
  danbooru_generate_coefficient_sql(dump, "images/4e47835b70d7e7901b0d6615daaf9dce.png", "png", 2687);
  danbooru_generate_coefficient_sql(dump, "images/d06dfc97e774443a25520be687e2b113.jpg", "jpg", 61199);
  danbooru_generate_coefficient_sql(dump, "images/2b96b87509332d0b06b454813e5499d2.jpg", "jpg", 101607);
  danbooru_generate_coefficient_sql(dump, "images/caee953806059e15b55bbaeb9a4e2538.png", "png", 103217);
  danbooru_generate_coefficient_sql(dump, "images/fcb5f1913bc4cc83ebd7668bbaad5c68.jpg", "jpg", 121041);
  danbooru_generate_coefficient_sql(dump, "images/5b38b2ec861ba7b6382a0000f1f6b789.jpg", "jpg", 77744);
  danbooru_generate_coefficient_sql(dump, "images/78886c53afa1a876d0167332fb44063f.jpg", "jpg", 71145);
  danbooru_generate_coefficient_sql(dump, "images/2e680c6e09599b58356ead97008066ed.jpg", "jpg", 31137);
  danbooru_generate_coefficient_sql(dump, "images/a64fe7e1748d7ff283db65474b4585bf.jpg", "jpg", 125719);
  danbooru_generate_coefficient_sql(dump, "images/f75c3ad229bc4bbf6e9772d8a1378bf3.jpg", "jpg", 117683);
  danbooru_generate_coefficient_sql(dump, "images/1bfc03725588859d01860a6a23391744.jpg", "jpg", 73776);
  danbooru_generate_coefficient_sql(dump, "images/d8ee41081ebf0578990971999b644c1d.jpeg", "jpg", 128091);
  danbooru_generate_coefficient_sql(dump, "images/e36e2dbf812465a91ad0d79275a361ae.jpg", "jpg", 2722);
  danbooru_generate_coefficient_sql(dump, "images/db3a324474e6c9a412269197bf15393a.jpg", "jpg", 42102);
  danbooru_generate_coefficient_sql(dump, "images/9270549f9d2452cc2ff8700c1d27e2e0.jpg", "jpg", 41215);
  danbooru_generate_coefficient_sql(dump, "images/acc74caf5c30ad03ea61e19da9cf3053.jpg", "jpg", 75124);
  danbooru_generate_coefficient_sql(dump, "images/72d330ae51bfca84d41bb8ba060e33a5.jpg", "jpg", 38837);
  danbooru_generate_coefficient_sql(dump, "images/c7489acebdfe142ff3c112b76cceb3d7.jpg", "jpg", 34088);
  danbooru_generate_coefficient_sql(dump, "images/85d8888054bc210805f5c1395cbe2717.jpg", "jpg", 16906);
  danbooru_generate_coefficient_sql(dump, "images/3fab38d4b1e759558adc883838026aec.jpg", "jpg", 98583);
  danbooru_generate_coefficient_sql(dump, "images/9f6d3e11b69390e0030e4810bb7abb50.jpg", "jpg", 138033);
  danbooru_generate_coefficient_sql(dump, "images/0d077106be1b85295c550762fc451d1f.jpg", "jpg", 121851);
  danbooru_generate_coefficient_sql(dump, "images/2fc177b7d02f8c4ed26745dd422abde1.jpg", "jpg", 27786);
  danbooru_generate_coefficient_sql(dump, "images/c1036b9551a194ad17fd7e5af31a20b2.jpg", "jpg", 7781);
  danbooru_generate_coefficient_sql(dump, "images/85c57028b17f7810cbb540ce44a5811f.jpg", "jpg", 141531);
  danbooru_generate_coefficient_sql(dump, "images/c58737448e69fe84da36994edd40fac9.jpg", "jpg", 122964);
  danbooru_generate_coefficient_sql(dump, "images/4a9860dd8e0a2c46ab0e5c8704f56b31.png", "png", 132516);
  danbooru_generate_coefficient_sql(dump, "images/3f5f321fababbd858ebf34174f870132.jpg", "jpg", 136547);
  danbooru_generate_coefficient_sql(dump, "images/853e72d3b6b1d6ad042f79c3b8136711.jpg", "jpg", 71817);
  danbooru_generate_coefficient_sql(dump, "images/de7388250c39acc46c0fefa33b727c94.jpg", "jpg", 30302);
  danbooru_generate_coefficient_sql(dump, "images/423a3551a3364070a60cc1d60801a117.jpg", "jpg", 57402);
  danbooru_generate_coefficient_sql(dump, "images/b786e7b1964211e118e804cf7b8efb71.jpg", "jpg", 14136);
  danbooru_generate_coefficient_sql(dump, "images/e10dd28e748c89b1850d98d89692ed57.jpg", "jpg", 87600);
  danbooru_generate_coefficient_sql(dump, "images/bfd097ae39fd5be31982f4798004a340.jpg", "jpg", 107962);
  danbooru_generate_coefficient_sql(dump, "images/aca24738e08ccc45f5b439da71fcf962.jpg", "jpg", 15291);
  danbooru_generate_coefficient_sql(dump, "images/95d7a91a558a4b66c555ad4477abe3a6.jpg", "jpg", 37810);
  danbooru_generate_coefficient_sql(dump, "images/e531083631d2189f434359b0e81fd532.jpg", "jpg", 82348);
  danbooru_generate_coefficient_sql(dump, "images/6f9b0155b37b8c82588e9f7255d0f40d.jpg", "jpg", 23119);
  danbooru_generate_coefficient_sql(dump, "images/24ea1777f6521d24215c31ed2418d435.jpg", "jpg", 128072);
  danbooru_generate_coefficient_sql(dump, "images/b15299ff1d5dc6ecc206ceeb45290c41.jpg", "jpg", 125419);
  danbooru_generate_coefficient_sql(dump, "images/8db4992268ead2b19b2747d569980ab4.jpg", "jpg", 125523);
  danbooru_generate_coefficient_sql(dump, "images/f9741bbc1dda562e0ba6844cbfadedf2.jpg", "jpg", 80319);
  danbooru_generate_coefficient_sql(dump, "images/462d59813c291514ecf0971dec83dd10.jpg", "jpg", 85365);
  danbooru_generate_coefficient_sql(dump, "images/5d48fef121017a7b88c8e6f42eb03276.jpg", "jpg", 61267);
  danbooru_generate_coefficient_sql(dump, "images/859aad21db579a622c11ef173bcb3a2a.jpg", "jpg", 90019);
  danbooru_generate_coefficient_sql(dump, "images/fda0d61970763e76d0e87413d0670c4d.jpg", "jpg", 67);
  danbooru_generate_coefficient_sql(dump, "images/5f72e7427c6401270d417c180a56fd1a.jpg", "jpg", 10430);
  danbooru_generate_coefficient_sql(dump, "images/9f783e71092e123138087212f1eedb1b.jpg", "jpg", 16293);
  danbooru_generate_coefficient_sql(dump, "images/852507938e8d62cbd69e3c9c1e210c71.jpg", "jpg", 51333);
  danbooru_generate_coefficient_sql(dump, "images/f3bc700a996d54eafdf8d8cb5e6d8b16.jpeg", "jpg", 130834);
  danbooru_generate_coefficient_sql(dump, "images/bbe1ccc6b0a6c1b270c728b3fd207c3e.jpg", "jpg", 5828);
  danbooru_generate_coefficient_sql(dump, "images/b663c461769bca524128fcfab59288bd.jpg", "jpg", 27309);
  danbooru_generate_coefficient_sql(dump, "images/dc24bcad6208f5c6b48ed00e0dbc5a13.jpg", "jpg", 7631);
  danbooru_generate_coefficient_sql(dump, "images/b0b5ec667933ad09e9c0e385957a84de.jpg", "jpg", 116093);
  danbooru_generate_coefficient_sql(dump, "images/984bd6a523a53dd0ae6f8184dcb2e719.jpg", "jpg", 29037);
  danbooru_generate_coefficient_sql(dump, "images/4f1cae1794d00e1656273eb1576c03ed.jpg", "jpg", 47839);
  danbooru_generate_coefficient_sql(dump, "images/42b7442e8d4db0ed2b15ec557af9ccb3.jpg", "jpg", 69449);
  danbooru_generate_coefficient_sql(dump, "images/fe920624fc2eb268e5323da8f241825d.jpeg", "jpg", 116797);
  danbooru_generate_coefficient_sql(dump, "images/000809ee6c0e21370ecb0de4976e9c4b.jpg", "jpg", 10749);
  danbooru_generate_coefficient_sql(dump, "images/c736f315f1b3c5fd8ab48f65ba5784f8.jpg", "jpg", 32018);
  danbooru_generate_coefficient_sql(dump, "images/239bd0c40159f9f007a230c9481009ae.gif", "gif", 36477);
  danbooru_generate_coefficient_sql(dump, "images/6dcd7791b967aff830edc7120e1590fc.jpg", "jpg", 65501);
  danbooru_generate_coefficient_sql(dump, "images/736f277585f180ba94f4e519245c1da5.jpg", "jpg", 15214);
  danbooru_generate_coefficient_sql(dump, "images/c16f1edfbc33636628fb00efe17aee73.jpg", "jpg", 105832);
  danbooru_generate_coefficient_sql(dump, "images/f1c5aa5159a53a628e5266e0b44569f4.gif", "gif", 8164);
  danbooru_generate_coefficient_sql(dump, "images/9983a6ade90f6e57b91a77bfa658de51.jpg", "jpg", 38932);
  danbooru_generate_coefficient_sql(dump, "images/006310f96ed4bde49eb5553bfaaa6f61.jpg", "jpg", 14086);
  danbooru_generate_coefficient_sql(dump, "images/3e9167989d8e4c1d108fa856045403ec.jpg", "jpg", 106628);
  danbooru_generate_coefficient_sql(dump, "images/23a040f6d4ed8f9623bca55b59ea6199.jpg", "jpg", 6389);
  danbooru_generate_coefficient_sql(dump, "images/4708097481187caf81b8422730e15c52.jpg", "jpg", 98181);
  danbooru_generate_coefficient_sql(dump, "images/84e7b085cb15a2636ef197b141e9e14f.jpg", "jpg", 36833);
  danbooru_generate_coefficient_sql(dump, "images/9366d1ded14d2b50ff68234ed8ca47ad.jpg", "jpg", 71212);
  danbooru_generate_coefficient_sql(dump, "images/48dcd7c5012b8ec105bf559b726f5723.jpg", "jpg", 104479);
  danbooru_generate_coefficient_sql(dump, "images/9518e27425cec362597ca202304aa022.jpg", "jpg", 82737);
  danbooru_generate_coefficient_sql(dump, "images/e5fd79574115291022afea9b030097f6.jpg", "jpg", 98871);
  danbooru_generate_coefficient_sql(dump, "images/5c1f49f1f70b45b3af1701bf18c65075.jpg", "jpg", 40870);
  danbooru_generate_coefficient_sql(dump, "images/01905012855511ddaa8fe4c6a49f12ae.jpg", "jpg", 61490);
  danbooru_generate_coefficient_sql(dump, "images/7b384d97555bac0359a2499cf7dd321a.jpg", "jpg", 13547);
  danbooru_generate_coefficient_sql(dump, "images/a82348da4953191a7b241a76f05b1225.jpg", "jpg", 110951);
  danbooru_generate_coefficient_sql(dump, "images/80390de6625dfd03fa42a2e3753372cc.jpg", "jpg", 32131);
  danbooru_generate_coefficient_sql(dump, "images/23e992c44f08658cbeb3337caa859f8f.jpg", "jpg", 58753);
  danbooru_generate_coefficient_sql(dump, "images/d14b4a8877a20ed7dcdf9ae696f3b33a.jpg", "jpg", 50953);
  danbooru_generate_coefficient_sql(dump, "images/80c71e5d9d89f820b5b99eb08a849850.jpg", "jpg", 109717);
  danbooru_generate_coefficient_sql(dump, "images/1726e1865630ffeae8ae2ef280032182.jpg", "jpg", 100703);
  danbooru_generate_coefficient_sql(dump, "images/7e37cb3b922ef9d662a38684b7c066d3.jpg", "jpg", 35140);
  danbooru_generate_coefficient_sql(dump, "images/b21be1342323423cc7b1d33bd534163b.jpg", "jpg", 118165);
  danbooru_generate_coefficient_sql(dump, "images/662babb5279e72a347bc144294eadc52.jpg", "jpg", 26374);
  danbooru_generate_coefficient_sql(dump, "images/ed6bafcf626be786b2d6d5e5b65c1b3f.jpeg", "jpg", 133277);
  danbooru_generate_coefficient_sql(dump, "images/10127584e8f1c048193296cb73e0d8ba.jpg", "jpg", 21844);
  danbooru_generate_coefficient_sql(dump, "images/392704e19d7ef8794f0e84b24511fbf2.jpg", "jpg", 13321);
  danbooru_generate_coefficient_sql(dump, "images/d6572035b33d621c27d5913f29b328d0.gif", "gif", 46974);
  danbooru_generate_coefficient_sql(dump, "images/69f24c3bfa04cb1649b7ef69422b0024.png", "png", 68897);
  danbooru_generate_coefficient_sql(dump, "images/0aba653f0321e27666df028f99d090b7.jpg", "jpg", 72438);
  danbooru_generate_coefficient_sql(dump, "images/a12dc934a6726adcf981cf0e3d4131ae.jpg", "jpg", 93967);
  danbooru_generate_coefficient_sql(dump, "images/5841605e5450a7a8ed472347ca0b2a0e.jpg", "jpg", 18952);
  danbooru_generate_coefficient_sql(dump, "images/aa6772879fa820714ee5041915c7aac3.jpg", "jpg", 27553);
  danbooru_generate_coefficient_sql(dump, "images/c9d4037a958db39932727d3ced18073e.jpg", "jpg", 27284);
  danbooru_generate_coefficient_sql(dump, "images/cd4028c23c76a4d68680f73c77ae3262.jpg", "jpg", 123125);
  danbooru_generate_coefficient_sql(dump, "images/05a68249217b255351a916a94c8320d0.jpg", "jpg", 4183);
  danbooru_generate_coefficient_sql(dump, "images/66bc99a2714f4d321c075138fb13892e.jpg", "jpg", 125408);
  danbooru_generate_coefficient_sql(dump, "images/4afc1a21009c3939309b25c0f0678d5f.jpg", "jpg", 23596);
  danbooru_generate_coefficient_sql(dump, "images/7f2dbd9760b3bca791f3cb1b41a8bfac.jpg", "jpg", 28742);
  danbooru_generate_coefficient_sql(dump, "images/dfeee21515d475d63a88b76580f53f50.jpg", "jpg", 52694);
  danbooru_generate_coefficient_sql(dump, "images/a636f1f11924828384ffd2fa278be883.jpg", "jpg", 88805);
  danbooru_generate_coefficient_sql(dump, "images/34426a5d4ef719524da64b5eabd20fda.jpg", "jpg", 52741);
  danbooru_generate_coefficient_sql(dump, "images/582c791e5a2e29805b9ece1f5728010f.jpg", "jpg", 112187);
  danbooru_generate_coefficient_sql(dump, "images/cb5c78b3149ff46e70727dfc19ed4237.jpg", "jpg", 95626);
  danbooru_generate_coefficient_sql(dump, "images/d875ef1948edbb127e68bc543fe8a6af.jpg", "jpg", 77054);
  danbooru_generate_coefficient_sql(dump, "images/604fabaa136ef98d684611fb87d59663.jpg", "jpg", 136901);
  danbooru_generate_coefficient_sql(dump, "images/c4978fc78653960463091a987ddd6de3.jpg", "jpg", 29161);
  danbooru_generate_coefficient_sql(dump, "images/0e17f6ea27734c12b68e7cfbf3970a9b.jpg", "jpg", 12176);
  danbooru_generate_coefficient_sql(dump, "images/635421f2a650a4f47ae13e9adb7ef1c6.jpg", "jpg", 15899);
  danbooru_generate_coefficient_sql(dump, "images/c0f12a59c52f35baff482206038cce1c.jpg", "jpg", 66881);
  danbooru_generate_coefficient_sql(dump, "images/bf03e278cbc9d22bd6208472e9c1f344.jpg", "jpg", 98895);
  danbooru_generate_coefficient_sql(dump, "images/e14a4fa739bbb47f29bdbab7817269e2.jpg", "jpg", 132436);
  danbooru_generate_coefficient_sql(dump, "images/c7ca2aae5e42133b2e2649a8074b0c40.jpg", "jpg", 118488);
  danbooru_generate_coefficient_sql(dump, "images/a8cd510bd986e35d4e152bddc259e349.jpg", "jpg", 56325);
  danbooru_generate_coefficient_sql(dump, "images/60fd4171e1d229ca77c5eee7e84e8e06.jpg", "jpg", 61714);
  danbooru_generate_coefficient_sql(dump, "images/94c84d431ffe70857c4a6ad1f438a402.jpg", "jpg", 83159);
  danbooru_generate_coefficient_sql(dump, "images/11ff93bd96c48ea6e40f0ca266da0979.jpg", "jpg", 124655);
  danbooru_generate_coefficient_sql(dump, "images/f80ffe544a7e5a2606545913a906a85b.jpg", "jpg", 27062);
  danbooru_generate_coefficient_sql(dump, "images/80e4cc9cf096d4e8243e2f07bc313028.jpg", "jpg", 38389);
  danbooru_generate_coefficient_sql(dump, "images/f2be1b015430fea398b4648f51e4947e.jpg", "jpg", 110470);
  danbooru_generate_coefficient_sql(dump, "images/601f1bd4805bea25e77e18d27e1fbb54.jpg", "jpg", 135540);
  danbooru_generate_coefficient_sql(dump, "images/f4a23892132a992ed6413037db289c36.jpg", "jpg", 37135);
  danbooru_generate_coefficient_sql(dump, "images/315ef589affd3311b278a1966d1d5c35.jpg", "jpg", 118779);
  danbooru_generate_coefficient_sql(dump, "images/20d8d61241e610d9184c42d12ad0964e.jpg", "jpg", 74432);
  danbooru_generate_coefficient_sql(dump, "images/bcb6b365df946a04643df2c6a3abc2d3.jpeg", "jpg", 116697);
  danbooru_generate_coefficient_sql(dump, "images/8c5179f3ad093b3e4d8beac0b60f1cb8.jpg", "jpg", 21741);
  danbooru_generate_coefficient_sql(dump, "images/582061ef9f864a725e7eaceebd71a656.jpg", "jpg", 135933);
  danbooru_generate_coefficient_sql(dump, "images/7139c43f5678cc6f5cb25557acfdd41f.jpg", "jpg", 70202);
  danbooru_generate_coefficient_sql(dump, "images/fefa003303cd50c4ef0a0d8c0784bf5e.gif", "gif", 9273);
  danbooru_generate_coefficient_sql(dump, "images/6b72168aa6f43502c46315c9d0ec7f63.jpg", "jpg", 59798);
  danbooru_generate_coefficient_sql(dump, "images/dd6755f8e4ab3c1f9b880c962696d4f4.jpg", "jpg", 128484);
  danbooru_generate_coefficient_sql(dump, "images/30be3fd3a20a19b692c22e359ce91676.jpg", "jpg", 57097);
  danbooru_generate_coefficient_sql(dump, "images/336381163ac53a38618045f6840fe58f.jpg", "jpg", 122160);
  danbooru_generate_coefficient_sql(dump, "images/c061b94f6705eb076df80a1b18385c99.jpg", "jpg", 36553);
  danbooru_generate_coefficient_sql(dump, "images/013c4965bc79664cd673f83864c1de44.jpg", "jpg", 14944);
  danbooru_generate_coefficient_sql(dump, "images/39c34c2b8304f749fd02340bff4b1fdb.jpg", "jpg", 69956);
  danbooru_generate_coefficient_sql(dump, "images/43714947398604054633ab70fce0ebd4.jpg", "jpg", 51787);
  danbooru_generate_coefficient_sql(dump, "images/12167944fa95596bf799b7867a7921b8.jpeg", "jpg", 116913);
  danbooru_generate_coefficient_sql(dump, "images/be98d67946f425292d4d99a93e9245fb.jpg", "jpg", 141836);
  danbooru_generate_coefficient_sql(dump, "images/9fc586b6ecfd547d229d607681646b65.png", "png", 140157);
  danbooru_generate_coefficient_sql(dump, "images/f4c5ab8db35ee9d5352d4f800f236469.png", "png", 98862);
  danbooru_generate_coefficient_sql(dump, "images/c7a5a11fbc7a5e72f56de5d85afcbd94.png", "png", 59605);
  danbooru_generate_coefficient_sql(dump, "images/7ed2fc81df0437cc2afed22a47918c4b.jpg", "jpg", 124970);
  danbooru_generate_coefficient_sql(dump, "images/0c146f107fdb32b8cfcf29fa592e160c.jpg", "jpg", 129956);
  danbooru_generate_coefficient_sql(dump, "images/81cd8f015911dd11c1a010db57bc07bb.jpg", "jpg", 16772);
  danbooru_generate_coefficient_sql(dump, "images/874c5bdf78c0013c6ae6b30a9bf33a5f.jpg", "jpg", 116304);
  danbooru_generate_coefficient_sql(dump, "images/82ded62c3a9b872ec44bed080318a9dd.jpg", "jpg", 30472);
  danbooru_generate_coefficient_sql(dump, "images/462576d43119e84650d54a8025b0cad8.jpg", "jpg", 16307);
  danbooru_generate_coefficient_sql(dump, "images/92bb047ca50854eaf82ce78a552f960b.jpg", "jpg", 13945);
  danbooru_generate_coefficient_sql(dump, "images/993ebe35fc88fb1d81dbd0d227efb855.jpg", "jpg", 23015);
  danbooru_generate_coefficient_sql(dump, "images/2a628a58ad64c91a332211d2564d0010.jpg", "jpg", 8097);
  danbooru_generate_coefficient_sql(dump, "images/a4f9c68cc4afbec6dda13757f4440461.jpg", "jpg", 11116);
  danbooru_generate_coefficient_sql(dump, "images/0df7049b080856d7945439ce17b05055.jpg", "jpg", 105045);
  danbooru_generate_coefficient_sql(dump, "images/dd26ea8bd351151e3dcdcfb868f251ea.jpg", "jpg", 120176);
  danbooru_generate_coefficient_sql(dump, "images/565a0fc1c0ed4604ef54fe949f01b51f.jpg", "jpg", 135512);
  danbooru_generate_coefficient_sql(dump, "images/c4d15ddb5a9abd078d7bbf59ce0e022c.jpg", "jpg", 103741);
  danbooru_generate_coefficient_sql(dump, "images/de70d09ba9020066e83bbf9b88744ad4.gif", "gif", 134665);
  danbooru_generate_coefficient_sql(dump, "images/16bfaeb5eeb9397a624df86082109e1f.jpg", "jpg", 9673);
  danbooru_generate_coefficient_sql(dump, "images/4c4a508c306a15ed654c18dcf6a8ef8a.jpg", "jpg", 83807);
  danbooru_generate_coefficient_sql(dump, "images/d94ba40651a76467914ae05942136810.gif", "gif", 934);
  danbooru_generate_coefficient_sql(dump, "images/3b8e3b44a294f71b5f75030765c51fb6.jpg", "jpg", 24285);
  danbooru_generate_coefficient_sql(dump, "images/3bf32596c669010e021d85aa4c1fea9c.jpg", "jpg", 24455);
  danbooru_generate_coefficient_sql(dump, "images/64698f50efbe196e8b72d934b810a066.png", "png", 34939);
  danbooru_generate_coefficient_sql(dump, "images/e561f3e6d47f51ca4047a0ff810259c2.jpg", "jpg", 69500);
  danbooru_generate_coefficient_sql(dump, "images/51710e92aaf7db929acb67ff1d53bae2.jpg", "jpg", 8471);
  danbooru_generate_coefficient_sql(dump, "images/7575eb9a53c1d97860ae017500ebc58a.jpg", "jpg", 27648);
  danbooru_generate_coefficient_sql(dump, "images/69e87cbb1b6a446b0b036daa386d20a0.jpg", "jpg", 87604);
  danbooru_generate_coefficient_sql(dump, "images/00695a19cbfedfe6224766466069bcaf.gif", "gif", 1660);
  danbooru_generate_coefficient_sql(dump, "images/b4d2d33156d4f56412f2f45e6f7f248a.jpg", "jpg", 6648);
  danbooru_generate_coefficient_sql(dump, "images/d6640154571eae524889e350ba1c2538.jpg", "jpg", 81897);
  danbooru_generate_coefficient_sql(dump, "images/f55509c1ea19ecefb4ce2ac86be405dc.jpg", "jpg", 19236);
  danbooru_generate_coefficient_sql(dump, "images/6c4aef61d0ed5a4c96ce74912763f192.gif", "gif", 46131);
  danbooru_generate_coefficient_sql(dump, "images/ea3634c367d8535911742daf95eeaaa7.jpg", "jpg", 58730);
  danbooru_generate_coefficient_sql(dump, "images/94e82c1cfa141adbac3e1abfc4059954.jpg", "jpg", 132809);
  danbooru_generate_coefficient_sql(dump, "images/e7b997ba087a00b564f5bf395a213f7d.jpg", "jpg", 32052);
  danbooru_generate_coefficient_sql(dump, "images/d7ca00d54134daf22d83c1faacc18dfb.jpg", "jpg", 17651);
  danbooru_generate_coefficient_sql(dump, "images/e41bb2372aff856008863c928b959f98.jpg", "jpg", 116970);
  danbooru_generate_coefficient_sql(dump, "images/82ba368f712c8b010606dc07fb71da16.jpg", "jpg", 122357);
  danbooru_generate_coefficient_sql(dump, "images/1caf3873777bdbc9b8dbad61a8be9555.jpg", "jpg", 19767);
  danbooru_generate_coefficient_sql(dump, "images/783fa3dedd4a860f57c308c29e67dd46.jpg", "jpg", 113067);
  danbooru_generate_coefficient_sql(dump, "images/761212c0ef6406256ffe1c9562f991e9.jpg", "jpg", 69732);
  danbooru_generate_coefficient_sql(dump, "images/f8f97e6b06adee220c9f68672613f844.jpg", "jpg", 2937);
  danbooru_generate_coefficient_sql(dump, "images/4b590c3514bbba5539c7ed5196c591cb.jpg", "jpg", 50274);
  danbooru_generate_coefficient_sql(dump, "images/d926bbc5cb830939b31ce3cf1a196ada.jpg", "jpg", 122753);
  danbooru_generate_coefficient_sql(dump, "images/c98e5dee3a4d6d36ec50f6a64bcbd2d9.jpg", "jpg", 62129);
  danbooru_generate_coefficient_sql(dump, "images/c4bcd9304967bced8baf42e5de861924.jpg", "jpg", 68762);
  danbooru_generate_coefficient_sql(dump, "images/7f27ed38472f5f388247e5fdbd4b8694.jpg", "jpg", 64169);
  danbooru_generate_coefficient_sql(dump, "images/b8cec6505cc1f12290d1d8e207864328.jpg", "jpg", 15457);
  danbooru_generate_coefficient_sql(dump, "images/741b83923393a0195d3ab994609e9fa1.jpg", "jpg", 22197);
  danbooru_generate_coefficient_sql(dump, "images/8e93d1fdaadd4c2ff2eec3c696726f9a.jpg", "jpg", 135829);
  danbooru_generate_coefficient_sql(dump, "images/d18533b92b18daff76bd3427cea8156d.jpg", "jpg", 8882);
  danbooru_generate_coefficient_sql(dump, "images/e418d080ee54db9c4787cc0f1d7490f3.jpg", "jpg", 51806);
  danbooru_generate_coefficient_sql(dump, "images/9b16fa50b6a548c6f72d69186f84fb59.jpg", "jpg", 139003);
  danbooru_generate_coefficient_sql(dump, "images/7f9b4b93a0eb3a7c3741a5e0b75b083c.jpg", "jpg", 100644);
  danbooru_generate_coefficient_sql(dump, "images/d202010ff8d2b45a16c99c2158083b39.jpg", "jpg", 134829);
  danbooru_generate_coefficient_sql(dump, "images/e278d8d0de6801905c40eba6cd615a84.jpg", "jpg", 18121);
  danbooru_generate_coefficient_sql(dump, "images/8cba3a7305c6e709bd8152b37143ff5a.jpg", "jpg", 17941);
  danbooru_generate_coefficient_sql(dump, "images/d372649c72bf76a6b41c886b07116a82.jpg", "jpg", 9585);
  danbooru_generate_coefficient_sql(dump, "images/126647133120f0551dba2387556be4c6.jpg", "jpg", 125133);
  danbooru_generate_coefficient_sql(dump, "images/91348829c0cc5d4b4cab692f34a6fc48.jpg", "jpg", 19039);
  danbooru_generate_coefficient_sql(dump, "images/1d58d8bb13a38af56140efc99e1ef7fa.jpg", "jpg", 108705);
  danbooru_generate_coefficient_sql(dump, "images/d695bff0cd01bf6ccd5a8101eabc7afe.jpg", "jpg", 14339);
  danbooru_generate_coefficient_sql(dump, "images/6ac1c2716aee9fa4bbb16987b3dd34d4.jpg", "jpg", 49389);
  danbooru_generate_coefficient_sql(dump, "images/b088c18eee451d99656d61f6eed713eb.jpg", "jpg", 22875);
  danbooru_generate_coefficient_sql(dump, "images/4ee5afc9db0a40ea2ef229eed5e8fbd7.jpg", "jpg", 116824);
  danbooru_generate_coefficient_sql(dump, "images/8512ed17dd8cc84de2723ffc2212d67c.jpg", "jpg", 50415);
  danbooru_generate_coefficient_sql(dump, "images/07c3b84354f5a8c6f8ebe34b5c0aca06.jpeg", "jpg", 128336);
  danbooru_generate_coefficient_sql(dump, "images/758f19a86371f6c7018b4c7391aa07ad.png", "png", 3058);
  danbooru_generate_coefficient_sql(dump, "images/a1486467830e24545c5a0f34c987e0d6.jpg", "jpg", 128554);
  danbooru_generate_coefficient_sql(dump, "images/33e095ee3e64c94b8ef87baca22cd50b.jpg", "jpg", 12170);
  danbooru_generate_coefficient_sql(dump, "images/9c1086f9c50f1cc58dcef115854a81e7.jpg", "jpg", 124674);
  danbooru_generate_coefficient_sql(dump, "images/07f23979f0a6a3c9ecf0250491659f7d.jpg", "jpg", 121584);
  danbooru_generate_coefficient_sql(dump, "images/229cb95cb0a721771a4c74cdda11d80c.jpg", "jpg", 49358);
  danbooru_generate_coefficient_sql(dump, "images/0671a3fd9a5eae132ce30e868defedfc.jpg", "jpg", 109559);
  danbooru_generate_coefficient_sql(dump, "images/22e2f6c09a353b78e282470cfd3e4810.jpg", "jpg", 57523);
  danbooru_generate_coefficient_sql(dump, "images/4f3a59973810102a41699c3de76d1cc0.jpg", "jpg", 118662);
  danbooru_generate_coefficient_sql(dump, "images/a5b5a195403d8f111b8082d752210616.jpg", "jpg", 95292);
  danbooru_generate_coefficient_sql(dump, "images/2508f06c5e806921da076ec591b66df3.jpg", "jpg", 133044);
  danbooru_generate_coefficient_sql(dump, "images/55d17c82292a8a5cd38199e443ae5fbc.png", "png", 87476);
  danbooru_generate_coefficient_sql(dump, "images/d3b206325f8ab13ee8cc93cc6b43f9b0.jpg", "jpg", 140076);
  danbooru_generate_coefficient_sql(dump, "images/c5c5e2d19d8ff4aab533aed94a384f28.jpg", "jpg", 98547);
  danbooru_generate_coefficient_sql(dump, "images/77e9660e1866899d6850b9b6b8eee7d8.jpg", "jpg", 72219);
  danbooru_generate_coefficient_sql(dump, "images/4473d3c194d1af77996c6e81ef33395e.jpg", "jpg", 71832);
  danbooru_generate_coefficient_sql(dump, "images/0c9c295f80b2ad748a3f8941b3970670.jpg", "jpg", 77053);
  danbooru_generate_coefficient_sql(dump, "images/31b46e46794a9a4c2cad70bc775e54a8.jpg", "jpg", 108087);
  danbooru_generate_coefficient_sql(dump, "images/6be94b60ff4d7bc994a191d3aeefb4b7.jpg", "jpg", 785);
  danbooru_generate_coefficient_sql(dump, "images/1f9173dcdc74656d6f9995677a947544.jpg", "jpg", 5449);
  danbooru_generate_coefficient_sql(dump, "images/3c747321a730d1930fa7454ace87048b.jpg", "jpg", 62173);
  danbooru_generate_coefficient_sql(dump, "images/5b0460f8151525a9e6313e623aca3c37.jpg", "jpg", 5926);
  danbooru_generate_coefficient_sql(dump, "images/1d72d697b6716459309e5be6ad8dd551.jpg", "jpg", 9936);
  danbooru_generate_coefficient_sql(dump, "images/e0668957d9d1c4eb76b22b14f115f525.png", "png", 42595);
  danbooru_generate_coefficient_sql(dump, "images/1ad0c0c033854fbb51143e9c644942db.jpg", "jpg", 22435);
  danbooru_generate_coefficient_sql(dump, "images/eb2453ddeca4377be090b2f2e48f94f5.jpg", "jpg", 137255);
  danbooru_generate_coefficient_sql(dump, "images/481ff334ca5ad76d6fb7bfc7c8e8c4fc.jpg", "jpg", 76085);
  danbooru_generate_coefficient_sql(dump, "images/55c4222f7119b287aba2518809cdd5d9.jpg", "jpg", 16006);
  danbooru_generate_coefficient_sql(dump, "images/12194bcb3691dfc0eeedbcbe7c8df25f.jpg", "jpg", 37844);
  danbooru_generate_coefficient_sql(dump, "images/ac2f506e5c0f7a68c079db0201202539.jpg", "jpg", 3800);
  danbooru_generate_coefficient_sql(dump, "images/8b064477988c7d0c6b0fe61a8fc4cd5b.jpg", "jpg", 110322);
  danbooru_generate_coefficient_sql(dump, "images/0b1fb5cd86c82e1e3219747ebfa21966.jpg", "jpg", 27293);
  danbooru_generate_coefficient_sql(dump, "images/11a7d22d79f391d112d9f96736f9cf87.jpg", "jpg", 14787);
  danbooru_generate_coefficient_sql(dump, "images/956cf0c756177c4bc1dca684c4a95c56.jpg", "jpg", 132290);
  danbooru_generate_coefficient_sql(dump, "images/ba3a062cd899abeb3244cdad1c13290f.jpg", "jpg", 132526);
  danbooru_generate_coefficient_sql(dump, "images/18e562804226f7bff5a29e37edfa5b58.gif", "gif", 56679);
  danbooru_generate_coefficient_sql(dump, "images/001626223b9602bcde58a294ba59a92f.jpg", "jpg", 124387);
  danbooru_generate_coefficient_sql(dump, "images/70c8e30ecc52f0934f16415736c3c917.jpg", "jpg", 13409);
  danbooru_generate_coefficient_sql(dump, "images/ae4bdc110e1207c64bb1942fe1949752.jpg", "jpg", 5595);
  danbooru_generate_coefficient_sql(dump, "images/124ad52ae13b0c01a8a41a0673148d82.jpg", "jpg", 38474);
  danbooru_generate_coefficient_sql(dump, "images/4bae6f1ceb1682d6e957eaf72d76ac96.jpg", "jpg", 114331);
  danbooru_generate_coefficient_sql(dump, "images/6725bcb052991fd2257372f77d96ed19.gif", "gif", 63459);
  danbooru_generate_coefficient_sql(dump, "images/ddb4d54cc5a3297b1d4f379aa183f4f0.gif", "gif", 9645);
  danbooru_generate_coefficient_sql(dump, "images/30901c0ca8625329ba726daedae8ab96.jpg", "jpg", 87551);
  danbooru_generate_coefficient_sql(dump, "images/ed578837744a71815f9cf448b4cfee03.gif", "gif", 3007);
  danbooru_generate_coefficient_sql(dump, "images/d7a4b1b30f29c4a2303b3c991cedbb6d.jpg", "jpg", 128400);
  danbooru_generate_coefficient_sql(dump, "images/4cd23be56d39f79ee9a78f6fc2a489cb.jpg", "jpg", 104315);
  danbooru_generate_coefficient_sql(dump, "images/816b2200acc6ccfcb565e61557836813.jpg", "jpg", 15611);
  danbooru_generate_coefficient_sql(dump, "images/2af21c728d58973faa96e076bc87db50.jpg", "jpg", 25854);
  danbooru_generate_coefficient_sql(dump, "images/478791fa3f86f7b579964cea302a58d0.jpg", "jpg", 32944);
  danbooru_generate_coefficient_sql(dump, "images/0e438f1a41a37eecf6e397b56da975e1.jpg", "jpg", 119622);
  danbooru_generate_coefficient_sql(dump, "images/877a78d7dbac9299cd056a59cac311fe.gif", "gif", 134439);
  danbooru_generate_coefficient_sql(dump, "images/8cf0fb7e08d5568fc5842ef9f9ec18ee.jpg", "jpg", 26856);
  danbooru_generate_coefficient_sql(dump, "images/17af3bd6652bbd9cc7bf3ee6f3c3aa7a.jpg", "jpg", 85083);
  danbooru_generate_coefficient_sql(dump, "images/1e27f4b4777aa8894c2620e1a1eeaf70.jpg", "jpg", 43873);
  danbooru_generate_coefficient_sql(dump, "images/d7ec0384b9984ed50ee3c6e95bbe0f93.jpg", "jpg", 18145);
  danbooru_generate_coefficient_sql(dump, "images/39054cf79bcc733dc245cf67df71b7a3.gif", "gif", 128029);
  danbooru_generate_coefficient_sql(dump, "images/874d4640daae5b910cf8f8b3757f20f7.jpg", "jpg", 61771);
  danbooru_generate_coefficient_sql(dump, "images/156b4de2ce4ddeb184bfc053792d3c19.jpg", "jpg", 20227);
  danbooru_generate_coefficient_sql(dump, "images/dee66a546cfb19e6e5a0ad3ea4e2b7d5.jpg", "jpg", 71728);
  danbooru_generate_coefficient_sql(dump, "images/45dde752dbd33b8288ea20ee78e893a2.jpg", "jpg", 125692);
  danbooru_generate_coefficient_sql(dump, "images/2aafa8f521a2a59b3412a3eacd7f42fc.jpg", "jpg", 93465);
  danbooru_generate_coefficient_sql(dump, "images/5b4dd134e157491fa4af16693d46704b.jpg", "jpg", 17212);
  danbooru_generate_coefficient_sql(dump, "images/0f98146fe7a80ec21ecfad0ac96ccac7.jpg", "jpg", 19046);
  danbooru_generate_coefficient_sql(dump, "images/c441f3623bc5a7c58fd4afc9a6c2cf3f.jpg", "jpg", 87889);
  danbooru_generate_coefficient_sql(dump, "images/f2a67a99eff7679d26f3ff36a1a2610c.jpg", "jpg", 53976);
  danbooru_generate_coefficient_sql(dump, "images/2cbbaeda4e07b23bbcfd32f493846fd0.jpg", "jpg", 83953);
  danbooru_generate_coefficient_sql(dump, "images/e87ad7f92ef11c4502d992a8bf273863.jpg", "jpg", 83866);
  danbooru_generate_coefficient_sql(dump, "images/6ed015d284ba26373ddc11732d05cddf.jpg", "jpg", 69317);
  danbooru_generate_coefficient_sql(dump, "images/d6ae6a0c69474e64c465b1eee2361c94.png", "png", 20890);
  danbooru_generate_coefficient_sql(dump, "images/3b8c9cb572dba5d7c893414b3f1a4a38.jpg", "jpg", 104411);
  danbooru_generate_coefficient_sql(dump, "images/96746b4e0d00c3fac3c8553a8108c9b5.jpg", "jpg", 55071);
  danbooru_generate_coefficient_sql(dump, "images/69032d8fb888b99dae2bf52f4dec1df7.jpg", "jpg", 96018);
  danbooru_generate_coefficient_sql(dump, "images/e29e0f847f97d8d5b604eaa5c0d5ede1.jpg", "jpg", 120196);
  danbooru_generate_coefficient_sql(dump, "images/fe429bc3d5c90f2a80f483bb70d521d9.jpg", "jpg", 63350);
  danbooru_generate_coefficient_sql(dump, "images/8ec92a053ee39e137d25e4300bb87a6a.jpg", "jpg", 50707);
  danbooru_generate_coefficient_sql(dump, "images/b1bf1af7c485e91f0650369298fdf0a6.jpg", "jpg", 49184);
  danbooru_generate_coefficient_sql(dump, "images/11d2ba43474d71b3bbc935ff46971e34.jpg", "jpg", 836);
  danbooru_generate_coefficient_sql(dump, "images/12833509b96bd24b07edd00c1f420c30.jpg", "jpg", 9402);
  danbooru_generate_coefficient_sql(dump, "images/b0148afdfcaa53cd612ba457baaa15d1.jpg", "jpg", 26649);
  danbooru_generate_coefficient_sql(dump, "images/07eae0d13319c2bd5f9b5423d8d1f9c3.jpg", "jpg", 117313);
  danbooru_generate_coefficient_sql(dump, "images/0116b2ff93e7e85c3956b0de00daae47.jpg", "jpg", 68993);
  danbooru_generate_coefficient_sql(dump, "images/09ea9493766b616705033d8d2e91183f.jpg", "jpg", 96835);
  danbooru_generate_coefficient_sql(dump, "images/d7c8170950371207e0036873ff077a87.jpg", "jpg", 6095);
  danbooru_generate_coefficient_sql(dump, "images/e9c628f7f2a85e7c523bdce6f94f9c17.jpg", "jpg", 77629);
  danbooru_generate_coefficient_sql(dump, "images/bfd6daf66418fb18664ea5132710bd3e.jpg", "jpg", 20666);
  danbooru_generate_coefficient_sql(dump, "images/13780dcce6bc7081e167209abc3987e4.jpg", "jpg", 23720);
  danbooru_generate_coefficient_sql(dump, "images/d9be09710fcd6970e278afb13bc94b4c.jpg", "jpg", 102456);
  danbooru_generate_coefficient_sql(dump, "images/4ca9e1961314e2b3585c73cf7a2e950d.jpg", "jpg", 139865);
  danbooru_generate_coefficient_sql(dump, "images/3d8a44cc058f0b40979e712c136ea84a.jpg", "jpg", 3272);
  danbooru_generate_coefficient_sql(dump, "images/9c90ce53625b240c92ebbf459bae0c27.jpg", "jpg", 52262);
  danbooru_generate_coefficient_sql(dump, "images/db47447c220b3c7ad463047a80d8e706.jpg", "jpg", 129343);
  danbooru_generate_coefficient_sql(dump, "images/f009551023154dfc604b2db0b3b8a152.jpg", "jpg", 39738);
  danbooru_generate_coefficient_sql(dump, "images/22148e5b82c88d5b5bd028f0f9543f1f.jpg", "jpg", 29692);
  danbooru_generate_coefficient_sql(dump, "images/2d1f8b802b2c38f420c910c7489b0c6a.jpg", "jpg", 94491);
  danbooru_generate_coefficient_sql(dump, "images/fb6aa5e91348f8b3378106396716a4f0.jpg", "jpg", 38568);
  danbooru_generate_coefficient_sql(dump, "images/68d38f08af029c4483524bb13c9056e7.jpg", "jpg", 118840);
  danbooru_generate_coefficient_sql(dump, "images/60fc8657899a9570584fc60b57aae41c.jpg", "jpg", 70712);
  danbooru_generate_coefficient_sql(dump, "images/9169fc773edea72219662892b15230ca.jpg", "jpg", 58573);
  danbooru_generate_coefficient_sql(dump, "images/87555394b2eafbe7ee1b3cb7741006f1.jpg", "jpg", 61616);
  danbooru_generate_coefficient_sql(dump, "images/0e3839aa65277914347b61d2bbeb4430.jpg", "jpg", 9530);
  danbooru_generate_coefficient_sql(dump, "images/ca7729d3ebab1c4ad26d80107fd3f8b1.jpg", "jpg", 3431);
  danbooru_generate_coefficient_sql(dump, "images/1da0fa2a85c14fa9da8345df9d763895.jpg", "jpg", 125077);
  danbooru_generate_coefficient_sql(dump, "images/85957f2718d0f3aeb69e27db9ca7860c.jpg", "jpg", 91930);
  danbooru_generate_coefficient_sql(dump, "images/70233ddc813fc977921ab8c7192342f3.jpg", "jpg", 6157);
  danbooru_generate_coefficient_sql(dump, "images/baeb0350012fc29f5dbfbdafaf7cc307.jpg", "jpg", 55407);
  danbooru_generate_coefficient_sql(dump, "images/4e00b2ad27d7a45f567acaf5cdadd40d.jpg", "jpg", 125110);
  danbooru_generate_coefficient_sql(dump, "images/3503b90b932bf98a8d586dc149ce86b0.jpg", "jpg", 115652);
  danbooru_generate_coefficient_sql(dump, "images/3bd810eb47cdbd26cf24ddeb3fc52a35.jpg", "jpg", 108707);
  danbooru_generate_coefficient_sql(dump, "images/04cc6fe41822fc8531d5afefcfcce23f.jpg", "jpg", 16340);
  danbooru_generate_coefficient_sql(dump, "images/a64a17eae58e00381b0dc8768868fb94.jpg", "jpg", 43572);
  danbooru_generate_coefficient_sql(dump, "images/0fdb9296a52ee616c31542a7723eab35.jpg", "jpg", 35107);
  danbooru_generate_coefficient_sql(dump, "images/7f086b3588e8b24c476b9306ee9de08f.jpg", "jpg", 113013);
  danbooru_generate_coefficient_sql(dump, "images/810a20348adfe33d1d35b5edfb8d5262.jpg", "jpg", 37524);
  danbooru_generate_coefficient_sql(dump, "images/cef6e9a8e6358b19d75d89bc166956f8.jpg", "jpg", 85243);
  danbooru_generate_coefficient_sql(dump, "images/4c332f0841d6e02eeb4fda9decd5988d.jpg", "jpg", 77249);
  danbooru_generate_coefficient_sql(dump, "images/3f2af98697d4a20873263f48f1100adb.png", "png", 84942);
  danbooru_generate_coefficient_sql(dump, "images/53e9f3d7657d10bf650acb9dd3c606c3.jpg", "jpg", 57683);
  danbooru_generate_coefficient_sql(dump, "images/d02695fe04f67c80221c12e82d28a37a.jpg", "jpg", 119592);
  danbooru_generate_coefficient_sql(dump, "images/3d501deca3f7e072a7a2fb06826ac92e.jpg", "jpg", 134013);
  danbooru_generate_coefficient_sql(dump, "images/999fa9cb63eaff96265a7716ae4f73d8.jpg", "jpg", 33554);
  danbooru_generate_coefficient_sql(dump, "images/e920f2294ed6e9daef733f9019689a6e.jpg", "jpg", 83846);
  danbooru_generate_coefficient_sql(dump, "images/2b55f1ca88d7f3e935574106c9ea7e2d.jpg", "jpg", 64295);
  danbooru_generate_coefficient_sql(dump, "images/60149b37c2eefc7a0784aec227f989f2.jpg", "jpg", 61427);
  danbooru_generate_coefficient_sql(dump, "images/b5617937bbcad586d87df189d8b7eac1.png", "png", 20207);
  danbooru_generate_coefficient_sql(dump, "images/ae79609b9c63db491e28f2782538a8c0.jpg", "jpg", 52764);
  danbooru_generate_coefficient_sql(dump, "images/4c202f73d3acc1e7bd3baa79598e86d6.jpg", "jpg", 15852);
  danbooru_generate_coefficient_sql(dump, "images/042e9cf1319592538f6e5253d336efb0.jpg", "jpg", 75284);
  danbooru_generate_coefficient_sql(dump, "images/313d89dbb25a9478fbd6d87f9358affc.jpg", "jpg", 5328);
  danbooru_generate_coefficient_sql(dump, "images/2dacfe10fe73e4710a7840c5925bbf89.jpg", "jpg", 33650);
  danbooru_generate_coefficient_sql(dump, "images/35a1b92d53949c8c22f8b4101c050b9c.jpg", "jpg", 39886);
  danbooru_generate_coefficient_sql(dump, "images/7f7e10ed4f3bf3721683ca530543ff3c.jpg", "jpg", 107121);
  danbooru_generate_coefficient_sql(dump, "images/da153b7f51f2d5de6fa2257c37dedaa1.gif", "gif", 35656);
  danbooru_generate_coefficient_sql(dump, "images/ed566b901ae17314bfff1b5c008b2f39.gif", "gif", 44197);
  danbooru_generate_coefficient_sql(dump, "images/f0ad8b54b28a4dfe2489d42700b6cc52.jpg", "jpg", 78144);
  danbooru_generate_coefficient_sql(dump, "images/362206d5d4d84755fca6764b59c68544.jpg", "jpg", 86673);
  danbooru_generate_coefficient_sql(dump, "images/38f1bea2db08ba602c70fe0f26fc8d38.jpg", "jpg", 57289);
  danbooru_generate_coefficient_sql(dump, "images/d8d514d27b551470eeb52bf4c6ceb6e8.jpg", "jpg", 7270);
  danbooru_generate_coefficient_sql(dump, "images/b3c9fe8a45865793f82685e48d8cdcfa.jpg", "jpg", 80557);
  danbooru_generate_coefficient_sql(dump, "images/2e87ffcef1ff2161d5c7a2abec98f72a.jpg", "jpg", 44960);
  danbooru_generate_coefficient_sql(dump, "images/69a88b067e1ded093381b783bc613100.jpg", "jpg", 29160);
  danbooru_generate_coefficient_sql(dump, "images/089fdbd5e0e5aa2c46e49f643f831e39.jpg", "jpg", 106852);
  danbooru_generate_coefficient_sql(dump, "images/225e7c37ff2af80f6e6ba368998fbdba.jpg", "jpg", 32293);
  danbooru_generate_coefficient_sql(dump, "images/be385b9c29a62240cb9a8b553484778f.jpg", "jpg", 1775);
  danbooru_generate_coefficient_sql(dump, "images/b219cfd2d627c24f0ab61c566ffab7fa.jpg", "jpg", 83473);
  danbooru_generate_coefficient_sql(dump, "images/b6d16cee849419a22c691ee675072324.jpg", "jpg", 86906);
  danbooru_generate_coefficient_sql(dump, "images/d5500127c0ae40d0008844b77f075892.png", "png", 25398);
  danbooru_generate_coefficient_sql(dump, "images/38cb8fceac518f52616aec1eb62913c8.jpg", "jpg", 21565);
  danbooru_generate_coefficient_sql(dump, "images/5d181a02ccf21d8c0ff2414c4aca07ac.jpg", "jpg", 77537);
  danbooru_generate_coefficient_sql(dump, "images/ee3a919d2652498138835cc87d0f7255.jpg", "jpg", 38048);
  danbooru_generate_coefficient_sql(dump, "images/a55e08b8b0c568415d75fe0af28162f7.jpg", "jpg", 52960);
  danbooru_generate_coefficient_sql(dump, "images/b6791c9862fa94dea42adc807be56de1.jpg", "jpg", 95872);
  danbooru_generate_coefficient_sql(dump, "images/b10dcc0697dbe81b9e6388a0715ac0db.jpg", "jpg", 47075);
  danbooru_generate_coefficient_sql(dump, "images/e780c583efae50a6475bee942693a839.gif", "gif", 10870);
  danbooru_generate_coefficient_sql(dump, "images/41f05cd4f17bca21f23f695e37551a72.jpg", "jpg", 23271);
  danbooru_generate_coefficient_sql(dump, "images/3b609880e5b82c3d167f2155e0bcad3d.jpg", "jpg", 71659);
  danbooru_generate_coefficient_sql(dump, "images/805db7b496b96319b8c2f0c3ba3120b6.jpg", "jpg", 31089);
  danbooru_generate_coefficient_sql(dump, "images/a2a2d27f983773876c00c98934a248d1.jpg", "jpg", 85123);
  danbooru_generate_coefficient_sql(dump, "images/759896b17899c4898ca60cd0b753090a.jpg", "jpg", 26634);
  danbooru_generate_coefficient_sql(dump, "images/e75b304a0759c62946a8ffc2c9c4d286.jpg", "jpg", 101378);
  danbooru_generate_coefficient_sql(dump, "images/83f83c32c986c287bb2ab437a798a488.jpg", "jpg", 115735);
  danbooru_generate_coefficient_sql(dump, "images/d91d2d5a38f79aef72dfac5c17bb40b5.jpg", "jpg", 16404);
  danbooru_generate_coefficient_sql(dump, "images/625fe2d926516e9609da2f01b99160fb.jpg", "jpg", 136773);
  danbooru_generate_coefficient_sql(dump, "images/014b6428d966541681cd2f0280b9ba35.jpg", "jpg", 73391);
  danbooru_generate_coefficient_sql(dump, "images/b720301681067932991a9fdb76209e54.jpg", "jpg", 87955);
  danbooru_generate_coefficient_sql(dump, "images/4dedd53b7fd7f4749a2e2e19ba6dbffe.jpg", "jpg", 38247);
  danbooru_generate_coefficient_sql(dump, "images/e696ceda471cd9c28f0c7e50639f8c65.jpg", "jpg", 141611);
  danbooru_generate_coefficient_sql(dump, "images/9c170b931c493e6c96c8082f48ebba6e.jpg", "jpg", 113493);
  danbooru_generate_coefficient_sql(dump, "images/e7b2b71bedcc057d8a484a5cd121a40a.jpg", "jpg", 103661);
  danbooru_generate_coefficient_sql(dump, "images/6e2db2995a690850cbaf25e35c4c9c2b.jpeg", "jpg", 127700);
  danbooru_generate_coefficient_sql(dump, "images/8a0a74e4b0b582ddaa01312b359bdc69.gif", "gif", 68733);
  danbooru_generate_coefficient_sql(dump, "images/310fd972bba45351652dd51ea4f7df4b.jpg", "jpg", 95726);
  danbooru_generate_coefficient_sql(dump, "images/51b3c351a2855985dea06b204537bfcd.jpg", "jpg", 1354);
  danbooru_generate_coefficient_sql(dump, "images/67b76d6443875d4d2bba0004fed1aee6.jpg", "jpg", 134855);
  danbooru_generate_coefficient_sql(dump, "images/884124c150a6fd0f7ec0a062b568b4b6.jpeg", "jpg", 116046);
  danbooru_generate_coefficient_sql(dump, "images/93cb8600288ca89ffae25fcc41ff7c4a.jpg", "jpg", 27520);
  danbooru_generate_coefficient_sql(dump, "images/e5734e6a71e051a218e1e77feb4b798f.jpg", "jpg", 97052);
  danbooru_generate_coefficient_sql(dump, "images/dc02bf1c15b8e3dc04c515db335fa4f7.jpg", "jpg", 75416);
  danbooru_generate_coefficient_sql(dump, "images/18b54c47c3528780bc59ae9ab8ca1c31.jpg", "jpg", 78540);
  danbooru_generate_coefficient_sql(dump, "images/fdc8ddad7dc403454ed6cc183a0b6771.jpg", "jpg", 92032);
  danbooru_generate_coefficient_sql(dump, "images/c30366721e02bbb836454921ec67ef10.gif", "gif", 71645);
  danbooru_generate_coefficient_sql(dump, "images/04bf9def8b63a470dd09c19af788c10a.jpg", "jpg", 111685);
  danbooru_generate_coefficient_sql(dump, "images/2cec444e02d9914076bb40c6c1522e90.gif", "gif", 24423);
  danbooru_generate_coefficient_sql(dump, "images/3a21e14b6e0b0ae6a1b9afbd77573d65.jpg", "jpg", 51059);
  danbooru_generate_coefficient_sql(dump, "images/d3dfde828c7dc64501347cec95fee3e8.jpg", "jpg", 115707);
  danbooru_generate_coefficient_sql(dump, "images/fb2dfa8b2235c6b6c4fc268d51d1a72a.gif", "gif", 89192);
  danbooru_generate_coefficient_sql(dump, "images/c7dc68bcf800fb097d1043ea1a7bc777.jpg", "jpg", 52794);
  danbooru_generate_coefficient_sql(dump, "images/a8d90b41f6556db1e4d019c923aad29b.jpg", "jpg", 113004);
  danbooru_generate_coefficient_sql(dump, "images/d304c6425b95d8024ec91d89774a758f.jpg", "jpg", 86185);
  danbooru_generate_coefficient_sql(dump, "images/0cf182066a487c97ddb1cb19a1afed5d.jpg", "jpg", 8509);
  danbooru_generate_coefficient_sql(dump, "images/830f274e8bfbad3ffedabb10cb065e64.jpg", "jpg", 103007);
  danbooru_generate_coefficient_sql(dump, "images/4d68f9e6bc2024a60ba628a18dae028a.jpg", "jpg", 58176);
  danbooru_generate_coefficient_sql(dump, "images/0dce3fa4224ef4131093c6ee0ec781a8.jpg", "jpg", 65302);
  danbooru_generate_coefficient_sql(dump, "images/5e4d0b58cd57d7eb6bab39651caed366.jpg", "jpg", 117042);
  danbooru_generate_coefficient_sql(dump, "images/81c602c7424e1bc4ae117de7a69fd649.jpg", "jpg", 68775);
  danbooru_generate_coefficient_sql(dump, "images/8ea14196833e611c39f16f504daedbc0.jpg", "jpg", 141830);
  danbooru_generate_coefficient_sql(dump, "images/d42161cbc14411863c755bf3fa3a63e1.jpg", "jpg", 40119);
  danbooru_generate_coefficient_sql(dump, "images/a0bc84b9ee3eea402ee57cf5512514bf.jpg", "jpg", 135305);
  danbooru_generate_coefficient_sql(dump, "images/9cdee934756f0ef746d7d1bcbdc93a7d.jpg", "jpg", 62297);
  danbooru_generate_coefficient_sql(dump, "images/6308150a1d167d1da12bed35c4d3e5a9.jpg", "jpg", 114501);
  danbooru_generate_coefficient_sql(dump, "images/f16f390cc6323b1698cdfa5d9ba49bdb.jpg", "jpg", 104012);
  danbooru_generate_coefficient_sql(dump, "images/231adcc218c72bc215a0d306b7aa9dfe.jpg", "jpg", 2783);
  danbooru_generate_coefficient_sql(dump, "images/7abaf345156532df1bab0083ecb38976.jpg", "jpg", 73836);
  danbooru_generate_coefficient_sql(dump, "images/b84573e8d6fc71e15ef0dc972018a3e5.jpg", "jpg", 44418);
  danbooru_generate_coefficient_sql(dump, "images/580b5a0ddce2b2e1f475f97da1a3b5d4.jpg", "jpg", 102860);
  danbooru_generate_coefficient_sql(dump, "images/965dd3d4b4f97219413df7011a843e04.jpg", "jpg", 91569);
  danbooru_generate_coefficient_sql(dump, "images/55d1e334d84fec916a23ff970369eadd.jpg", "jpg", 49051);
  danbooru_generate_coefficient_sql(dump, "images/72890a9ca23cb6532bc001c39d40a601.jpg", "jpg", 21736);
  danbooru_generate_coefficient_sql(dump, "images/4c8d3a0f525c71e0cf9a2b29c0ce24e8.jpg", "jpg", 46856);
  danbooru_generate_coefficient_sql(dump, "images/0743c5604af192a7985b0b0276b3dcd5.jpg", "jpg", 98339);
  danbooru_generate_coefficient_sql(dump, "images/e0d6da84df96168dc6e797bf71cdf9c4.jpg", "jpg", 16912);
  danbooru_generate_coefficient_sql(dump, "images/e42ac480d43c79aa015e86522e45fc6b.jpg", "jpg", 51653);
  danbooru_generate_coefficient_sql(dump, "images/7061f1c5c1509335105b7a649fdc570f.jpg", "jpg", 14242);
  danbooru_generate_coefficient_sql(dump, "images/13dde4d02ee029caf60a0ded1879051b.jpg", "jpg", 100547);
  danbooru_generate_coefficient_sql(dump, "images/51d9ed6b2c6646a8bf621e02744cfd78.jpg", "jpg", 55642);
  danbooru_generate_coefficient_sql(dump, "images/c3c0ee4b036e568a8de782a89bfb0887.jpg", "jpg", 70580);
  danbooru_generate_coefficient_sql(dump, "images/09391463cd3f89874b247f2866823815.jpg", "jpg", 122403);
  danbooru_generate_coefficient_sql(dump, "images/dacad4e4456c6f852ed3f637873d0d08.jpg", "jpg", 73693);
  danbooru_generate_coefficient_sql(dump, "images/8fc88b704ceee51837c93aee44e9407a.jpg", "jpg", 91472);
  danbooru_generate_coefficient_sql(dump, "images/833bc82be51d53f015c335090630c856.jpg", "jpg", 114778);
  danbooru_generate_coefficient_sql(dump, "images/a04f219c98ad8a22d157c99eb279b24f.gif", "gif", 56816);
  danbooru_generate_coefficient_sql(dump, "images/2b8b97566dcbeab8c04c8606d9f91c97.jpg", "jpg", 117696);
  danbooru_generate_coefficient_sql(dump, "images/bb106dc98274ea2c6d831e7ccae24e70.jpg", "jpg", 48411);
  danbooru_generate_coefficient_sql(dump, "images/23a683ce234cfed2e1eac8abe9392e71.jpg", "jpg", 1981);
  danbooru_generate_coefficient_sql(dump, "images/4c607baeb09d1c84efeac35ad4ead844.jpg", "jpg", 24090);
  danbooru_generate_coefficient_sql(dump, "images/7419e055849df629d07cd519c4a35411.jpg", "jpg", 25876);
  danbooru_generate_coefficient_sql(dump, "images/345913a8f8eae55fb31a40c1bd284ac7.jpg", "jpg", 136129);
  danbooru_generate_coefficient_sql(dump, "images/da51129e29a6ad41e3ef88cce347066c.jpg", "jpg", 122368);
  danbooru_generate_coefficient_sql(dump, "images/e7d1d74a966b9be741ac82da605b946b.jpg", "jpg", 75244);
  danbooru_generate_coefficient_sql(dump, "images/69ccd8259ff1c7691ce2353b401856bb.jpg", "jpg", 13162);
  danbooru_generate_coefficient_sql(dump, "images/ff47073fcfce6c60986a33fbb9533d09.jpg", "jpg", 46410);
  danbooru_generate_coefficient_sql(dump, "images/c9c2ac09e29ceaaaecbcc690d5550d48.jpg", "jpg", 92110);
  danbooru_generate_coefficient_sql(dump, "images/a9833cda8378ff6ffd13de95651d214c.jpg", "jpg", 120293);
  danbooru_generate_coefficient_sql(dump, "images/f49e60803b658034367cad57f87e9ddc.jpg", "jpg", 38450);
  danbooru_generate_coefficient_sql(dump, "images/2f204ceb093b9bf5a0cae3bdf23e807f.jpg", "jpg", 16294);
  danbooru_generate_coefficient_sql(dump, "images/88238fd008f3ad5a3103362994d6f65c.jpg", "jpg", 95751);
  danbooru_generate_coefficient_sql(dump, "images/0b40183923e6f69e04bc6f98d75115e0.jpg", "jpg", 25568);
  danbooru_generate_coefficient_sql(dump, "images/649d42173b49d137b996a744b57f0f11.jpg", "jpg", 94319);
  danbooru_generate_coefficient_sql(dump, "images/4de9b9dd3b477687ed18f16bd11bd3e5.jpg", "jpg", 85615);
  danbooru_generate_coefficient_sql(dump, "images/1ecad926f75535520c588e1eb9748b86.jpg", "jpg", 95634);
  danbooru_generate_coefficient_sql(dump, "images/8bedec4aff6bc0b2462394af9a8d4237.jpg", "jpg", 99855);
  danbooru_generate_coefficient_sql(dump, "images/7d28872d1ed6913db17b2fb8b80845a9.gif", "gif", 98055);
  danbooru_generate_coefficient_sql(dump, "images/b23f60ef5c7a3548387dd2e401969af3.png", "png", 91484);
  danbooru_generate_coefficient_sql(dump, "images/a9e1fa266bdfb4557d426e05f6bdc061.gif", "gif", 20942);
  danbooru_generate_coefficient_sql(dump, "images/eba2da496f35cea268491033e3df8ea2.jpg", "jpg", 120735);
  danbooru_generate_coefficient_sql(dump, "images/1007145ac6faf9e9a76de1dea06aec75.jpg", "jpg", 40385);
  danbooru_generate_coefficient_sql(dump, "images/a1f2eedd416064831f6c45f4ad6cb43b.gif", "gif", 141023);
  danbooru_generate_coefficient_sql(dump, "images/13c62d800b7da812911a4148e7fd0f3e.jpg", "jpg", 121591);
  danbooru_generate_coefficient_sql(dump, "images/61593cb4c133fb53d9c35a0e0021e191.jpg", "jpg", 13999);
  danbooru_generate_coefficient_sql(dump, "images/a915c8574a3a3e5de47396fe6fb4830e.png", "png", 2039);
  danbooru_generate_coefficient_sql(dump, "images/d90e491174bb544dfbd2382045529c57.jpg", "jpg", 86129);
  danbooru_generate_coefficient_sql(dump, "images/6ef5347a0b4b8afe683de096ef21c65a.jpg", "jpg", 36661);
  danbooru_generate_coefficient_sql(dump, "images/bbbdeac44cb9557e42a1567005b21ee6.jpg", "jpg", 69690);
  danbooru_generate_coefficient_sql(dump, "images/c8673276978b6dd3bfa6180410e19c83.jpg", "jpg", 12835);
  danbooru_generate_coefficient_sql(dump, "images/3f659ca789e8b1f846348b378b7930c0.jpg", "jpg", 5264);
  danbooru_generate_coefficient_sql(dump, "images/b20669b3145f2fca1561893e32f0225e.jpg", "jpg", 61981);
  danbooru_generate_coefficient_sql(dump, "images/4e3ef2196ac40d131ce4ba5bcba00edb.png", "png", 62336);
  danbooru_generate_coefficient_sql(dump, "images/19682b6ddba202d2837d88c0ea5011eb.jpg", "jpg", 129017);
  danbooru_generate_coefficient_sql(dump, "images/169d267addcdc1c9ea82cce573e8b019.jpg", "jpg", 56150);
  danbooru_generate_coefficient_sql(dump, "images/9b301578b304428ee7bfae5cfb8235df.jpg", "jpg", 13324);
  danbooru_generate_coefficient_sql(dump, "images/1db77ec20534fedff172aba28055b652.jpg", "jpg", 31649);
  danbooru_generate_coefficient_sql(dump, "images/684f82e79302ad0ab930a3d7b267f004.jpg", "jpg", 11138);
  danbooru_generate_coefficient_sql(dump, "images/8cd22b4fd020f3ebf95cc81769da35b8.jpg", "jpg", 134395);
  danbooru_generate_coefficient_sql(dump, "images/9c268b809ce13f8e7587c4e351889493.jpg", "jpg", 86423);
  danbooru_generate_coefficient_sql(dump, "images/cbafc5d69c2b6a1622ec184c3ee1ea3c.jpg", "jpg", 63976);
  danbooru_generate_coefficient_sql(dump, "images/be0348e42c46537336ebbb87d33065c6.jpeg", "jpg", 136931);
  danbooru_generate_coefficient_sql(dump, "images/ac8860338eb4e2dd5bc508806873d165.jpg", "jpg", 8222);
  danbooru_generate_coefficient_sql(dump, "images/ea450ad57815a07f3860ec007c701195.jpg", "jpg", 82920);
  danbooru_generate_coefficient_sql(dump, "images/a04f20210c480b385b10094023448486.jpg", "jpg", 99497);
  danbooru_generate_coefficient_sql(dump, "images/7e7576ca2206b8543ffdd24a8e1da462.jpg", "jpg", 128268);
  danbooru_generate_coefficient_sql(dump, "images/3f6afd91cd2a8f1bd8ef8b1302c0b24c.jpg", "jpg", 6712);
  danbooru_generate_coefficient_sql(dump, "images/f6e5541d60da568711d2672cac8df75f.jpg", "jpg", 65405);
  danbooru_generate_coefficient_sql(dump, "images/7e45edd021206cf7a107e8b2bc36794b.jpg", "jpg", 30682);
  danbooru_generate_coefficient_sql(dump, "images/c86d64a60482c6af1dfefac5102d7a4c.jpg", "jpg", 84365);
  danbooru_generate_coefficient_sql(dump, "images/edda34bfe60cac18d9ce2b85170a42c9.jpg", "jpg", 108492);
  danbooru_generate_coefficient_sql(dump, "images/c24aab5d90995b142e27282a2e1f05f2.jpg", "jpg", 128729);
  danbooru_generate_coefficient_sql(dump, "images/0025d7cd9721b27a624954218a2201d3.jpg", "jpg", 140894);
  danbooru_generate_coefficient_sql(dump, "images/71fb60c88e78c5790572b6827d7d8c40.jpg", "jpg", 57563);
  danbooru_generate_coefficient_sql(dump, "images/5002ffce140c4a84de0c85b46dc6d48a.jpg", "jpg", 37383);
  danbooru_generate_coefficient_sql(dump, "images/18b3a71db675384db77823f804b45b89.jpg", "jpg", 74912);
  danbooru_generate_coefficient_sql(dump, "images/54f9b19849c6e20205e61fed9a7045a6.jpg", "jpg", 107174);
  danbooru_generate_coefficient_sql(dump, "images/9275d2955d369b9bb7daff9c5accac59.jpg", "jpg", 71464);
  danbooru_generate_coefficient_sql(dump, "images/a38c93c34b3cd2775f08261daf25cf06.jpg", "jpg", 20280);
  danbooru_generate_coefficient_sql(dump, "images/b1a78cc1056d196f76ab394368bfc8e5.jpg", "jpg", 57744);
  danbooru_generate_coefficient_sql(dump, "images/bd83a047d539a7763685ece721ce9c8c.jpg", "jpg", 58239);
  danbooru_generate_coefficient_sql(dump, "images/bf840c035ff5dc9e7d87fa2f755d54d2.jpg", "jpg", 46291);
  danbooru_generate_coefficient_sql(dump, "images/6a1c4eee02f6db79d9726bcca98a6a1a.jpg", "jpg", 126475);
  danbooru_generate_coefficient_sql(dump, "images/cd17bbe74f06b1713a152dd3d9fa1e1d.jpg", "jpg", 17953);
  danbooru_generate_coefficient_sql(dump, "images/fa9235bea65151145cfe36c76bc88de2.jpg", "jpg", 81136);
  danbooru_generate_coefficient_sql(dump, "images/be1a8c80806328c9182907ccfd1c0f48.jpg", "jpg", 116326);
  danbooru_generate_coefficient_sql(dump, "images/900cfd0f4250059995bec9a66b0cc818.jpg", "jpg", 45054);
  danbooru_generate_coefficient_sql(dump, "images/83c2f71b7a4ab7694a8bf28bd1a5b422.jpg", "jpg", 38834);
  danbooru_generate_coefficient_sql(dump, "images/5b9f4486d93122d44d1d6c5e9fd5918a.jpg", "jpg", 104);
  danbooru_generate_coefficient_sql(dump, "images/dee0a5731106e7f835ed510b14bd4590.jpg", "jpg", 135216);
  danbooru_generate_coefficient_sql(dump, "images/66369d4375f51ccb6e20b6341ef680fa.jpg", "jpg", 8835);
  danbooru_generate_coefficient_sql(dump, "images/229d3a475898a83d065f0877c5c1a362.jpg", "jpg", 30644);
  danbooru_generate_coefficient_sql(dump, "images/706233d269dea6281557053a3b77b565.jpg", "jpg", 62360);
  danbooru_generate_coefficient_sql(dump, "images/1bb4f35109aa2986f023dfe12f97767e.png", "png", 102571);
  danbooru_generate_coefficient_sql(dump, "images/2a66a80cec43cfa8a30eeb9fd1726b13.jpg", "jpg", 56060);
  danbooru_generate_coefficient_sql(dump, "images/41f9540e0528e013a0aac1ece87a0579.jpg", "jpg", 98715);
  danbooru_generate_coefficient_sql(dump, "images/32f56b247d44eee7f0ddac6f5a0c7e37.jpg", "jpg", 53147);
  danbooru_generate_coefficient_sql(dump, "images/8c5d9ac686468ba35a78df985f4bde82.jpg", "jpg", 96634);
  danbooru_generate_coefficient_sql(dump, "images/d188cc2c21cdafca3faa45b1f1647031.jpg", "jpg", 125835);
  danbooru_generate_coefficient_sql(dump, "images/9947f17323f53c0cffafd16f612c12b2.gif", "gif", 125572);
  danbooru_generate_coefficient_sql(dump, "images/0723ec34ca4c1646437ed4a4a9ac471e.jpg", "jpg", 121288);
  danbooru_generate_coefficient_sql(dump, "images/1cac37dd7b250831ef14a0318356272d.jpg", "jpg", 87546);
  danbooru_generate_coefficient_sql(dump, "images/e56b6288c89d1bc8ad3cb990dacc591b.jpg", "jpg", 12361);
  danbooru_generate_coefficient_sql(dump, "images/8297cc82220ec0a42b542a07727ffeda.png", "png", 88893);
  danbooru_generate_coefficient_sql(dump, "images/a0ba186082a8e296fafd44d8a1110876.jpg", "jpg", 55797);
  danbooru_generate_coefficient_sql(dump, "images/4d0d1a03a6df2cf09439534837be745e.jpg", "jpg", 128003);
  danbooru_generate_coefficient_sql(dump, "images/514ff9435aedfbaf9a7d2791a498364e.jpg", "jpg", 5114);
  danbooru_generate_coefficient_sql(dump, "images/3c2c6b6e49f969a7253b9b25be8279d9.jpg", "jpg", 118486);
  danbooru_generate_coefficient_sql(dump, "images/d39a44e0eecd310b46ccc3f5d01171a5.jpg", "jpg", 113256);
  danbooru_generate_coefficient_sql(dump, "images/f435c7df29d2704da3ffe15933766a29.jpg", "jpg", 54362);
  danbooru_generate_coefficient_sql(dump, "images/b5fb49db0f8dd25603f63ae68fb50a92.jpg", "jpg", 80872);
  danbooru_generate_coefficient_sql(dump, "images/e951aae3c3a0ab2db60d534d5c15be96.jpg", "jpg", 86302);
  danbooru_generate_coefficient_sql(dump, "images/ec245fb71e85b48428adb629d97032a8.jpg", "jpg", 103592);
  danbooru_generate_coefficient_sql(dump, "images/400792ffd34d44f9e541506e03cf9121.jpg", "jpg", 22921);
  danbooru_generate_coefficient_sql(dump, "images/91238d727be1c8b1bd2ddc4396f445c1.jpg", "jpg", 95410);
  danbooru_generate_coefficient_sql(dump, "images/0400af2121daf7777a8fed739ad12487.jpg", "jpg", 138939);
  danbooru_generate_coefficient_sql(dump, "images/ff0666a58a70bd77282656f333a0797b.jpg", "jpg", 116437);
  danbooru_generate_coefficient_sql(dump, "images/e946c9b94632cb9ad790b4d7066d1067.gif", "gif", 117894);
  danbooru_generate_coefficient_sql(dump, "images/c7ddfd918ccac7bee70759044a578d82.jpg", "jpg", 113812);
  danbooru_generate_coefficient_sql(dump, "images/de7eb0925b55d957144fdce8322327f1.jpg", "jpg", 18022);
  danbooru_generate_coefficient_sql(dump, "images/aae2343fc809189946b98763fe648e61.jpg", "jpg", 74013);
  danbooru_generate_coefficient_sql(dump, "images/6290e27f74c08349319acd20ff3586a2.jpg", "jpg", 34417);
  danbooru_generate_coefficient_sql(dump, "images/0e3981165e4ae20ec73f54154e9de13e.jpg", "jpg", 81921);
  danbooru_generate_coefficient_sql(dump, "images/c7c3e4d411502a1431bb634fe93b170a.jpg", "jpg", 60939);
  danbooru_generate_coefficient_sql(dump, "images/1714fc4beae7aedbe9dbbd3b9a4b3e67.jpg", "jpg", 60753);
  danbooru_generate_coefficient_sql(dump, "images/c5aae01f2ee603e55a599a627bde4f58.jpg", "jpg", 54766);
  danbooru_generate_coefficient_sql(dump, "images/b8073a6eb2e6e902a5a3e88f6efb6013.jpg", "jpg", 30770);
  danbooru_generate_coefficient_sql(dump, "images/a7d0f570d9d22bd0ac616eb5869ce651.jpg", "jpg", 21234);
  danbooru_generate_coefficient_sql(dump, "images/c71af7510208f431b7d1123646a4d4a4.jpg", "jpg", 46187);
  danbooru_generate_coefficient_sql(dump, "images/4bdaf1badff940a8e8400fbb5770988c.jpg", "jpg", 103136);
  danbooru_generate_coefficient_sql(dump, "images/f1489bec1b7612e3fc951a639d54d178.jpg", "jpg", 32593);
  danbooru_generate_coefficient_sql(dump, "images/cd8716919ffd23cd6bba60027100c0a5.jpg", "jpg", 26581);
  danbooru_generate_coefficient_sql(dump, "images/3b8da03265ddfcd13226bf497a699e78.jpg", "jpg", 104312);
  danbooru_generate_coefficient_sql(dump, "images/6adc10aba8a3ce95fbbafaffa2488b7d.jpg", "jpg", 95148);
  danbooru_generate_coefficient_sql(dump, "images/ffd93e52f20b07d55ef3ff2b446096d0.jpg", "jpg", 102169);
  danbooru_generate_coefficient_sql(dump, "images/42926dfd277520889b0040419b116e48.jpg", "jpg", 112917);
  danbooru_generate_coefficient_sql(dump, "images/d133b81edbd2533378f33348a8eb9d1b.jpg", "jpg", 33496);
  danbooru_generate_coefficient_sql(dump, "images/681b4e90ac37948a8c3f675a0467f63b.jpg", "jpg", 1578);
  danbooru_generate_coefficient_sql(dump, "images/5a9a13db2a3cd2cca69153a5cf3a8307.jpg", "jpg", 98726);
  danbooru_generate_coefficient_sql(dump, "images/3ae73102f0c1d51007aae60309b77e86.jpg", "jpg", 47414);
  danbooru_generate_coefficient_sql(dump, "images/c4c11475351fe521fb8364d3e10cd34f.jpg", "jpg", 42342);
  danbooru_generate_coefficient_sql(dump, "images/28f619ca495d2caa520246f4fa03613b.gif", "gif", 96871);
  danbooru_generate_coefficient_sql(dump, "images/b1bc9bfd157fdc093c72230f9f7dbdfd.jpg", "jpg", 10585);
  danbooru_generate_coefficient_sql(dump, "images/70c05974ed5511151618d9a32ba6c605.jpg", "jpg", 21740);
  danbooru_generate_coefficient_sql(dump, "images/e46f48df1217b9120d5dbde0966de221.jpg", "jpg", 46746);
  danbooru_generate_coefficient_sql(dump, "images/0c147cd3982f5a00ec9b478f64e367d6.jpg", "jpg", 64530);
  danbooru_generate_coefficient_sql(dump, "images/c6dc6b037a6277272de3856237ebaa9b.jpg", "jpg", 97845);
  danbooru_generate_coefficient_sql(dump, "images/bda43f42897261b659963f61f569bb04.jpg", "jpg", 75691);
  danbooru_generate_coefficient_sql(dump, "images/183b4982d6c09179630a4759cee26f9d.jpg", "jpg", 134708);
  danbooru_generate_coefficient_sql(dump, "images/490dc2cefdb9821ec0cc23d702b1eb0d.jpg", "jpg", 14867);
  danbooru_generate_coefficient_sql(dump, "images/364132c76417b328fa92d379b4cbe93d.jpg", "jpg", 15166);
  danbooru_generate_coefficient_sql(dump, "images/c581ea99d89a1b35113df5144f322dc2.jpg", "jpg", 137401);
  danbooru_generate_coefficient_sql(dump, "images/5c4b103401119c9df6e71aa1fd51e42b.jpg", "jpg", 137466);
  danbooru_generate_coefficient_sql(dump, "images/2832d1f707237c479255085c67fd300a.jpg", "jpg", 128720);
  danbooru_generate_coefficient_sql(dump, "images/2e3cee6e1ce76c7cfec771c05c8ef0f0.jpg", "jpg", 17790);
  danbooru_generate_coefficient_sql(dump, "images/049f6863d5089ca740c9db1f983e9e55.jpg", "jpg", 142631);
  danbooru_generate_coefficient_sql(dump, "images/365e0b85e99d2de0b45bd4a9e6076e84.jpg", "jpg", 20427);
  danbooru_generate_coefficient_sql(dump, "images/5161e133ecb48c115d4beffba30f7448.jpg", "jpg", 20069);
  danbooru_generate_coefficient_sql(dump, "images/65cfdfc5f1acaa162fbc1edbe2bc3ed6.jpg", "jpg", 129430);
  danbooru_generate_coefficient_sql(dump, "images/a1f3d19787a2d897be6442fd743b56bd.jpg", "jpg", 101054);
  danbooru_generate_coefficient_sql(dump, "images/df23c80349fe1759400b804058ede187.jpeg", "jpg", 127188);
  danbooru_generate_coefficient_sql(dump, "images/849d127d409be2317b4b2ee4549671a7.jpg", "jpg", 126173);
  danbooru_generate_coefficient_sql(dump, "images/e292ba9d160edabe41ee226cbfb67cd6.jpg", "jpg", 113649);
  danbooru_generate_coefficient_sql(dump, "images/3472032e9fcd01f51ca14b7f945c79d8.jpg", "jpg", 71552);
  danbooru_generate_coefficient_sql(dump, "images/f14bba9bee39806d578aeed55916731d.jpg", "jpg", 99854);
  danbooru_generate_coefficient_sql(dump, "images/8afe2801e33f8b5172450ccdf46320c1.jpg", "jpg", 142206);
  danbooru_generate_coefficient_sql(dump, "images/9df6a17a512e1ca7df05f857b9adf64f.jpg", "jpg", 14293);
  danbooru_generate_coefficient_sql(dump, "images/ac03ac646480d90c9ad2c154f5dafe51.jpg", "jpg", 132227);
  danbooru_generate_coefficient_sql(dump, "images/fe574b6d3f158c444fc95c2e19720832.jpg", "jpg", 126015);
  danbooru_generate_coefficient_sql(dump, "images/f8f05536a06f8585fefb16e6364cd4f9.jpg", "jpg", 52335);
  danbooru_generate_coefficient_sql(dump, "images/34507137e3cfde62ff1a17e13f121cb2.gif", "gif", 39370);
  danbooru_generate_coefficient_sql(dump, "images/bb358ad68aba709ac70d6a0aa89a9740.jpg", "jpg", 69692);
  danbooru_generate_coefficient_sql(dump, "images/82b335051732a804145a02fcd44a74e5.jpeg", "jpg", 123219);
  danbooru_generate_coefficient_sql(dump, "images/fc6b6f9022b66d04616a7e9b87d5ae1c.jpg", "jpg", 92896);
  danbooru_generate_coefficient_sql(dump, "images/301c39ee54c792439d502461808c196c.jpg", "jpg", 1574);
  danbooru_generate_coefficient_sql(dump, "images/715f2f937d644000d3a8cca65fec1418.gif", "gif", 58296);
  danbooru_generate_coefficient_sql(dump, "images/21d1035598252f51bee31ab8281cbef4.jpg", "jpg", 116511);
  danbooru_generate_coefficient_sql(dump, "images/365936f597553e1fc1090f3e22b1120a.jpg", "jpg", 10131);
  danbooru_generate_coefficient_sql(dump, "images/f39824083c327c79e512feab7fcaf86b.jpg", "jpg", 28974);
  danbooru_generate_coefficient_sql(dump, "images/823c5c3d8491a71b7376cf0f4abaf739.jpg", "jpg", 8425);
  danbooru_generate_coefficient_sql(dump, "images/7baa5277f71f54fa7b5065515e291356.jpg", "jpg", 11530);
  danbooru_generate_coefficient_sql(dump, "images/1361cd833cb27b09666e78911a879177.jpg", "jpg", 69519);
  danbooru_generate_coefficient_sql(dump, "images/690ba8412b69ff75b321f0294aa56c64.jpeg", "jpg", 129859);
  danbooru_generate_coefficient_sql(dump, "images/51199a429cba4a4438a9b4ebc97f1ef9.jpg", "jpg", 86856);
  danbooru_generate_coefficient_sql(dump, "images/9d7a8ea7a6508cc3aebabc5b847a0596.jpg", "jpg", 62845);
  danbooru_generate_coefficient_sql(dump, "images/70f6e6a0215c8d8abf28dddc27c11ab6.jpg", "jpg", 49316);
  danbooru_generate_coefficient_sql(dump, "images/6de5a9470c16e00792c6788fc1bcd811.jpg", "jpg", 37571);
  danbooru_generate_coefficient_sql(dump, "images/f0a60f0d68562b674425f612e11daa87.jpg", "jpg", 2247);
  danbooru_generate_coefficient_sql(dump, "images/2a7695a4fed8b0beead86959363e7450.jpg", "jpg", 46284);
  danbooru_generate_coefficient_sql(dump, "images/e6a931a372df8a60484dd34ce2b6b980.jpg", "jpg", 27004);
  danbooru_generate_coefficient_sql(dump, "images/ea9a25020bc7b5c8a4c700788e77044b.png", "png", 84797);
  danbooru_generate_coefficient_sql(dump, "images/63a24661a389c8e18b9884da6fe2144e.jpg", "jpg", 42764);
  danbooru_generate_coefficient_sql(dump, "images/a26bccc895dac504d60aee989b33ef4c.jpg", "jpg", 92756);
  danbooru_generate_coefficient_sql(dump, "images/261c4565029f53893398088e1bfdbfdf.jpg", "jpg", 118517);
  danbooru_generate_coefficient_sql(dump, "images/36fb1359fa97fe7ee671e098a523e52c.jpg", "jpg", 131419);
  danbooru_generate_coefficient_sql(dump, "images/dc71d60e2d78f0b703536ff110978b1c.gif", "gif", 17620);
  danbooru_generate_coefficient_sql(dump, "images/6b4128eb91aa3b64c656cecb780070c0.jpeg", "jpg", 122513);
  danbooru_generate_coefficient_sql(dump, "images/355465484748791ac751f6a586a21f11.jpeg", "jpg", 128888);
  danbooru_generate_coefficient_sql(dump, "images/67bc4a4ea2b1b4ae4abf5aa003ef3c0a.jpg", "jpg", 67485);
  danbooru_generate_coefficient_sql(dump, "images/6623ffcc9aba77baff6f3fd049c01a2c.gif", "gif", 114395);
  danbooru_generate_coefficient_sql(dump, "images/726c7f504af0a9df1c08ffc09b17151c.jpg", "jpg", 121937);
  danbooru_generate_coefficient_sql(dump, "images/d0f7407fd7cc318e08ac515644502070.png", "png", 32313);
  danbooru_generate_coefficient_sql(dump, "images/3e23ae5a1aa0313852072840dbdadcfe.jpg", "jpg", 56841);
  danbooru_generate_coefficient_sql(dump, "images/f833ea9e24db2509d18752e9569ff816.jpg", "jpg", 65371);
  danbooru_generate_coefficient_sql(dump, "images/deed60402920b337712cfa9a32b68fef.jpg", "jpg", 92153);
  danbooru_generate_coefficient_sql(dump, "images/b534f8916640dc1a6ea79a9db734f1cb.jpg", "jpg", 6588);
  danbooru_generate_coefficient_sql(dump, "images/0453ccbf38ee92ec8826a8041c1db1ed.jpg", "jpg", 71141);
  danbooru_generate_coefficient_sql(dump, "images/94d20c2fb0859fe2daf35a1b56766c3c.gif", "gif", 50267);
  danbooru_generate_coefficient_sql(dump, "images/996d893724ea620448061cc3107873e0.jpg", "jpg", 39988);
  danbooru_generate_coefficient_sql(dump, "images/b355519c367b1b3fd1bfc85cfef77106.jpg", "jpg", 87863);
  danbooru_generate_coefficient_sql(dump, "images/d01efb27cc979206450263cb691798f8.jpg", "jpg", 136581);
  danbooru_generate_coefficient_sql(dump, "images/56bf07b63576bd68f07456c821cc791a.jpg", "jpg", 108496);
  danbooru_generate_coefficient_sql(dump, "images/80ad9988570221be6f8b1585e26dc928.jpg", "jpg", 14758);
  danbooru_generate_coefficient_sql(dump, "images/17dacbcbcde1edeea739840fbb612b37.jpg", "jpg", 85776);
  danbooru_generate_coefficient_sql(dump, "images/5c0a2ad58dbb149ec3b7a5f31578abad.jpg", "jpg", 49527);
  danbooru_generate_coefficient_sql(dump, "images/b638e6f1a4aa3ae7929dadedc4e7ce77.jpg", "jpg", 133120);
  danbooru_generate_coefficient_sql(dump, "images/3ab9359cdc24864969c6ba4251247a21.jpg", "jpg", 62317);
  danbooru_generate_coefficient_sql(dump, "images/1c97f97f1d533512d3bdb71415ed5e40.jpg", "jpg", 64158);
  danbooru_generate_coefficient_sql(dump, "images/6af09c22413cb75150f654b9a3f9a290.jpg", "jpg", 87072);
  danbooru_generate_coefficient_sql(dump, "images/766f9d55025f53144645a07dbf3e8321.jpg", "jpg", 12065);
  danbooru_generate_coefficient_sql(dump, "images/8ff58015b129ccb7c7670e880c34d9bb.jpg", "jpg", 61897);
  danbooru_generate_coefficient_sql(dump, "images/31f2b3cc225b31b4d13b389e95dc18b0.jpg", "jpg", 137300);
  danbooru_generate_coefficient_sql(dump, "images/d72610fbde0b14f516ca29765325a013.jpg", "jpg", 44140);
  danbooru_generate_coefficient_sql(dump, "images/8aaa0dd54aaab4c4e2e685ef32af9920.jpg", "jpg", 39643);
  danbooru_generate_coefficient_sql(dump, "images/dd339ae010ef48473b59b1c5245141f2.jpg", "jpg", 96183);
  danbooru_generate_coefficient_sql(dump, "images/4d0f60e2ff0a08bc0c14d28a4ef87337.jpg", "jpg", 59974);
  danbooru_generate_coefficient_sql(dump, "images/3715ef2b8c8ebd8e785ddf0b44f96554.jpg", "jpg", 135346);
  danbooru_generate_coefficient_sql(dump, "images/b73dcb99f4f03f1191920a62473ef6fc.png", "png", 35083);
  danbooru_generate_coefficient_sql(dump, "images/d80749f5ba44b5ebb6e20e0f8b0d1ca0.jpg", "jpg", 15795);
  danbooru_generate_coefficient_sql(dump, "images/d68756cbbcdb0cbd500bfc358a7313f8.jpg", "jpg", 105210);
  danbooru_generate_coefficient_sql(dump, "images/6a96773fe9b53c5eb0b9c42c595c227d.jpg", "jpg", 7586);
  danbooru_generate_coefficient_sql(dump, "images/715f6acb764a31371896ad9cbf764504.jpg", "jpg", 48843);
  danbooru_generate_coefficient_sql(dump, "images/1ccebad1f99510e4994afc10905d82d4.jpg", "jpg", 42233);
  danbooru_generate_coefficient_sql(dump, "images/d39b5b445d9e0a5fca28923a402d297d.jpg", "jpg", 102700);
  danbooru_generate_coefficient_sql(dump, "images/57fe51e0b3e6e02bb956b3661832b6dd.jpg", "jpg", 71338);
  danbooru_generate_coefficient_sql(dump, "images/248b5cdb4a3278b0319ec4a04855d742.png", "png", 8747);
  danbooru_generate_coefficient_sql(dump, "images/22a5b978b537cbefee66e6fc635c1ae5.jpg", "jpg", 62616);
  danbooru_generate_coefficient_sql(dump, "images/b460c983a7c890bb964613b8799c9b90.jpg", "jpg", 60373);
  danbooru_generate_coefficient_sql(dump, "images/e91e81edb1d1622e81b03e8f1fd601a8.jpg", "jpg", 136597);
  danbooru_generate_coefficient_sql(dump, "images/9cc07088b03201132aae2791643bed21.jpg", "jpg", 4182);
  danbooru_generate_coefficient_sql(dump, "images/109d60b75893a077b968995c2d28eb15.jpg", "jpg", 65382);
  danbooru_generate_coefficient_sql(dump, "images/c31dc2fd82859ba13128529e13dc4463.jpg", "jpg", 40771);
  danbooru_generate_coefficient_sql(dump, "images/b43b67e085d3ceed90f7d4bfa88fa680.jpg", "jpg", 127359);
  danbooru_generate_coefficient_sql(dump, "images/349908c6496c49ad69ca8fa50f36fe15.jpg", "jpg", 60140);
  danbooru_generate_coefficient_sql(dump, "images/25a6f839566c9aea428efa1e296822ee.gif", "gif", 105566);
  danbooru_generate_coefficient_sql(dump, "images/c7c87ed1d8ec77ba685d121f0008fbd6.jpg", "jpg", 114871);
  danbooru_generate_coefficient_sql(dump, "images/554b91b6f6cc18f7dd0144068a70f4f2.jpg", "jpg", 91637);
  danbooru_generate_coefficient_sql(dump, "images/1e7146a3d24ad00b4bad172e20237226.jpg", "jpg", 125036);
  danbooru_generate_coefficient_sql(dump, "images/2d65352be966d5253b9f61bfedf619f1.jpg", "jpg", 18159);
  danbooru_generate_coefficient_sql(dump, "images/79f2131cb39c748b441f7b6b643ad915.jpg", "jpg", 84821);
  danbooru_generate_coefficient_sql(dump, "images/ed95acac56bd776fad501b7cc4980294.jpg", "jpg", 57804);
  danbooru_generate_coefficient_sql(dump, "images/97d476e7b47a389539f54f94a2c05c16.jpeg", "jpg", 138954);
  danbooru_generate_coefficient_sql(dump, "images/1dc842a4fec1401e24e6b33d5308e736.png", "png", 107436);
  danbooru_generate_coefficient_sql(dump, "images/0ccfb54b080fdfa6214017b9ed8d09c3.jpg", "jpg", 97956);
  danbooru_generate_coefficient_sql(dump, "images/ac54eae51bebd0659083a99747605089.jpg", "jpg", 29783);
  danbooru_generate_coefficient_sql(dump, "images/0e1a039a57544987cbd336fecee6cb30.jpg", "jpg", 77401);
  danbooru_generate_coefficient_sql(dump, "images/a50715f327f7a7709be63a6fc0159459.jpg", "jpg", 78843);
  danbooru_generate_coefficient_sql(dump, "images/de84a028ec0256f3b4bfe4ef62e4e77f.jpg", "jpg", 77955);
  danbooru_generate_coefficient_sql(dump, "images/01abf7d2a76bc53bdb661763f58cf451.jpg", "jpg", 35646);
  danbooru_generate_coefficient_sql(dump, "images/15d815ef2847e040caf2c512529c8b33.jpg", "jpg", 105442);
  danbooru_generate_coefficient_sql(dump, "images/22a2aa6f326b185cf6bebe429c4e61bc.jpg", "jpg", 131368);
  danbooru_generate_coefficient_sql(dump, "images/50ba419527540866d36c6a770387a765.jpg", "jpg", 49570);
  danbooru_generate_coefficient_sql(dump, "images/81650d1cb554c52526c3c6081fd3bb8b.jpg", "jpg", 126711);
  danbooru_generate_coefficient_sql(dump, "images/b62bb46cc496add642482dafde93b106.jpg", "jpg", 118700);
  danbooru_generate_coefficient_sql(dump, "images/727b8748e2c66d06f08039a3c55f54e5.jpg", "jpg", 119291);
  danbooru_generate_coefficient_sql(dump, "images/989905eedf7e3a7564bdbe5b5168ea54.jpg", "jpg", 105040);
  danbooru_generate_coefficient_sql(dump, "images/27585ba8781656ee3838439c4e1d365b.jpg", "jpg", 59910);
  danbooru_generate_coefficient_sql(dump, "images/cca1feea9ca596ed98307888e98a601d.jpg", "jpg", 25786);
  danbooru_generate_coefficient_sql(dump, "images/951ad2a65c6d2d82766d2b398caac310.jpg", "jpg", 110354);
  danbooru_generate_coefficient_sql(dump, "images/e0c3b2e150da7f42ddfcf78d49ff1618.jpg", "jpg", 18455);
  danbooru_generate_coefficient_sql(dump, "images/5a95210d41561b929fdbd3849bf93860.jpg", "jpg", 122551);
  danbooru_generate_coefficient_sql(dump, "images/3e16f5a3172e219ca415ce0c895ae435.gif", "gif", 3777);
  danbooru_generate_coefficient_sql(dump, "images/097110607a255c224b7472398f9b18f1.gif", "gif", 80880);
  danbooru_generate_coefficient_sql(dump, "images/08762313255fac04e09453a920c4a625.jpg", "jpg", 68613);
  danbooru_generate_coefficient_sql(dump, "images/90e3ae8d4c826a068a8033c371080585.jpg", "jpg", 24324);
  danbooru_generate_coefficient_sql(dump, "images/e9e8754f9dee430ec98ab87c4cc1ddd5.jpg", "jpg", 100008);
  danbooru_generate_coefficient_sql(dump, "images/c47a94d2e7af14f2493f666eed52bdc9.gif", "gif", 65684);
  danbooru_generate_coefficient_sql(dump, "images/8528448590beebe06772664703d814aa.jpg", "jpg", 72906);
  danbooru_generate_coefficient_sql(dump, "images/1cd9c1c3523f541080a5dd753bc6ce91.jpg", "jpg", 31192);
  danbooru_generate_coefficient_sql(dump, "images/9fe6f50e53ce69ff5b3309ae661e0ec1.jpeg", "jpg", 139973);
  danbooru_generate_coefficient_sql(dump, "images/aeb0129c931a557763eb3a01996d112c.jpg", "jpg", 85030);
  danbooru_generate_coefficient_sql(dump, "images/9b51067aa3fedd1b75eff45057508a69.jpg", "jpg", 26771);
  danbooru_generate_coefficient_sql(dump, "images/f3f8eda04b54dd4f0c8d71472b4076ed.jpg", "jpg", 113713);
  danbooru_generate_coefficient_sql(dump, "images/6f79416417987ca9a8f395c1067edfae.jpg", "jpg", 13832);
  danbooru_generate_coefficient_sql(dump, "images/09a628546cd1fb641feb09e8a6eb1775.jpg", "jpg", 80789);
  danbooru_generate_coefficient_sql(dump, "images/224872ace681d8a73d6ae1b9e9cc5daa.jpg", "jpg", 81095);
  danbooru_generate_coefficient_sql(dump, "images/752d1db9c24b09b2e012be5164eb4bfd.jpg", "jpg", 123823);
  danbooru_generate_coefficient_sql(dump, "images/ce8380ec4ac1351d2de42544b4e3c58f.jpg", "jpg", 82600);
  danbooru_generate_coefficient_sql(dump, "images/72240acd3eeeb88ee6ddf511c7db61b2.jpg", "jpg", 137166);
  danbooru_generate_coefficient_sql(dump, "images/35d775e420d4a54bd6e7b760467473e4.jpg", "jpg", 137207);
  danbooru_generate_coefficient_sql(dump, "images/5dda593049313500dbf05693c1f31a76.jpg", "jpg", 113587);
  danbooru_generate_coefficient_sql(dump, "images/11c20492102e5692deee8126bda573c2.jpg", "jpg", 117495);
  danbooru_generate_coefficient_sql(dump, "images/08fa8eecaaafe4def93df4f49c522239.jpg", "jpg", 30923);
  danbooru_generate_coefficient_sql(dump, "images/ec2d6dcbf5016c633b1f2aea26d82995.jpg", "jpg", 36236);
  danbooru_generate_coefficient_sql(dump, "images/da04c9305b394c2b6551f6a22738f016.jpg", "jpg", 49976);
  danbooru_generate_coefficient_sql(dump, "images/e89d0b1709b65fdfe4c4805d210add58.jpg", "jpg", 134549);
  danbooru_generate_coefficient_sql(dump, "images/eb54bd6688f4a22b99371fd821656849.jpg", "jpg", 92119);
  danbooru_generate_coefficient_sql(dump, "images/a1e121edb43555bc015ff038bec9de27.jpg", "jpg", 74900);
  danbooru_generate_coefficient_sql(dump, "images/29e0bc1bf43af508d078b0cc7469deed.jpg", "jpg", 79049);
  danbooru_generate_coefficient_sql(dump, "images/b5b226e11a735eb186c77f41c3e5f6d1.jpg", "jpg", 97421);
  danbooru_generate_coefficient_sql(dump, "images/afd172fdba379a8a6f2aedc3bba375e7.jpg", "jpg", 26670);
  danbooru_generate_coefficient_sql(dump, "images/57761748ef848f4896201de9ba3cbb56.jpg", "jpg", 99945);
  danbooru_generate_coefficient_sql(dump, "images/2af479465c3cef8079827d26b4304980.jpg", "jpg", 79985);
  danbooru_generate_coefficient_sql(dump, "images/3589b3b67666162f3b1cc4c5b8885fbe.jpg", "jpg", 47852);
  danbooru_generate_coefficient_sql(dump, "images/2c228eb64f3c03e40eae7e6ae3cda488.jpg", "jpg", 16464);
  danbooru_generate_coefficient_sql(dump, "images/64b894ce236f907be64ee25eb3085f11.jpg", "jpg", 98414);
  danbooru_generate_coefficient_sql(dump, "images/f17cbab3605225433eb7d71f33184db1.jpg", "jpg", 23503);
  danbooru_generate_coefficient_sql(dump, "images/1162673d1aca431eff050e47e81fe494.jpg", "jpg", 4172);
  danbooru_generate_coefficient_sql(dump, "images/7cc73530a09b66171d957c1a9071930f.jpg", "jpg", 34148);
  danbooru_generate_coefficient_sql(dump, "images/39398132f03b94b78b6f01770cf25e79.jpg", "jpg", 138779);
  danbooru_generate_coefficient_sql(dump, "images/57327806e2094bb239885129871add17.jpg", "jpg", 5939);
  danbooru_generate_coefficient_sql(dump, "images/66821a4609abf4a2f03f8d5183700110.jpg", "jpg", 83221);
  danbooru_generate_coefficient_sql(dump, "images/64977621044007c0b293bfa37a5d33a2.jpg", "jpg", 54013);
  danbooru_generate_coefficient_sql(dump, "images/351b87d34fc88827d1dc4fc32317104a.jpg", "jpg", 28647);
  danbooru_generate_coefficient_sql(dump, "images/d21dd2c99685b8c7a0ea8770983e6f7e.jpg", "jpg", 128643);
  danbooru_generate_coefficient_sql(dump, "images/cabb024d9123be27c446f7015b781971.jpg", "jpg", 118282);
  danbooru_generate_coefficient_sql(dump, "images/82be94ee62eaa651e20ffd0c01045f73.jpg", "jpg", 137337);
  danbooru_generate_coefficient_sql(dump, "images/11f523b4e71d3c8b617453a48c30d0f9.jpg", "jpg", 119899);
  danbooru_generate_coefficient_sql(dump, "images/38b8a824e344168eea09a79b55333894.jpg", "jpg", 67242);
  danbooru_generate_coefficient_sql(dump, "images/cb911b59aa7ff617651ab50d6508efa8.jpg", "jpg", 4298);
  danbooru_generate_coefficient_sql(dump, "images/c04cec2a7a98a1780b4bd799d2fee3d1.jpg", "jpg", 16181);
  danbooru_generate_coefficient_sql(dump, "images/f7c3b4045c61fc40994e52658d371723.jpg", "jpg", 128056);
  danbooru_generate_coefficient_sql(dump, "images/6967c840126593935dc641ffbbf26477.jpg", "jpg", 53182);
  danbooru_generate_coefficient_sql(dump, "images/04d9056629ce8529c272d41a5a948cfc.jpg", "jpg", 13614);
  danbooru_generate_coefficient_sql(dump, "images/3ae504cb6f28809069f8b73bed3d86b2.jpg", "jpg", 49530);
  danbooru_generate_coefficient_sql(dump, "images/fefdd7b57091fbf6101fcad66e8f7939.jpg", "jpg", 121870);
  danbooru_generate_coefficient_sql(dump, "images/dae8532072bc3c555af184eef9052799.jpg", "jpg", 18958);
  danbooru_generate_coefficient_sql(dump, "images/b9982096a9805f1baf611e99eca9b585.jpg", "jpg", 91823);
  danbooru_generate_coefficient_sql(dump, "images/78bead9a9ade168bffaf3e3b82b3f48d.jpg", "jpg", 132430);
  danbooru_generate_coefficient_sql(dump, "images/a225f806d8d7c6ae1c4f290607e028cc.jpg", "jpg", 39151);
  danbooru_generate_coefficient_sql(dump, "images/edde1b179e755bc8b8cb29da76cd7ed8.jpg", "jpg", 75262);
  danbooru_generate_coefficient_sql(dump, "images/77659dfbbae549d9c37a34ab9a5a64e9.gif", "gif", 113618);
  danbooru_generate_coefficient_sql(dump, "images/3b90b795d29ea0a42a5fecd2e772dcd4.jpg", "jpg", 15209);
  danbooru_generate_coefficient_sql(dump, "images/7e22115be73ffd6c78254eb961067353.gif", "gif", 117567);
  danbooru_generate_coefficient_sql(dump, "images/be2f519eb34d107f719010db5f221159.jpg", "jpg", 129050);
  danbooru_generate_coefficient_sql(dump, "images/ff8b144c1a3d5984ce904d944adda43f.jpg", "jpg", 140413);
  danbooru_generate_coefficient_sql(dump, "images/2ecb310394531633a07eafe5946b594a.jpg", "jpg", 131834);
  danbooru_generate_coefficient_sql(dump, "images/48f47f8b17cf9ea5b816c31f3ada250c.jpg", "jpg", 76376);
  danbooru_generate_coefficient_sql(dump, "images/9ea92fc5b3a9e9088cc2206d56454162.jpg", "jpg", 131052);
  danbooru_generate_coefficient_sql(dump, "images/04d0c8aa4ad1a576ff3844cb007b0107.jpg", "jpg", 77354);
  danbooru_generate_coefficient_sql(dump, "images/25b323e41536f3555328b23e3c981c55.jpg", "jpg", 115153);
  danbooru_generate_coefficient_sql(dump, "images/2d8325173faf08d6008e2ca4fcff6ac7.jpg", "jpg", 74126);
  danbooru_generate_coefficient_sql(dump, "images/11ded07d0435d5f72a42896ad49cbca2.jpg", "jpg", 69221);
  danbooru_generate_coefficient_sql(dump, "images/2ee4caa081a762b25664beae02e21281.jpg", "jpg", 61760);
  danbooru_generate_coefficient_sql(dump, "images/737afe2c1f9ad331ba75b8bceb5edd74.jpg", "jpg", 114049);
  danbooru_generate_coefficient_sql(dump, "images/411421d5f948feb554da7a33c42b27e9.jpg", "jpg", 125215);
  danbooru_generate_coefficient_sql(dump, "images/c76fd602adf6101f99aeb2a93dbc42eb.jpg", "jpg", 67708);
  danbooru_generate_coefficient_sql(dump, "images/92f4313405f81136b73347527860c33c.jpg", "jpg", 52078);
  danbooru_generate_coefficient_sql(dump, "images/0c2a9c474c17b87856f3e14683df0e31.png", "png", 29865);
  danbooru_generate_coefficient_sql(dump, "images/a0e106a8770aad62d9477674beaa1ba4.jpg", "jpg", 63319);
  danbooru_generate_coefficient_sql(dump, "images/52d7051c9936442cd7b5ca1bb083788b.jpg", "jpg", 47107);
  danbooru_generate_coefficient_sql(dump, "images/dbe8826768812535fa5783324752227b.jpg", "jpg", 51674);
  danbooru_generate_coefficient_sql(dump, "images/5203a027ef1f552b9c52de4f5292b690.jpg", "jpg", 138770);
  danbooru_generate_coefficient_sql(dump, "images/9df018c1221c9c245a119659587531bc.jpg", "jpg", 93114);
  danbooru_generate_coefficient_sql(dump, "images/5c1e0abcfc3584514853b247b2cf8f4c.jpg", "jpg", 55323);
  danbooru_generate_coefficient_sql(dump, "images/61845a028bc1824555b71551266077fe.jpg", "jpg", 18263);
  danbooru_generate_coefficient_sql(dump, "images/73cb43e3b66bff4818dfa2fd87e98bd9.jpg", "jpg", 4462);
  danbooru_generate_coefficient_sql(dump, "images/3bfc5a3d3eab63e4911bea928df8dc26.jpg", "jpg", 2855);
  danbooru_generate_coefficient_sql(dump, "images/66f2a4404f5a013d89e00cf885f06d6b.jpg", "jpg", 6505);
  danbooru_generate_coefficient_sql(dump, "images/099aac3f9b93f9a55073e20a8d2fb40a.jpg", "jpg", 91782);
  danbooru_generate_coefficient_sql(dump, "images/5b4d5aecc18011d6f7657f441bf9b2eb.jpeg", "jpg", 135725);
  danbooru_generate_coefficient_sql(dump, "images/2c77ebb396b04e8bfa1491c772b32f2f.jpg", "jpg", 45080);
  danbooru_generate_coefficient_sql(dump, "images/344cf1bc0a63f6cb0da40ff7664c63bf.jpg", "jpg", 89732);
  danbooru_generate_coefficient_sql(dump, "images/6c472c78f2e8299e0057173b9ae0df9b.jpg", "jpg", 62936);
  danbooru_generate_coefficient_sql(dump, "images/7a606a11d0e19519cdea781dd2912190.jpg", "jpg", 10144);
  danbooru_generate_coefficient_sql(dump, "images/5f6fccedcf2137b430b2bb523b94e76a.jpeg", "jpg", 121478);
  danbooru_generate_coefficient_sql(dump, "images/4db6af6d83aba14e0a3322a1cc339496.jpg", "jpg", 80046);
  danbooru_generate_coefficient_sql(dump, "images/73384fb530f472cf10f447bfcea08c67.jpg", "jpg", 84051);
  danbooru_generate_coefficient_sql(dump, "images/5d200837bf1a20544848c8eca7499e7c.jpg", "jpg", 136076);
  danbooru_generate_coefficient_sql(dump, "images/1ad5a7b8564cfa7423d05c44810d4186.jpg", "jpg", 31989);
  danbooru_generate_coefficient_sql(dump, "images/c8299507eed30992bafbc1f13e134c1a.jpg", "jpg", 98433);
  danbooru_generate_coefficient_sql(dump, "images/200f89c5ec2160d7efb081961ca8616f.jpg", "jpg", 92969);
  danbooru_generate_coefficient_sql(dump, "images/a7237558be6c61af431df7248d8c5e90.jpg", "jpg", 93864);
  danbooru_generate_coefficient_sql(dump, "images/64b63b723f283f7d9e9add20bf1be390.jpg", "jpg", 11301);
  danbooru_generate_coefficient_sql(dump, "images/6b93d21d824dfde2b97dbde9fb458328.jpg", "jpg", 50737);
  danbooru_generate_coefficient_sql(dump, "images/2a0b42426a19881403661a5fa58b9a0d.jpg", "jpg", 127543);
  danbooru_generate_coefficient_sql(dump, "images/0ae2c24fdc58d7dc64940c06d4e743a5.jpg", "jpg", 132096);
  danbooru_generate_coefficient_sql(dump, "images/1b67620b6239fae673e7ac4a3a05e1e8.jpg", "jpg", 52462);
  danbooru_generate_coefficient_sql(dump, "images/73699fb5b24d5e7a2eaf9a9f2628f8da.jpg", "jpg", 18124);
  danbooru_generate_coefficient_sql(dump, "images/d4c4fb0dc567aa653dd82941f0267072.jpg", "jpg", 118600);
  danbooru_generate_coefficient_sql(dump, "images/9026b2ca468048075f4820cbb45780e5.jpg", "jpg", 61032);
  danbooru_generate_coefficient_sql(dump, "images/486d98221598e40a290496b70a6fe0f3.jpg", "jpg", 18903);
  danbooru_generate_coefficient_sql(dump, "images/9715fa1182b3d3718fad8e09b8d4c16e.jpg", "jpg", 93410);
  danbooru_generate_coefficient_sql(dump, "images/a353c516983ba517d6474caf3620c3b3.jpg", "jpg", 39191);
  danbooru_generate_coefficient_sql(dump, "images/f21840d52497bef5b9b7ca4804f89cee.jpg", "jpg", 53977);
  danbooru_generate_coefficient_sql(dump, "images/ddc24842b9fba80559ba404d601f1014.jpg", "jpg", 141615);
  danbooru_generate_coefficient_sql(dump, "images/dd8d1a9a2ae803d944d67beb6f30b4e7.jpg", "jpg", 41127);
  danbooru_generate_coefficient_sql(dump, "images/59d659db0f643546cf8103621845a6f7.jpg", "jpg", 134507);
  danbooru_generate_coefficient_sql(dump, "images/31fa0c751c7bd8ee842ee360858fda19.jpg", "jpg", 32916);
  danbooru_generate_coefficient_sql(dump, "images/ec901aa44f93d6366f639eb2b1730a9b.gif", "gif", 63431);
  danbooru_generate_coefficient_sql(dump, "images/45fdef59e499f4f019212bd62899d96d.jpg", "jpg", 46220);
  danbooru_generate_coefficient_sql(dump, "images/e5091b9b82141c3a1f955dd25cfb827c.jpg", "jpg", 29437);
  danbooru_generate_coefficient_sql(dump, "images/b348a6749b99abbbadc941abac2d77c5.jpg", "jpg", 106849);
  danbooru_generate_coefficient_sql(dump, "images/ed8161a11d2cd485476178eeb910c6b7.jpg", "jpg", 28586);
  danbooru_generate_coefficient_sql(dump, "images/e5288c4d2de7038fb7c7d47091b6452a.jpg", "jpg", 83519);
  danbooru_generate_coefficient_sql(dump, "images/c893832aa96970131d7deeaff78cd3c6.jpg", "jpg", 89868);
  danbooru_generate_coefficient_sql(dump, "images/8954a8122e6d29b4f5aa6e7ed093dd00.png", "png", 58632);
  danbooru_generate_coefficient_sql(dump, "images/079969f97496b1668284670f99a80940.jpg", "jpg", 2468);
  danbooru_generate_coefficient_sql(dump, "images/e02e5680c1a16a0aa393b0b9d11e7df2.jpg", "jpg", 28148);
  danbooru_generate_coefficient_sql(dump, "images/7bd05ff75a209b3a994bce07f34c77c2.png", "png", 129565);
  danbooru_generate_coefficient_sql(dump, "images/e4f5377696a5472128e77827b9eb9f46.jpg", "jpg", 30181);
  danbooru_generate_coefficient_sql(dump, "images/7c97933aef510d89e7193643b0de78dc.png", "png", 41561);
  danbooru_generate_coefficient_sql(dump, "images/dafad40bd637682ab20083d44ba3f126.jpg", "jpg", 91063);
  danbooru_generate_coefficient_sql(dump, "images/8466bb9096e908afb3f9b9e17f731476.jpg", "jpg", 51407);
  danbooru_generate_coefficient_sql(dump, "images/ffef402f5b07749e599f75cd8546335d.jpg", "jpg", 104257);
  danbooru_generate_coefficient_sql(dump, "images/4dd1fae89ade1494baa2d13fdd96edbb.jpg", "jpg", 87063);
  danbooru_generate_coefficient_sql(dump, "images/263d98027eba0945b53491c56b6f0fd8.jpg", "jpg", 8859);
  danbooru_generate_coefficient_sql(dump, "images/6058908ece64bc095a6f4377bac5da73.gif", "gif", 83100);
  danbooru_generate_coefficient_sql(dump, "images/1a4ec73899d503ae9679b3a9dfa479c8.jpg", "jpg", 21779);
  danbooru_generate_coefficient_sql(dump, "images/3a2e553ea197be2fb55fd99150fa18d9.jpg", "jpg", 50665);
  danbooru_generate_coefficient_sql(dump, "images/7ba151b0b6dc5e31125ef720b6129611.jpg", "jpg", 32826);
  danbooru_generate_coefficient_sql(dump, "images/24e8b16891f6b86e9e0494cf4c3936ab.jpg", "jpg", 73607);
  danbooru_generate_coefficient_sql(dump, "images/90ddc35b4d9db4702a7ee6334db5d055.jpg", "jpg", 56609);
  danbooru_generate_coefficient_sql(dump, "images/78ebe739e4882465ebb3e64bf78422c1.jpg", "jpg", 118369);
  danbooru_generate_coefficient_sql(dump, "images/8a08a28391f7b283d9460356af261ddb.jpg", "jpg", 133513);
  danbooru_generate_coefficient_sql(dump, "images/12519ef51e8f9404fe2deede7f9447e7.jpg", "jpg", 119152);
  danbooru_generate_coefficient_sql(dump, "images/11c8785cf67d79a940bd83b3a72c6db6.jpg", "jpg", 18782);
  danbooru_generate_coefficient_sql(dump, "images/b7f440267411405236d6ff84dab49e53.jpg", "jpg", 106317);
  danbooru_generate_coefficient_sql(dump, "images/2bf7da744b54b8460b0b1cbe482dff9e.jpg", "jpg", 8564);
  danbooru_generate_coefficient_sql(dump, "images/de114d1eca661598bf5649135a62ab8d.gif", "gif", 86561);
  danbooru_generate_coefficient_sql(dump, "images/944abb681428d190c1c9149801560966.jpg", "jpg", 53203);
  danbooru_generate_coefficient_sql(dump, "images/fb816074e226eaa754c469fbc81c9708.jpg", "jpg", 79421);
  danbooru_generate_coefficient_sql(dump, "images/7e3c182ed542c13e2f4f0e2133e552ad.jpg", "jpg", 54214);
  danbooru_generate_coefficient_sql(dump, "images/b128851331c2c31b127793c2e676bfb9.jpg", "jpg", 92514);
  danbooru_generate_coefficient_sql(dump, "images/49d8d367dfdc041a1e4ddcc592579a76.jpg", "jpg", 41944);
  danbooru_generate_coefficient_sql(dump, "images/d9c5cb2db13914900bed8f3538f21a0f.jpg", "jpg", 109458);
  danbooru_generate_coefficient_sql(dump, "images/d0d335d709412b92256457c2fa504817.jpg", "jpg", 42145);
  danbooru_generate_coefficient_sql(dump, "images/1466b91b903420c08b4f9418634a309f.jpg", "jpg", 52650);
  danbooru_generate_coefficient_sql(dump, "images/71452e64c5f12e4983afa42264686ade.jpg", "jpg", 45029);
  danbooru_generate_coefficient_sql(dump, "images/825c3442a4aa341a212a450ced142258.jpg", "jpg", 5133);
  danbooru_generate_coefficient_sql(dump, "images/261eaf5402020a05d7c45da736d559a6.jpg", "jpg", 98020);
  danbooru_generate_coefficient_sql(dump, "images/283ddbf1b30301f10d9a046eeb8e0cea.jpg", "jpg", 61862);
  danbooru_generate_coefficient_sql(dump, "images/4444c18571451f371e531e8b1e3404c5.jpeg", "jpg", 123701);
  danbooru_generate_coefficient_sql(dump, "images/7e2f3abb65794570d4e8bed1ff3bb8e0.jpg", "jpg", 59461);
  danbooru_generate_coefficient_sql(dump, "images/d74afd217edf728b8c38f3c0af53b492.jpg", "jpg", 108515);
  danbooru_generate_coefficient_sql(dump, "images/bb5a3fac08cf4df153f587a02278253e.jpg", "jpg", 93772);
  danbooru_generate_coefficient_sql(dump, "images/ff58656c6b4a68797ebedc5c47589be9.gif", "gif", 20299);
  danbooru_generate_coefficient_sql(dump, "images/f641474d1dba87958574110ef1b2a154.jpg", "jpg", 41315);
  danbooru_generate_coefficient_sql(dump, "images/205a2cd300177f8e9ef42bfece1f2cc6.jpeg", "jpg", 117904);
  danbooru_generate_coefficient_sql(dump, "images/2d5a6e0bffe18c81b53d169cee76b46a.jpg", "jpg", 18216);
  danbooru_generate_coefficient_sql(dump, "images/c8d2b42e615668ff8429a9249a79b095.jpg", "jpg", 60401);
  danbooru_generate_coefficient_sql(dump, "images/2422893c473494c9d47d0e953bf55324.jpg", "jpg", 121914);
  danbooru_generate_coefficient_sql(dump, "images/c33860aaacbe99883b075dfabbb74ed5.jpg", "jpg", 71765);
  danbooru_generate_coefficient_sql(dump, "images/5b4c8dc2b2a254e9f6cbdeb2cd7ed5e1.jpg", "jpg", 39362);
  danbooru_generate_coefficient_sql(dump, "images/66fcce7580c3548a0b4c3839e566fcd1.jpeg", "jpg", 124835);
  danbooru_generate_coefficient_sql(dump, "images/dd33ea4c166c5949161f40d802323968.jpg", "jpg", 139952);
  danbooru_generate_coefficient_sql(dump, "images/a98e1cff085def9b94ea761584b88592.jpg", "jpg", 63012);
  danbooru_generate_coefficient_sql(dump, "images/959bcf07a0ef4646c66e32f36e129a98.jpg", "jpg", 8872);
  danbooru_generate_coefficient_sql(dump, "images/5c28c83856b6574410ac469329a54d75.jpg", "jpg", 120927);
  danbooru_generate_coefficient_sql(dump, "images/0139b56fbc54c77367cd4fda1cfe9311.jpg", "jpg", 7492);
  danbooru_generate_coefficient_sql(dump, "images/c16b12c581f995adf0c741f5684fabb5.jpg", "jpg", 66319);
  danbooru_generate_coefficient_sql(dump, "images/084295c5dce15aaafc88867e16f7c21c.jpg", "jpg", 14462);
  danbooru_generate_coefficient_sql(dump, "images/ff6e99713ad7223b1ec85489b68f51ef.jpg", "jpg", 19071);
  danbooru_generate_coefficient_sql(dump, "images/0f8ce161e44b8359639add29866479c5.jpg", "jpg", 58645);
  danbooru_generate_coefficient_sql(dump, "images/15dcb606de35a65b41ebc89350b78d30.jpg", "jpg", 7039);
  danbooru_generate_coefficient_sql(dump, "images/6f4260d3fa5487265ce87a685687e1a9.jpg", "jpg", 118944);
  danbooru_generate_coefficient_sql(dump, "images/c0ec4fb2a13c47994614b27157cc7a89.jpg", "jpg", 50410);
  danbooru_generate_coefficient_sql(dump, "images/61d05721dbc7b73ee612367b7fcf047b.jpg", "jpg", 67184);
  danbooru_generate_coefficient_sql(dump, "images/7e18fe129cd4a61c8bd0314b3757f527.png", "png", 13068);
  danbooru_generate_coefficient_sql(dump, "images/8db8e0055b6c13e0044155b006b67806.jpg", "jpg", 127618);
  danbooru_generate_coefficient_sql(dump, "images/83e706ac3adc53fe24d198195d728578.jpg", "jpg", 86734);
  danbooru_generate_coefficient_sql(dump, "images/d0d357d1cf800148e1163bcfa3e29513.jpg", "jpg", 5539);
  danbooru_generate_coefficient_sql(dump, "images/7bf272268e6f93b9adc4a6ce1408e5bf.jpg", "jpg", 22137);
  danbooru_generate_coefficient_sql(dump, "images/b26ad53700fe27645697e41cd377fb75.jpg", "jpg", 97247);
  danbooru_generate_coefficient_sql(dump, "images/483fe2d7bc1f1d7f58b0c4e7ee4fe9ad.jpg", "jpg", 51793);
  danbooru_generate_coefficient_sql(dump, "images/06d25704c58c0d16d979ccb52a3eeb94.jpg", "jpg", 34662);
  danbooru_generate_coefficient_sql(dump, "images/b6cbc333bc86a2d8288f0b5d6aa2499f.jpg", "jpg", 88603);
  danbooru_generate_coefficient_sql(dump, "images/2138ae466d6b18eda44e20c2f9ab54a3.jpg", "jpg", 10292);
  danbooru_generate_coefficient_sql(dump, "images/416e92fd6e57472895e353be3f734087.jpg", "jpg", 80402);
  danbooru_generate_coefficient_sql(dump, "images/415bf60a98a899127cc4f18c3d912e4f.jpg", "jpg", 17066);
  danbooru_generate_coefficient_sql(dump, "images/0fdc9b1b407b93bd91092efe331500ce.jpg", "jpg", 7843);
  danbooru_generate_coefficient_sql(dump, "images/8337d2dcfd9aafb2ad856af22ea21274.jpg", "jpg", 67934);
  danbooru_generate_coefficient_sql(dump, "images/7d692286f426418d2eb54703bafce3af.jpg", "jpg", 115599);
  danbooru_generate_coefficient_sql(dump, "images/ff2989722c19375156e1b5c7fc4ffdb1.png", "png", 51283);
  danbooru_generate_coefficient_sql(dump, "images/f139d60efc29b96e7ccc90b3938dfd45.jpg", "jpg", 115030);
  danbooru_generate_coefficient_sql(dump, "images/9ffd7f5b3ea1026aaa2905f6d3af6281.jpg", "jpg", 51870);
  danbooru_generate_coefficient_sql(dump, "images/50bb4579d6da79f22ec82dae9bb5dd0a.jpg", "jpg", 25943);
  danbooru_generate_coefficient_sql(dump, "images/df051ed0137ca5ada7ceee892cc78d0a.png", "png", 60809);
  danbooru_generate_coefficient_sql(dump, "images/0316e1d8a773777efcca85fda785e060.gif", "gif", 102223);
  danbooru_generate_coefficient_sql(dump, "images/0de7ad3d9b9bdc815d30090218ca8a76.jpg", "jpg", 93310);
  danbooru_generate_coefficient_sql(dump, "images/884cf2b5d165095b30483ea163cfa330.jpg", "jpg", 40465);
  danbooru_generate_coefficient_sql(dump, "images/37e5756d032015982ced00fc17211392.jpg", "jpg", 3146);
  danbooru_generate_coefficient_sql(dump, "images/54972f977ee82269c89623af468cc0ed.jpg", "jpg", 82115);
  danbooru_generate_coefficient_sql(dump, "images/c7a61051aef04881db99c6acc1ae9099.jpg", "jpg", 15648);
  danbooru_generate_coefficient_sql(dump, "images/31f25c949e0101df9002a35ca8a7d3cb.jpg", "jpg", 8374);
  danbooru_generate_coefficient_sql(dump, "images/f3bcfc146b97af6c9931bb749e0a29f9.jpg", "jpg", 91674);
  danbooru_generate_coefficient_sql(dump, "images/43076ab32f06b63422a849eef067c3f5.jpg", "jpg", 91690);
  danbooru_generate_coefficient_sql(dump, "images/a9b5416179e46cee320f5b5258ab6a79.gif", "gif", 4565);
  danbooru_generate_coefficient_sql(dump, "images/02e51a10926eec8bf0f21d8de7178d87.gif", "gif", 95067);
  danbooru_generate_coefficient_sql(dump, "images/5727432fd3b46e09ac0552f3fc53d78b.jpg", "jpg", 88817);
  danbooru_generate_coefficient_sql(dump, "images/00743bf851448adeb46e605559592042.jpg", "jpg", 72248);
  danbooru_generate_coefficient_sql(dump, "images/ea7d49c958c46b465a7cb13297332767.jpg", "jpg", 138989);
  danbooru_generate_coefficient_sql(dump, "images/4a20a5af5d2b8f2f7ab7a4e04adbea40.jpg", "jpg", 108291);
  danbooru_generate_coefficient_sql(dump, "images/59b2d0e26a2cfa24eb0b25c47295bd20.jpg", "jpg", 86678);
  danbooru_generate_coefficient_sql(dump, "images/bf9da796e36aea403a7c1a4fb0b70f26.jpg", "jpg", 20624);
  danbooru_generate_coefficient_sql(dump, "images/a53f05cb9c2221c8a6a9bb1e9ef1a8c6.jpg", "jpg", 108765);
  danbooru_generate_coefficient_sql(dump, "images/93cdf7c1cbc8b6d166d05ad02ecdb143.jpg", "jpg", 227);
  danbooru_generate_coefficient_sql(dump, "images/e5be9c37c58c7e01474eacb7df5fa22f.jpg", "jpg", 1366);
  danbooru_generate_coefficient_sql(dump, "images/b0bc6562c35e87ec619e683a57e9b225.jpeg", "jpg", 120085);
  danbooru_generate_coefficient_sql(dump, "images/1727ff18c796a7390716156baea1a8bd.jpg", "jpg", 32632);
}

  danbooru_generate_coefficient_sql(dump, "images/57ac75a6ae3c9414afd74a47f24a95f9.jpg", "jpg", 83368);
  danbooru_generate_coefficient_sql(dump, "images/802f07518158c5d06c3fac90362efcbe.jpg", "jpg", 69959);
  danbooru_generate_coefficient_sql(dump, "images/90e8b97dc587276505df3756e4c99af9.jpg", "jpg", 4763);
  danbooru_generate_coefficient_sql(dump, "images/c6c29111d22619a5f003927a13d24fb0.jpg", "jpg", 38393);
  danbooru_generate_coefficient_sql(dump, "images/e5502e91e450a657870503387aabb24f.jpg", "jpg", 31200);
  danbooru_generate_coefficient_sql(dump, "images/3ddea192c4d7cfd2fde683bb9da6ccc1.jpg", "jpg", 40387);
  danbooru_generate_coefficient_sql(dump, "images/21626e44ca9c5cb1636c25178e4cf908.jpg", "jpg", 6507);
  danbooru_generate_coefficient_sql(dump, "images/fc8d11de3f1f5ce145fbcc67dc4654d2.jpg", "jpg", 114428);
  danbooru_generate_coefficient_sql(dump, "images/322369e7e1a1b777dbe627270de4289c.jpg", "jpg", 7229);
  danbooru_generate_coefficient_sql(dump, "images/41d2d6af3648c77e9f9362307232f538.jpg", "jpg", 40199);
  danbooru_generate_coefficient_sql(dump, "images/a252cbe8d8f024147fc58ad646f2db17.jpg", "jpg", 57554);
  danbooru_generate_coefficient_sql(dump, "images/8d03f7cd5428b78afe0bd7b1eb207433.jpg", "jpg", 34833);
  danbooru_generate_coefficient_sql(dump, "images/654286da1f3d982d66ea103e696ba556.jpg", "jpg", 132336);
  danbooru_generate_coefficient_sql(dump, "images/7a25e3922412553a17b258f0352f2271.jpg", "jpg", 10076);
  danbooru_generate_coefficient_sql(dump, "images/6f7942bbe7c5c97f087969a4f86731d1.jpg", "jpg", 90711);
  danbooru_generate_coefficient_sql(dump, "images/609222098360603619ad4a3de46c928d.jpg", "jpg", 36487);
  danbooru_generate_coefficient_sql(dump, "images/8e2c77203cf84ba74cf25f75ea11792f.jpg", "jpg", 106522);
  danbooru_generate_coefficient_sql(dump, "images/55f57faef05d94b1be93c25365f35501.jpg", "jpg", 107629);
  danbooru_generate_coefficient_sql(dump, "images/0f3ba54e2cc429fc815b9e665dbc1b63.jpeg", "jpg", 120093);
  danbooru_generate_coefficient_sql(dump, "images/a21d39a9f33914a0cdba376b08f7f401.jpg", "jpg", 30459);
  danbooru_generate_coefficient_sql(dump, "images/c02b6d8a3397e66cc1f74ac8eb95de95.jpg", "jpg", 92529);
  danbooru_generate_coefficient_sql(dump, "images/c60f9a3bf46610f83d8c66c49bb3b0b4.jpg", "jpg", 88617);
  danbooru_generate_coefficient_sql(dump, "images/de27bad3732272b1bd80cfe13939694c.jpg", "jpg", 48193);
  danbooru_generate_coefficient_sql(dump, "images/1c80d28be694549a399b26b4ffed38fe.jpg", "jpg", 16618);
  danbooru_generate_coefficient_sql(dump, "images/f5fd05138991c505cd60c2006fc520f9.jpg", "jpg", 32762);
  danbooru_generate_coefficient_sql(dump, "images/d04d46b1ece06c617ba99619940a9a0a.jpg", "jpg", 78272);
  danbooru_generate_coefficient_sql(dump, "images/e8854587a42c8d0cf4cc2626efebad11.png", "png", 30524);
  danbooru_generate_coefficient_sql(dump, "images/4af1ebcb7c80b9c48e765ab6deb5e7d7.jpg", "jpg", 112193);
  danbooru_generate_coefficient_sql(dump, "images/cff977e522269b86bbd7ec2f9d10caad.jpg", "jpg", 10803);
  danbooru_generate_coefficient_sql(dump, "images/68f8374c4722f418d7105d0a19af15df.jpg", "jpg", 121157);
  danbooru_generate_coefficient_sql(dump, "images/48ab14a8e1bc6c52c82f62fba9caa267.jpg", "jpg", 124609);
  danbooru_generate_coefficient_sql(dump, "images/3a7574b74b1b75239a37651203038601.jpeg", "jpg", 122487);
  danbooru_generate_coefficient_sql(dump, "images/1f6ada435251825fa9a2c660bc3e3517.jpg", "jpg", 115720);
  danbooru_generate_coefficient_sql(dump, "images/a5fb87dd92c03052318fdb3e39a6e171.jpg", "jpg", 96178);
  danbooru_generate_coefficient_sql(dump, "images/a8fefa14a869a0ba10e82e11d476f076.jpg", "jpg", 25576);
  danbooru_generate_coefficient_sql(dump, "images/9df8fa7ab25888b783b03db6c45b3442.jpg", "jpg", 94649);
  danbooru_generate_coefficient_sql(dump, "images/e6e90704cf1bc1c8e07b49a7fa4c7433.jpg", "jpg", 76796);
  danbooru_generate_coefficient_sql(dump, "images/3715686f408834c9c8bcc52d7c900f21.jpg", "jpg", 102795);
  danbooru_generate_coefficient_sql(dump, "images/69160bcaa7e460ca9b80fb9067974837.jpg", "jpg", 50644);
  danbooru_generate_coefficient_sql(dump, "images/12233379b27e8fa5b2df39c8655f22d7.jpg", "jpg", 119761);
  danbooru_generate_coefficient_sql(dump, "images/72e92d854d4465f57c4048150759c93d.jpg", "jpg", 14537);
  danbooru_generate_coefficient_sql(dump, "images/b02b76feeaf04974c1604f89f313b5cf.jpg", "jpg", 116541);
  danbooru_generate_coefficient_sql(dump, "images/c05afabb1c410204550b9560549a2e7a.jpg", "jpg", 71518);
  danbooru_generate_coefficient_sql(dump, "images/db039e6ce0d38e36246003ba7f62cfb3.jpg", "jpg", 30647);
  danbooru_generate_coefficient_sql(dump, "images/14a79375b4927a0d8e86a8266c067817.jpg", "jpg", 88356);
  danbooru_generate_coefficient_sql(dump, "images/816689d95f35b9e01fe0607ff3c09f3c.jpg", "jpg", 130258);
  danbooru_generate_coefficient_sql(dump, "images/4b97f38d4f112a1afcfe019668e0e21b.jpg", "jpg", 121916);
  danbooru_generate_coefficient_sql(dump, "images/22bac4135eadaf19b985dd0619eb3bce.gif", "gif", 29808);
  danbooru_generate_coefficient_sql(dump, "images/f11a0652bbc627757a809501a2f7888f.jpg", "jpg", 107165);
  danbooru_generate_coefficient_sql(dump, "images/c2c6edcbaef34c107518c3fd77c0e4fe.jpeg", "jpg", 122711);
  danbooru_generate_coefficient_sql(dump, "images/754062b028116fd3fed6d278af1fe29d.jpg", "jpg", 68764);
  danbooru_generate_coefficient_sql(dump, "images/2796e4ecef5eec2eb116f02738c4baa7.jpg", "jpg", 108874);
  danbooru_generate_coefficient_sql(dump, "images/0d15594e81c730f17f890b51a9dda2ff.jpg", "jpg", 109615);
  danbooru_generate_coefficient_sql(dump, "images/51a467eb5f6c3ead7783b004463bf498.jpg", "jpg", 1263);
  danbooru_generate_coefficient_sql(dump, "images/6d32f864c1cddc0c6318e31a57109d6f.jpg", "jpg", 65742);
  danbooru_generate_coefficient_sql(dump, "images/673d1d0175e78587be13f530b416f72a.jpg", "jpg", 106533);
  danbooru_generate_coefficient_sql(dump, "images/9ff29f96e196e3d78f1e5db1879a655c.jpg", "jpg", 95413);
  danbooru_generate_coefficient_sql(dump, "images/ffdc5d176db9257b656e19aa05abce4a.jpg", "jpg", 71175);
  danbooru_generate_coefficient_sql(dump, "images/da0bec96a7c2f0e0994d92cc635806a4.jpg", "jpg", 96441);
  danbooru_generate_coefficient_sql(dump, "images/530448fab504b7fb6f8e2d5cc5494067.jpg", "jpg", 67959);
  danbooru_generate_coefficient_sql(dump, "images/855ac00ce763d82d6221168436b0c8eb.jpg", "jpg", 80208);
  danbooru_generate_coefficient_sql(dump, "images/7c4af3692a81fcfacc27081e50dacf22.jpg", "jpg", 27470);
  danbooru_generate_coefficient_sql(dump, "images/fa285ab5f2c69b165cef667c9c14bae2.jpg", "jpg", 73213);
  danbooru_generate_coefficient_sql(dump, "images/202776c9fb3565ef0b972301aa9da084.gif", "gif", 31153);
  danbooru_generate_coefficient_sql(dump, "images/869d97b5b34175a492c5b33aba183299.jpg", "jpg", 21507);
  danbooru_generate_coefficient_sql(dump, "images/52c5b6293e45adf95a72e7cb69380720.jpg", "jpg", 72999);
  danbooru_generate_coefficient_sql(dump, "images/22b2409d32a396e282473cac6d368ad6.gif", "gif", 86701);
  danbooru_generate_coefficient_sql(dump, "images/e1130d2f762518c5ee01e18a39ec8286.jpg", "jpg", 35573);
  danbooru_generate_coefficient_sql(dump, "images/97a03d4215cff85fe9eb5ae760bc788b.jpg", "jpg", 108768);
  danbooru_generate_coefficient_sql(dump, "images/a7ccd298a4a2746c3359957f5ee81035.jpg", "jpg", 84171);
  danbooru_generate_coefficient_sql(dump, "images/9e42ee622e68f62436c0b973d878d123.jpg", "jpg", 9694);
  danbooru_generate_coefficient_sql(dump, "images/bdf1a1cf8976157ada4534108aafd031.jpg", "jpg", 57578);
  danbooru_generate_coefficient_sql(dump, "images/4e28d3e442e3bb997b2c00bd4bac83cb.jpg", "jpg", 64804);
  danbooru_generate_coefficient_sql(dump, "images/7004b21de8812ad8d3cbf6eff8fc22e6.jpg", "jpg", 17674);
  danbooru_generate_coefficient_sql(dump, "images/f2e544808afbfd4e688292925dde0e1f.jpg", "jpg", 20710);
  danbooru_generate_coefficient_sql(dump, "images/fa5df0c4b44d37185877bd9e14552a47.jpg", "jpg", 9082);
  danbooru_generate_coefficient_sql(dump, "images/7fe5b6c5ce09965d5e8354356b9940be.jpg", "jpg", 48164);
  danbooru_generate_coefficient_sql(dump, "images/5cd911aff324bc3c66bd72bf523fc573.jpeg", "jpg", 140018);
  danbooru_generate_coefficient_sql(dump, "images/b9de0b155290a9bdf4def89f909579e1.jpg", "jpg", 8371);
  danbooru_generate_coefficient_sql(dump, "images/74eb0faefda6b598a9287340fcea8adf.jpg", "jpg", 62110);
  danbooru_generate_coefficient_sql(dump, "images/666d439c61a4bf52e0b41d1a760bf58f.gif", "gif", 54125);
  danbooru_generate_coefficient_sql(dump, "images/eb6c4e8200e93c5ef7a995fa48d98afb.jpg", "jpg", 105998);
  danbooru_generate_coefficient_sql(dump, "images/9155498d537027d73a7ccb903eee2b59.jpg", "jpg", 14374);
  danbooru_generate_coefficient_sql(dump, "images/36b66c65ccd1772ed1901e75fddc7811.jpg", "jpg", 7304);
  danbooru_generate_coefficient_sql(dump, "images/5e71a1ba55fb87181640a0aee946a064.jpg", "jpg", 39783);
  danbooru_generate_coefficient_sql(dump, "images/4ff9c177e1ffff4e61a034e19581b6c6.jpg", "jpg", 58773);
  danbooru_generate_coefficient_sql(dump, "images/a7104501b74e690fb2017940e192e0bd.jpg", "jpg", 40302);
  danbooru_generate_coefficient_sql(dump, "images/25248a7a878251dbd55a42c868b1298d.jpg", "jpg", 15423);
  danbooru_generate_coefficient_sql(dump, "images/0a63385536fd26c59d51f2b9dfbb218c.jpg", "jpg", 17387);
  danbooru_generate_coefficient_sql(dump, "images/8406f54eccf46a6b1e8216d098eca3a4.jpg", "jpg", 16313);
  danbooru_generate_coefficient_sql(dump, "images/2ec4f5311689b3b82ece8f5f9d1b5396.jpg", "jpg", 42691);
  danbooru_generate_coefficient_sql(dump, "images/a520a84817195095c449cd98c6c1e032.jpg", "jpg", 38504);
  danbooru_generate_coefficient_sql(dump, "images/e40abe27e46af4c5385833318f672b5a.jpg", "jpg", 92768);
  danbooru_generate_coefficient_sql(dump, "images/f8f85697a5a2472047ac43b3f63bcf61.jpg", "jpg", 80449);
  danbooru_generate_coefficient_sql(dump, "images/db7b7000729a01b652920f2e2d8c8c59.jpg", "jpg", 55216);
  danbooru_generate_coefficient_sql(dump, "images/eb715d218232e3f3a23868afc49e22ab.jpg", "jpg", 130773);
  danbooru_generate_coefficient_sql(dump, "images/7f8b57489c18e9714257f5e85d3dcb62.jpg", "jpg", 119482);
  danbooru_generate_coefficient_sql(dump, "images/95572f3a7b71e6d2ba542a992b05cb5f.jpg", "jpg", 131414);
  danbooru_generate_coefficient_sql(dump, "images/b1db7f4665554e35f7f72c209d5492c0.jpg", "jpg", 46767);
  danbooru_generate_coefficient_sql(dump, "images/470f3bc4d3c75b18fd8fa3a505668622.jpg", "jpg", 41489);
  danbooru_generate_coefficient_sql(dump, "images/9599b6d0d6e314d2ad46781904cb147a.jpg", "jpg", 4456);
  danbooru_generate_coefficient_sql(dump, "images/fd0ebfe9ddffbf9639542ce868da7e1f.jpg", "jpg", 22643);
  danbooru_generate_coefficient_sql(dump, "images/b67419d8bae52e9850f6940f1bd8a609.jpg", "jpg", 50466);
  danbooru_generate_coefficient_sql(dump, "images/9b145f4324aaf30c65d70a8108f7e500.jpg", "jpg", 17397);
  danbooru_generate_coefficient_sql(dump, "images/93f6e953d85c367dc746b378b6a6814c.jpg", "jpg", 140034);
  danbooru_generate_coefficient_sql(dump, "images/c126886e42b96f3bebd4d3cb305400f2.jpg", "jpg", 68724);
  danbooru_generate_coefficient_sql(dump, "images/900cc253b905be9111b25b7d2b7386c7.png", "png", 8789);
  danbooru_generate_coefficient_sql(dump, "images/49a619cefb6aef9f94190ff082a95599.jpg", "jpg", 58663);
  danbooru_generate_coefficient_sql(dump, "images/28ff03206c6a41f6286aa85d7d0022ce.jpg", "jpg", 50474);
  danbooru_generate_coefficient_sql(dump, "images/69d2918ba22fc0dec16250b13d6f261c.png", "png", 48815);
  danbooru_generate_coefficient_sql(dump, "images/3b6646f53096e0033d899a55a4f9e421.jpg", "jpg", 84895);
  danbooru_generate_coefficient_sql(dump, "images/3a12be8df039fe2eab73208f7ce81b75.jpg", "jpg", 119731);
  danbooru_generate_coefficient_sql(dump, "images/0a68314f1b8188bd4e0f689c97e9e377.jpg", "jpg", 69899);
  danbooru_generate_coefficient_sql(dump, "images/7978df450add5887ba74c88db00c90f6.jpg", "jpg", 71722);
  danbooru_generate_coefficient_sql(dump, "images/2e47911bf03d2ce944714ba26ee0263b.jpg", "jpg", 26763);
  danbooru_generate_coefficient_sql(dump, "images/7dc7418e1091dae9bc0995d70ae797d0.jpg", "jpg", 37454);
  danbooru_generate_coefficient_sql(dump, "images/36f4e6c6b443e4efbc1c12a8c99a0e83.jpg", "jpg", 120489);
  danbooru_generate_coefficient_sql(dump, "images/8be18417b5e75c1201f7e2d91febca79.png", "png", 22129);
  danbooru_generate_coefficient_sql(dump, "images/e5c013940f50f8e28a762e5089ace736.jpg", "jpg", 61852);
  danbooru_generate_coefficient_sql(dump, "images/1e8ed193593da4eaa5237b8e677dc7b3.jpg", "jpg", 95180);
  danbooru_generate_coefficient_sql(dump, "images/ed74e6971c92127e59447e8fc91f5cc7.jpg", "jpg", 5281);
  danbooru_generate_coefficient_sql(dump, "images/f0dc494c767e7309ac827802a1d29041.jpg", "jpg", 72595);
  danbooru_generate_coefficient_sql(dump, "images/c75b9201e3f6dd0cbed5c47ff29ea060.jpg", "jpg", 81070);
  danbooru_generate_coefficient_sql(dump, "images/dec225d120a2c0bc3844f8c8efea1100.jpg", "jpg", 75483);
  danbooru_generate_coefficient_sql(dump, "images/daa0d50c3e12b4543adcd23e01293fe0.jpg", "jpg", 24889);
  danbooru_generate_coefficient_sql(dump, "images/622441903788dc5fdb9f84259bb5ad5f.jpg", "jpg", 23425);
  danbooru_generate_coefficient_sql(dump, "images/fbc0bae5335a6120a5dd8ff2cb9a206f.jpg", "jpg", 31177);
  danbooru_generate_coefficient_sql(dump, "images/d38d818f81ec444622a71cbb8f73d4f9.jpg", "jpg", 48525);
  danbooru_generate_coefficient_sql(dump, "images/6af0acc470e8b78a6b55f8fc29c877df.jpg", "jpg", 71076);
  danbooru_generate_coefficient_sql(dump, "images/e49428303aa19551b67698a2759841df.jpg", "jpg", 46587);
  danbooru_generate_coefficient_sql(dump, "images/f0323c75dc60202a842d3876b9ec6b27.jpg", "jpg", 47732);
  danbooru_generate_coefficient_sql(dump, "images/01b8d937bdb73f723ec57d1863638cd7.jpg", "jpg", 32037);
  danbooru_generate_coefficient_sql(dump, "images/5466c4a8b8c3b7eaed418306afd4bb5a.jpg", "jpg", 125231);
  danbooru_generate_coefficient_sql(dump, "images/1bd7055e01908e4424d43244eab28493.jpg", "jpg", 106105);
  danbooru_generate_coefficient_sql(dump, "images/cb7472451d52720bb810bfa43be461d8.jpg", "jpg", 83053);
  danbooru_generate_coefficient_sql(dump, "images/eaca4f421a689872971123deaa739349.jpg", "jpg", 117845);
  danbooru_generate_coefficient_sql(dump, "images/977d42503f592e12692662e2e1ece4a9.jpg", "jpg", 3210);
  danbooru_generate_coefficient_sql(dump, "images/639969044642a1c152aebb467e8ef4ad.jpg", "jpg", 3847);
  danbooru_generate_coefficient_sql(dump, "images/8ac6281b5052d22e8bb7b83721da9856.jpg", "jpg", 6833);
  danbooru_generate_coefficient_sql(dump, "images/a4131ec87f28d00a1e1f4731852166c5.jpg", "jpg", 78726);
  danbooru_generate_coefficient_sql(dump, "images/ebab0f26b2ce5d02adac5e55a4724cab.jpg", "jpg", 93047);
  danbooru_generate_coefficient_sql(dump, "images/c8b0bec08f7987979d306dad6973156d.jpg", "jpg", 38667);
  danbooru_generate_coefficient_sql(dump, "images/59f8472356f647f719503f51fa442af5.jpg", "jpg", 46338);
  danbooru_generate_coefficient_sql(dump, "images/54ea75c8408304884d0763533e1f2727.jpg", "jpg", 141137);
  danbooru_generate_coefficient_sql(dump, "images/ab57cc6d486e72c01722d26bc29ad7da.jpg", "jpg", 99243);
  danbooru_generate_coefficient_sql(dump, "images/5c6c1db9b4094a6cca1a6ae2f69cf72f.jpg", "jpg", 105519);
  danbooru_generate_coefficient_sql(dump, "images/a390f0f4915395d185f1ec5b07e0ff56.gif", "gif", 12877);
  danbooru_generate_coefficient_sql(dump, "images/37153e9b6598e77499d60597f003127f.jpg", "jpg", 85290);
  danbooru_generate_coefficient_sql(dump, "images/b70004c74f54f7e7cd4aecef30f13b98.jpg", "jpg", 135201);
  danbooru_generate_coefficient_sql(dump, "images/6c7b84f15b22dbfc72bbbe285439d6b8.jpg", "jpg", 77672);
  danbooru_generate_coefficient_sql(dump, "images/a48c986117929740fa9cecf66618ba06.jpg", "jpg", 115568);
  danbooru_generate_coefficient_sql(dump, "images/a21a6a7fbdf4fe806524d569f00e4aed.jpg", "jpg", 118347);
  danbooru_generate_coefficient_sql(dump, "images/91cc8d0aca2de1d466df20e9f4c59ea3.jpg", "jpg", 107381);
  danbooru_generate_coefficient_sql(dump, "images/56fdc4a804e26ed03a39150b4083746f.jpg", "jpg", 87395);
  danbooru_generate_coefficient_sql(dump, "images/cd674834ecc6e217878be8a7da7445f5.jpg", "jpg", 39740);
  danbooru_generate_coefficient_sql(dump, "images/dcc4e01f21c765f3ec13e0a3f0342024.jpeg", "jpg", 136361);
  danbooru_generate_coefficient_sql(dump, "images/6e3bdcd896260e4bb08abca827f757b5.jpg", "jpg", 77768);
  danbooru_generate_coefficient_sql(dump, "images/ab5560afc8966842ddf9bfd0ddcac830.jpg", "jpg", 56161);
  danbooru_generate_coefficient_sql(dump, "images/507a7f8c792d96da72b1c4d05cccfb8c.jpg", "jpg", 691);
  danbooru_generate_coefficient_sql(dump, "images/4bcc72ce9132a906463e4b515c04de3a.png", "png", 84452);
  danbooru_generate_coefficient_sql(dump, "images/9c5a77f872b0997fd57bbd6679b1d4c7.jpg", "jpg", 25218);
  danbooru_generate_coefficient_sql(dump, "images/28e44f72e6a80e5f05c53dd85200b2ee.jpg", "jpg", 120587);
  danbooru_generate_coefficient_sql(dump, "images/5fae850a1b523fb60d6e621489f5e9a1.jpg", "jpg", 106844);
  danbooru_generate_coefficient_sql(dump, "images/4f8a35577843e5266b87834c8e60acd2.jpg", "jpg", 4863);
  danbooru_generate_coefficient_sql(dump, "images/9304771e5c53703b59adb3cfbc73052e.jpg", "jpg", 117648);
  danbooru_generate_coefficient_sql(dump, "images/d1e48ae7937a44bd89817fa40b242b87.jpg", "jpg", 59791);
  danbooru_generate_coefficient_sql(dump, "images/eb6e72767896a62bcd98a99924975065.jpg", "jpg", 84417);
  danbooru_generate_coefficient_sql(dump, "images/b4aacbedb33e1ffa49bf2a03bdbaaef9.png", "png", 66533);
  danbooru_generate_coefficient_sql(dump, "images/127744017641e8d9476da5b354b35427.jpg", "jpg", 13754);
  danbooru_generate_coefficient_sql(dump, "images/d76021c55b8f6d411bb8d8e47388b927.jpg", "jpg", 64653);
  danbooru_generate_coefficient_sql(dump, "images/80f3328a73dc32a50726ff031ebd41e6.jpg", "jpg", 33144);
  danbooru_generate_coefficient_sql(dump, "images/d88a76ba2cc6ca403d16dcdabab5e1e6.jpg", "jpg", 116502);
  danbooru_generate_coefficient_sql(dump, "images/d08a6c9d19f4a0e898ea2228bf540e51.jpg", "jpg", 130398);
  danbooru_generate_coefficient_sql(dump, "images/c9565499a979e04c7b26e1e0169a4298.jpg", "jpg", 138810);
  danbooru_generate_coefficient_sql(dump, "images/bf83aaf29c39b68472d50fdc9c0a3208.jpeg", "jpg", 141272);
  danbooru_generate_coefficient_sql(dump, "images/b5ef0961c4b032837d1c56f70ed701f8.jpg", "jpg", 48448);
  danbooru_generate_coefficient_sql(dump, "images/897d233b4e01d352c368461deb4f73b9.jpg", "jpg", 111974);
  danbooru_generate_coefficient_sql(dump, "images/d7d62662609cfbef2100309970f2521a.jpg", "jpg", 77379);
  danbooru_generate_coefficient_sql(dump, "images/4bbaf63f90f0dcf95d3bd1f740ee6e84.jpg", "jpg", 71938);
  danbooru_generate_coefficient_sql(dump, "images/49e4af6d29d4d7da66145807e66dcef3.jpg", "jpg", 239);
  danbooru_generate_coefficient_sql(dump, "images/2cea7a09cbc505a45c4e00f95678fc17.jpg", "jpg", 47511);
  danbooru_generate_coefficient_sql(dump, "images/745e30dfb325508928a967c4b9327ca7.jpg", "jpg", 74444);
  danbooru_generate_coefficient_sql(dump, "images/f0b8b214d9b6561981ef612a30b97458.jpg", "jpg", 82056);
  danbooru_generate_coefficient_sql(dump, "images/e52d9b47e256f4321a974cb1e3d2de81.jpg", "jpg", 92694);
  danbooru_generate_coefficient_sql(dump, "images/7f329a846fd671163f94860ffe1fc7ea.jpg", "jpg", 129967);
  danbooru_generate_coefficient_sql(dump, "images/8259626af78c0eb297cb7e22b0b092fc.jpg", "jpg", 72090);
  danbooru_generate_coefficient_sql(dump, "images/233c08faa0848288434b460ce2e7e2a5.jpg", "jpg", 106809);
  danbooru_generate_coefficient_sql(dump, "images/b8afc96dcc60242656ed73171a409363.jpg", "jpg", 20451);
  danbooru_generate_coefficient_sql(dump, "images/f7297a307e05b8dae52fc53e23740250.jpg", "jpg", 2827);
  danbooru_generate_coefficient_sql(dump, "images/025fcadd6006c2cbb015711c65084c13.jpg", "jpg", 33010);
  danbooru_generate_coefficient_sql(dump, "images/cec8995797b5b320f16661db025fc747.jpg", "jpg", 89146);
  danbooru_generate_coefficient_sql(dump, "images/0f9fa8960f47ea3120bd2a75385974bc.png", "png", 21063);
  danbooru_generate_coefficient_sql(dump, "images/160766142d7899c961f5829559f21a78.jpg", "jpg", 141219);
  danbooru_generate_coefficient_sql(dump, "images/3cb24e1cc8d97414b9243586c3fd31f5.jpg", "jpg", 13715);
  danbooru_generate_coefficient_sql(dump, "images/1a373983dc7f9f25353c4f231115db40.jpg", "jpg", 112900);
  danbooru_generate_coefficient_sql(dump, "images/90a6137862207d580a73be5420f0dc60.jpg", "jpg", 20929);
  danbooru_generate_coefficient_sql(dump, "images/2be513803a71050116b56b20f9868c4e.jpg", "jpg", 16200);
  danbooru_generate_coefficient_sql(dump, "images/6c607357907ca4395a5eba73b3526a42.jpg", "jpg", 22380);
  danbooru_generate_coefficient_sql(dump, "images/51ce098110639e03a7e6583bf1fd2228.jpg", "jpg", 79569);
  danbooru_generate_coefficient_sql(dump, "images/22ab702531f3aa93880b14a55a7468ef.jpg", "jpg", 68362);
  danbooru_generate_coefficient_sql(dump, "images/18717a32b6e7fef83b59584e377a42c2.jpg", "jpg", 6592);
  danbooru_generate_coefficient_sql(dump, "images/ab770ab0e596eb36a410ee2b2b904352.jpg", "jpg", 115903);
  danbooru_generate_coefficient_sql(dump, "images/dd6861c37691298e1af87023641189ef.jpg", "jpg", 120258);
  danbooru_generate_coefficient_sql(dump, "images/d9f55da7349b35544fb1e464ac3a550c.jpg", "jpg", 78381);
  danbooru_generate_coefficient_sql(dump, "images/1c7df2dcd537237ba5265196f8566c8a.jpg", "jpg", 63979);
  danbooru_generate_coefficient_sql(dump, "images/014fe9f67a8beb360fa8ecbc9061a5ed.jpg", "jpg", 53945);
  danbooru_generate_coefficient_sql(dump, "images/314837d02db87c6026814897b9fe8dba.jpg", "jpg", 136480);
  danbooru_generate_coefficient_sql(dump, "images/c4eb77de1b1f57c62454a0890f9df8c2.jpg", "jpg", 66074);
  danbooru_generate_coefficient_sql(dump, "images/54af7a1b699b939c0a8a58d692edda41.jpg", "jpg", 100166);
  danbooru_generate_coefficient_sql(dump, "images/517dafcd6c1e328cb005bdd3c4e4c4f5.jpg", "jpg", 107387);
  danbooru_generate_coefficient_sql(dump, "images/2b2fd95e5f51445b9fdb74d6f3f3e05d.jpg", "jpg", 67778);
  danbooru_generate_coefficient_sql(dump, "images/530d8972e36031a82e0655d5c8d69184.jpg", "jpg", 724);
  danbooru_generate_coefficient_sql(dump, "images/8a101fb207f50248bac101285507661e.jpg", "jpg", 127552);
  danbooru_generate_coefficient_sql(dump, "images/3840d2e29f90d93fcaad35ffaff95354.jpg", "jpg", 83982);
  danbooru_generate_coefficient_sql(dump, "images/f66935f00ff3219fe04f85341a8a134e.jpg", "jpg", 106186);
  danbooru_generate_coefficient_sql(dump, "images/e1af947a2d1c0c9b64b0822a88474d50.jpg", "jpg", 17099);
  danbooru_generate_coefficient_sql(dump, "images/6499136fb83abad72b559c7c1e891ca4.gif", "gif", 68485);
  danbooru_generate_coefficient_sql(dump, "images/4c7c23776740f36a753871d316f942d9.jpg", "jpg", 39164);
  danbooru_generate_coefficient_sql(dump, "images/d5af8b9f24fe50dff5144851fa8c1dd2.jpg", "jpg", 69823);
  danbooru_generate_coefficient_sql(dump, "images/873947c02245227b9b87206b40a7336c.jpg", "jpg", 43979);
  danbooru_generate_coefficient_sql(dump, "images/b99df880abb38bd14a67dbf9ecf3054d.jpg", "jpg", 67534);
  danbooru_generate_coefficient_sql(dump, "images/54c6987c5a563f748a6eda08fdaff352.jpg", "jpg", 103658);
  danbooru_generate_coefficient_sql(dump, "images/1eb00295bc15a4d303bf82f3e2eedb6e.jpg", "jpg", 120172);
  danbooru_generate_coefficient_sql(dump, "images/0899ab812924f778efd24144581d5358.jpg", "jpg", 66275);
  danbooru_generate_coefficient_sql(dump, "images/ba4d8a0acd873266b6704e1ab2f7d764.jpg", "jpg", 109648);
  danbooru_generate_coefficient_sql(dump, "images/64d0dad36a4ceaa43adfd16c6c4aee94.jpg", "jpg", 115035);
  danbooru_generate_coefficient_sql(dump, "images/ec632a34ae307c659672e9fc1af16de0.jpg", "jpg", 19834);
  danbooru_generate_coefficient_sql(dump, "images/acddea8d55bd0a9a2aca859b63ef6afc.jpg", "jpg", 122352);
  danbooru_generate_coefficient_sql(dump, "images/45a6f24f05216c40f880679f91fc1dd7.jpg", "jpg", 79268);
  danbooru_generate_coefficient_sql(dump, "images/4c9d10dfb63785c7ec9d98f0713c71e8.jpg", "jpg", 22520);
  danbooru_generate_coefficient_sql(dump, "images/8adb962f6917152e3181fcdeaec43ad4.jpg", "jpg", 99182);
  danbooru_generate_coefficient_sql(dump, "images/4c02f96b73523d263d6031bb3c17166c.jpeg", "jpg", 137035);
  danbooru_generate_coefficient_sql(dump, "images/d589185e3b939494308c87ed000a01a1.jpg", "jpg", 95582);
  danbooru_generate_coefficient_sql(dump, "images/1c23360f79061fc96b80a26e8a97de77.jpg", "jpg", 63580);
  danbooru_generate_coefficient_sql(dump, "images/a9f45e23066d7cf6bf083f0f4ae794ce.jpg", "jpg", 115624);
  danbooru_generate_coefficient_sql(dump, "images/94c94d764f70d227a02fc1fc50eea13b.jpg", "jpg", 16831);
  danbooru_generate_coefficient_sql(dump, "images/45aa0319f5ed9671a5adb66fc577c520.jpg", "jpg", 74826);
  danbooru_generate_coefficient_sql(dump, "images/8019316abf916ffdd658e9f9e8722ed5.jpg", "jpg", 51313);
  danbooru_generate_coefficient_sql(dump, "images/766699f8df8756dc8d9dc216eab627ab.jpg", "jpg", 131658);
  danbooru_generate_coefficient_sql(dump, "images/eaa41182d034b7def93464c18d18f04f.jpg", "jpg", 62353);
  danbooru_generate_coefficient_sql(dump, "images/6ed862a4143379a8849d4c41a7abfa22.jpg", "jpg", 82031);
  danbooru_generate_coefficient_sql(dump, "images/284932e1db4cfbf1f265dc0b6bfc181d.jpg", "jpg", 137947);
  danbooru_generate_coefficient_sql(dump, "images/05cb1de4f3b5e50bb59f031ca1806ffe.jpg", "jpg", 90301);
  danbooru_generate_coefficient_sql(dump, "images/4d2e42060ff3827d151094c0fd9a1b5c.jpg", "jpg", 105669);
  danbooru_generate_coefficient_sql(dump, "images/f458cdf04d98f2c9ca6a324b91f807c2.jpg", "jpg", 139793);
  danbooru_generate_coefficient_sql(dump, "images/2deaabcc5c0c8d9126b53e035d3a9ad2.jpg", "jpg", 126344);
  danbooru_generate_coefficient_sql(dump, "images/f28458a24c8d314e955ec2db89784cb5.jpg", "jpg", 85759);
  danbooru_generate_coefficient_sql(dump, "images/30a42203167caa0ad3a83878c00820a3.jpg", "jpg", 80430);
  danbooru_generate_coefficient_sql(dump, "images/0d13aa02a99ccacf909172e843dd3a7c.gif", "gif", 310);
  danbooru_generate_coefficient_sql(dump, "images/e7d602eab65a5e6ab475a93a2c6499d3.jpg", "jpg", 60889);
  danbooru_generate_coefficient_sql(dump, "images/b0c4e8aadf33b5302008d3b2770e11eb.jpg", "jpg", 132520);
  danbooru_generate_coefficient_sql(dump, "images/058575c6539866d284ded967774932db.jpg", "jpg", 19649);
  danbooru_generate_coefficient_sql(dump, "images/48637c5f432b9168f7c7dd1cd2063c58.jpg", "jpg", 109011);
  danbooru_generate_coefficient_sql(dump, "images/eebb50feb7597e6c3f32df28ded49cf9.jpg", "jpg", 57858);
  danbooru_generate_coefficient_sql(dump, "images/907663d9954acce25e2037c853c6c9ce.jpg", "jpg", 70826);
  danbooru_generate_coefficient_sql(dump, "images/afe241320ca6168f4506e7f70ea093f4.jpg", "jpg", 112229);
  danbooru_generate_coefficient_sql(dump, "images/91e0948ae8cd72bfba3790f85236fd8e.jpg", "jpg", 113849);
  danbooru_generate_coefficient_sql(dump, "images/c816f63292d287bc976d1eae81c239df.gif", "gif", 50578);
  danbooru_generate_coefficient_sql(dump, "images/f134dda883123506ce5be67229b9a387.jpg", "jpg", 27292);
  danbooru_generate_coefficient_sql(dump, "images/acd809ce9a6e3404f0c227a0ebc22776.jpg", "jpg", 5898);
  danbooru_generate_coefficient_sql(dump, "images/dafd19c5854b0451dc8050273e50cda2.jpg", "jpg", 53485);
  danbooru_generate_coefficient_sql(dump, "images/b7242f68cbf3635f5b4cfcec254ec4d5.jpg", "jpg", 71693);
  danbooru_generate_coefficient_sql(dump, "images/0762028971aaa4bf93ec5bfbb46f9c79.jpg", "jpg", 46772);
  danbooru_generate_coefficient_sql(dump, "images/ffba116b704e2934de7835c24ff4e289.gif", "gif", 74768);
  danbooru_generate_coefficient_sql(dump, "images/0177686f4472d9d696aacd03c8a8c68f.jpg", "jpg", 136591);
  danbooru_generate_coefficient_sql(dump, "images/4f306fcd08495ac89034cbfe4b2b6a16.jpg", "jpg", 32731);
  danbooru_generate_coefficient_sql(dump, "images/44e9959f99aad14b774f4273d27c3904.jpg", "jpg", 84882);
  danbooru_generate_coefficient_sql(dump, "images/34a7933e945d0b2eb5ce2f10c1f3ca2b.jpg", "jpg", 70385);
  danbooru_generate_coefficient_sql(dump, "images/e867e2046f12d43a43b4b184fdcaf719.png", "png", 130316);
  danbooru_generate_coefficient_sql(dump, "images/62569bf2554031df35c5ffd75f7dae50.jpg", "jpg", 86279);
  danbooru_generate_coefficient_sql(dump, "images/b48d4d18910ab8733fbbc84dfd5c7b58.jpg", "jpg", 105039);
  danbooru_generate_coefficient_sql(dump, "images/771d913233002e114d04621fd0bf4449.jpg", "jpg", 64323);
  danbooru_generate_coefficient_sql(dump, "images/90470251ff3b360b9cbb86c5a4c58b88.jpg", "jpg", 107854);
  danbooru_generate_coefficient_sql(dump, "images/22cf11b2ffb1e5302436ec13f452f1b7.jpg", "jpg", 74588);
  danbooru_generate_coefficient_sql(dump, "images/116fb0d0e45b16875910a2905f6b3123.jpg", "jpg", 79613);
  danbooru_generate_coefficient_sql(dump, "images/a0300a28ac4dcdddbc9f83c72a397400.jpg", "jpg", 102745);
  danbooru_generate_coefficient_sql(dump, "images/159cb77c9fb28b2e0c3109fed56cad91.gif", "gif", 23124);
  danbooru_generate_coefficient_sql(dump, "images/8b4c317d3ba61e5ba8cf53c834407367.jpg", "jpg", 86534);
  danbooru_generate_coefficient_sql(dump, "images/825018601739c0bcb9ba0110f2d082fb.jpg", "jpg", 120751);
  danbooru_generate_coefficient_sql(dump, "images/9b4a0fe42dcccbf32c01eca91233bc91.jpg", "jpg", 27725);
  danbooru_generate_coefficient_sql(dump, "images/3873bb6ff150d6a34fadc38730c4f312.jpg", "jpg", 40077);
  danbooru_generate_coefficient_sql(dump, "images/0bc5432287033cb9513950163c971ffc.jpg", "jpg", 11134);
  danbooru_generate_coefficient_sql(dump, "images/fb6fcd2393f7d79687b5640652f7bcc6.jpg", "jpg", 13516);
  danbooru_generate_coefficient_sql(dump, "images/21310eab69cb718ad3d9e9770bba5b66.jpg", "jpg", 19485);
  danbooru_generate_coefficient_sql(dump, "images/8168847cad749261216d761960e5619d.gif", "gif", 69836);
  danbooru_generate_coefficient_sql(dump, "images/10f9ed2061f427ea21443fd90e642035.jpg", "jpg", 23681);
  danbooru_generate_coefficient_sql(dump, "images/7e46d24f61a654335571470a576eb2c8.jpg", "jpg", 67437);
  danbooru_generate_coefficient_sql(dump, "images/8cf6ca9d11358485829542a326c5781d.jpg", "jpg", 1235);
  danbooru_generate_coefficient_sql(dump, "images/695c2d89797264b29f429d6f7f8f058b.jpg", "jpg", 69904);
  danbooru_generate_coefficient_sql(dump, "images/a1f046557fb7c96dc266f959b027a32a.jpg", "jpg", 27243);
  danbooru_generate_coefficient_sql(dump, "images/048f232b495cd4135c36df787232b0d1.png", "png", 92592);
  danbooru_generate_coefficient_sql(dump, "images/edf1cc6976f3c5d486ead35de5fd734f.jpg", "jpg", 51122);
  danbooru_generate_coefficient_sql(dump, "images/920d4c8f608cd00f844006b3b7641945.jpg", "jpg", 49820);
  danbooru_generate_coefficient_sql(dump, "images/d75ac44b2e38000cf2c19c6795f36582.jpg", "jpg", 90365);
  danbooru_generate_coefficient_sql(dump, "images/c667bdf01647e777e94428acc8b993c9.jpg", "jpg", 112215);
  danbooru_generate_coefficient_sql(dump, "images/4ddad1e2db31644b5876ba764481bf65.jpg", "jpg", 5666);
  danbooru_generate_coefficient_sql(dump, "images/c491d446b03e82972203718d43d73f0f.gif", "gif", 123779);
  danbooru_generate_coefficient_sql(dump, "images/0f6b099b8c153bd2dd927cf309cd5a07.jpg", "jpg", 20635);
  danbooru_generate_coefficient_sql(dump, "images/f90582a557c244582bc447905df40236.jpg", "jpg", 133673);
  danbooru_generate_coefficient_sql(dump, "images/38210883cd61750ec6c9d7162c7d9723.jpg", "jpg", 62822);
  danbooru_generate_coefficient_sql(dump, "images/64c1781cb5910405d65cb22ae405ef08.jpg", "jpg", 84787);
  danbooru_generate_coefficient_sql(dump, "images/50da78f8465b7e4717a48948dcf5f872.jpeg", "jpg", 133347);
  danbooru_generate_coefficient_sql(dump, "images/0c875b7c4a87e28960922db1019e18ee.jpg", "jpg", 8256);
  danbooru_generate_coefficient_sql(dump, "images/ea98f7ee5828974d444f9a960d1faf4f.jpg", "jpg", 45951);
  danbooru_generate_coefficient_sql(dump, "images/3d031d8b48d41ab94b88fa09d73df48d.jpg", "jpg", 52103);
  danbooru_generate_coefficient_sql(dump, "images/da78f53478d7cb6d38a0b7542c3a2fec.jpg", "jpg", 3738);
  danbooru_generate_coefficient_sql(dump, "images/145d12a9d3ebc12f02e4d82fbcc280ee.jpg", "jpg", 58869);
  danbooru_generate_coefficient_sql(dump, "images/5a42ad78da11844aad46702aa6dc98d7.jpg", "jpg", 67679);
  danbooru_generate_coefficient_sql(dump, "images/11698579204f7ef8840e1468228249bd.jpg", "jpg", 32080);
  danbooru_generate_coefficient_sql(dump, "images/698a0e21348b7e831bb7322330a97391.jpg", "jpg", 83495);
  danbooru_generate_coefficient_sql(dump, "images/bae969fd485d059af8c29c0ada4b2352.jpg", "jpg", 21561);
  danbooru_generate_coefficient_sql(dump, "images/997fc366abd24bcfd596521d70ff9f41.jpg", "jpg", 122861);
  danbooru_generate_coefficient_sql(dump, "images/2752073cea23894d68a007b0c3c2ca96.jpg", "jpg", 8174);
  danbooru_generate_coefficient_sql(dump, "images/504031223a80ba34b631405f3faa085b.jpg", "jpg", 67323);
  danbooru_generate_coefficient_sql(dump, "images/3c5cf764be69f60a9bdd4cb277eeb781.jpg", "jpg", 127943);
  danbooru_generate_coefficient_sql(dump, "images/3534903540e600bd534982fd473bdfb7.jpg", "jpg", 3031);
  danbooru_generate_coefficient_sql(dump, "images/370519e8d3161e6d03a0a62cf0946fed.jpg", "jpg", 66119);
  danbooru_generate_coefficient_sql(dump, "images/e3fa274789f977ee2bca266e807aebbd.jpg", "jpg", 78749);
  danbooru_generate_coefficient_sql(dump, "images/9608bf74c68b7e052695db2823a5a5a0.jpg", "jpg", 95238);
  danbooru_generate_coefficient_sql(dump, "images/0688baedd62fb95c6b58a6dff67927f4.jpg", "jpg", 6967);
  danbooru_generate_coefficient_sql(dump, "images/a65672e6fcdc25e5287070793b95044f.jpg", "jpg", 21537);
  danbooru_generate_coefficient_sql(dump, "images/ae5a9092f08ff9099ac7e1d79abb3bc6.jpg", "jpg", 108583);
  danbooru_generate_coefficient_sql(dump, "images/4a1889f2d7ce0ec9641b4e4b49636e9e.jpg", "jpg", 90148);
  danbooru_generate_coefficient_sql(dump, "images/111fe577cfb9fae766fc3a4f3d117b7b.jpg", "jpg", 111107);
  danbooru_generate_coefficient_sql(dump, "images/5b5e0e8f5a843ff9669bfc2b49c11d28.gif", "gif", 43972);
  danbooru_generate_coefficient_sql(dump, "images/3fe878dd948b75f89a21fdf0f9abec9e.jpg", "jpg", 20441);
  danbooru_generate_coefficient_sql(dump, "images/f0583b6a257da6faa381c130a31e5f3d.gif", "gif", 110952);
  danbooru_generate_coefficient_sql(dump, "images/3578c88fa6afa16e3b460cad386ee4f7.jpg", "jpg", 134596);
  danbooru_generate_coefficient_sql(dump, "images/a462020bb37cec7dc40a4ea26972a048.jpg", "jpg", 63024);
  danbooru_generate_coefficient_sql(dump, "images/12f7d401a03fa257d2b60fd8f3f70a06.jpg", "jpg", 46269);
  danbooru_generate_coefficient_sql(dump, "images/1ae0baaf54d6d2f36bc0eb87542134c4.jpg", "jpg", 64186);
  danbooru_generate_coefficient_sql(dump, "images/9a0ad1f94cc5ec1ae0845d3713c1fc1c.jpg", "jpg", 83084);
  danbooru_generate_coefficient_sql(dump, "images/c357daf2a2f3aa126ee448091d37f350.png", "png", 134312);
  danbooru_generate_coefficient_sql(dump, "images/a6ddf812d980cef1defc51d52640315c.jpg", "jpg", 11529);
  danbooru_generate_coefficient_sql(dump, "images/df937d2d49225ca14ac258524efdc2a6.jpg", "jpg", 91942);
  danbooru_generate_coefficient_sql(dump, "images/12a26bf53b38297809513c00f7f34bb2.jpg", "jpg", 88113);
  danbooru_generate_coefficient_sql(dump, "images/d830e3b2b513a2dcb190745bd17a4ad1.jpg", "jpg", 56375);
  danbooru_generate_coefficient_sql(dump, "images/33b5b59d658c00ce5d3fdaa6d7b5b7c0.jpg", "jpg", 102390);
  danbooru_generate_coefficient_sql(dump, "images/f9cfef5373a1070fc85c0b78989bab8a.jpg", "jpg", 121203);
  danbooru_generate_coefficient_sql(dump, "images/86459bc21e2e05968a24eb03ceed2c1e.jpg", "jpg", 114389);
  danbooru_generate_coefficient_sql(dump, "images/2069bd293029df7a149f5790e9f8a105.jpg", "jpg", 142690);
  danbooru_generate_coefficient_sql(dump, "images/64faa78b73d606a6f94746431699f974.jpg", "jpg", 2018);
  danbooru_generate_coefficient_sql(dump, "images/1bbbae69d7de3b6058155f76a40fb39c.jpg", "jpg", 79092);
  danbooru_generate_coefficient_sql(dump, "images/01489c835169a0025495fa89e09fc79b.jpg", "jpg", 13525);
  danbooru_generate_coefficient_sql(dump, "images/53e8389c0cae2ab62ae41beb94ffc284.jpg", "jpg", 48061);
  danbooru_generate_coefficient_sql(dump, "images/696e8181dc38b41b1a851ffb447075d0.png", "png", 523);
  danbooru_generate_coefficient_sql(dump, "images/049f46485e9cdb13f9eba7deba1eb565.jpg", "jpg", 89045);
  danbooru_generate_coefficient_sql(dump, "images/0fdf8fed49da2ce8c9d6ba70e3e8c897.jpg", "jpg", 26877);
  danbooru_generate_coefficient_sql(dump, "images/6dbc3cfc642df29bf1ddd97176b6599f.jpg", "jpg", 114882);
  danbooru_generate_coefficient_sql(dump, "images/86a009873a7a5081461f49b69e4aeb9c.jpg", "jpg", 58508);
  danbooru_generate_coefficient_sql(dump, "images/f8f686fb88dff81c2b8b3363cdf9e731.jpg", "jpg", 132670);
  danbooru_generate_coefficient_sql(dump, "images/c6826493449c8a3a3c092cee0360f96e.jpg", "jpg", 85708);
  danbooru_generate_coefficient_sql(dump, "images/c228d4c530a963910c5e37986803d8d9.jpg", "jpg", 21595);
  danbooru_generate_coefficient_sql(dump, "images/f2ba9d8c7ebe0d2fb923c574cfd7f4ee.jpg", "jpg", 105758);
  danbooru_generate_coefficient_sql(dump, "images/d6a6fa34d89a96054eba969a2602e8f9.jpg", "jpg", 8166);
  danbooru_generate_coefficient_sql(dump, "images/4339d3899ee5569b809aad969ef7081e.jpg", "jpg", 34980);
  danbooru_generate_coefficient_sql(dump, "images/9d8643da1543ca7ecb2960051863ded0.jpg", "jpg", 110647);
  danbooru_generate_coefficient_sql(dump, "images/30235b3aa389cce67c6b08254a463f9f.jpg", "jpg", 83859);
  danbooru_generate_coefficient_sql(dump, "images/365b97f7038ff5decc6accb25eb916f6.png", "png", 130846);
  danbooru_generate_coefficient_sql(dump, "images/d955e27b2e5219d6d8ec06040d0251c6.jpg", "jpg", 65696);
  danbooru_generate_coefficient_sql(dump, "images/2d668a5a5b5f427fad57c4dfd496a230.jpg", "jpg", 90948);
  danbooru_generate_coefficient_sql(dump, "images/346f0021b8e5eb96e3d1a8df79be92ab.jpg", "jpg", 109038);
  danbooru_generate_coefficient_sql(dump, "images/fb5833828ba1461e87bf88f88eda7da4.jpg", "jpg", 63470);
  danbooru_generate_coefficient_sql(dump, "images/01ada2ff661fd59c7045d5af80ac6321.jpg", "jpg", 78134);
  danbooru_generate_coefficient_sql(dump, "images/743552192a1f932e18c898bd61f71afd.jpg", "jpg", 83615);
  danbooru_generate_coefficient_sql(dump, "images/062100c104d678ec25233a8b3a3ba0e7.jpg", "jpg", 126055);
  danbooru_generate_coefficient_sql(dump, "images/56e3473d4dc41e25cd1b5f402c5db2bd.jpg", "jpg", 54064);
  danbooru_generate_coefficient_sql(dump, "images/2cf9ecb9291f7df1de0406577a2312ec.jpg", "jpg", 116426);
  danbooru_generate_coefficient_sql(dump, "images/741dbe312aa3a036d427605a3a7bf66a.jpg", "jpg", 107047);
  danbooru_generate_coefficient_sql(dump, "images/aee01d0c6d4cae003bba92dff9fffebc.jpg", "jpg", 5464);
  danbooru_generate_coefficient_sql(dump, "images/dd630c51568cffbd55a88e62f6b24bd7.jpg", "jpg", 62840);
  danbooru_generate_coefficient_sql(dump, "images/77fa1d9f33a3db097344def0f4ba7040.jpg", "jpg", 48466);
  danbooru_generate_coefficient_sql(dump, "images/f21474e78622f06bdd8186a73a6d5bf6.jpg", "jpg", 34697);
  danbooru_generate_coefficient_sql(dump, "images/69990b076cfa4f576f789b6ef48c6deb.jpg", "jpg", 47905);
  danbooru_generate_coefficient_sql(dump, "images/a498c434b262cd332682a3a888faba4d.jpg", "jpg", 8720);
  danbooru_generate_coefficient_sql(dump, "images/83ab5ea55e2c31a2fa8ad23b85baa4fa.jpg", "jpg", 80891);
  danbooru_generate_coefficient_sql(dump, "images/7fe335954b4520202360a686732785b7.jpg", "jpg", 61324);
  danbooru_generate_coefficient_sql(dump, "images/33157fd85cf3393405328411406584bf.jpg", "jpg", 92392);
  danbooru_generate_coefficient_sql(dump, "images/aeb2b0dcb4adcd84ff95d9993ca42f33.jpg", "jpg", 104382);
  danbooru_generate_coefficient_sql(dump, "images/5bc570d89306c95dfccffca4ba3f39e9.jpg", "jpg", 79109);
  danbooru_generate_coefficient_sql(dump, "images/f569b73146e1cf23afefcb29ce57610f.jpg", "jpg", 68011);
  danbooru_generate_coefficient_sql(dump, "images/42bf52b35a0a47b2e111dab605c78aa9.jpg", "jpg", 17784);
  danbooru_generate_coefficient_sql(dump, "images/5aeb161cf675ea7d37d8eec62d8c4812.jpg", "jpg", 73080);
  danbooru_generate_coefficient_sql(dump, "images/9ba1608c4b4e48b521b6f2c47de9511e.jpeg", "jpg", 137968);
  danbooru_generate_coefficient_sql(dump, "images/5c929ee5232b868dc88967137d8bfacd.jpg", "jpg", 36369);
  danbooru_generate_coefficient_sql(dump, "images/5e14f96b5f059cedcec0a7dcae2041b1.jpg", "jpg", 95431);
  danbooru_generate_coefficient_sql(dump, "images/a5e2d45ae6c8b692cfa79e63ac41aea0.jpg", "jpg", 123271);
  danbooru_generate_coefficient_sql(dump, "images/72c0ac8f6bd9bae44fc438ca14cf13f4.jpg", "jpg", 58908);
  danbooru_generate_coefficient_sql(dump, "images/06d7fbbe3ed8b3bfb40a5c43f916a5a2.jpg", "jpg", 125392);
  danbooru_generate_coefficient_sql(dump, "images/0c2b9744fb7b2ecc2188a3eddbb013ac.jpg", "jpg", 61186);
  danbooru_generate_coefficient_sql(dump, "images/578926fdfc19e3e29b7ac775ca66c6f6.jpg", "jpg", 124114);
  danbooru_generate_coefficient_sql(dump, "images/eb1975af2a0073faa05ac0a86bb29525.jpg", "jpg", 57588);
  danbooru_generate_coefficient_sql(dump, "images/fc3ceaaba9ebcd74f396846165f7efe5.gif", "gif", 44288);
  danbooru_generate_coefficient_sql(dump, "images/b9eff605234adcead25ed8187ac63391.jpg", "jpg", 88973);
  danbooru_generate_coefficient_sql(dump, "images/fee1dbb53e9159d484a836146d9ae169.jpg", "jpg", 11808);
  danbooru_generate_coefficient_sql(dump, "images/bcd695f7bace7262ea2dec60ad5d8a4a.jpg", "jpg", 58463);
  danbooru_generate_coefficient_sql(dump, "images/615fe7a7ffb1ed79b21f012c82005a7c.jpg", "jpg", 103484);
  danbooru_generate_coefficient_sql(dump, "images/231e0cd39dc5baf9cf475d6c740cf93f.gif", "gif", 90897);
  danbooru_generate_coefficient_sql(dump, "images/73dde0d163682ceaf4633005a33c5b5c.jpg", "jpg", 55908);
  danbooru_generate_coefficient_sql(dump, "images/b970e4dae047f2e5f33b54b5ac918252.jpg", "jpg", 31476);
  danbooru_generate_coefficient_sql(dump, "images/0281cd97ae916e5bfd8b715c8384a2a2.jpg", "jpg", 73669);
  danbooru_generate_coefficient_sql(dump, "images/58d55b616295fdfaf98525da6fa960a6.png", "png", 131209);
  danbooru_generate_coefficient_sql(dump, "images/d73adc662dc5f08a06717826683b87cc.jpg", "jpg", 34932);
  danbooru_generate_coefficient_sql(dump, "images/cfe66a584a22d77e624322b3eab39915.jpg", "jpg", 74450);
  danbooru_generate_coefficient_sql(dump, "images/b64659fc72b8d566f9fc8240ae853812.jpg", "jpg", 85432);
  danbooru_generate_coefficient_sql(dump, "images/63565035cdac18dc0163881ffc33b1da.jpg", "jpg", 109953);
  danbooru_generate_coefficient_sql(dump, "images/f6309f2a047bd2ea3d6c37c742c23c59.jpg", "jpg", 101555);
  danbooru_generate_coefficient_sql(dump, "images/5e1986ddfe9ff391e20047b4666ea911.jpg", "jpg", 90415);
  danbooru_generate_coefficient_sql(dump, "images/76fd82d9b1cb6d4c9cbdffcb2015aa41.jpg", "jpg", 131038);
  danbooru_generate_coefficient_sql(dump, "images/14425fb72926241fc02653aa4ab0d81c.jpg", "jpg", 136751);
  danbooru_generate_coefficient_sql(dump, "images/99f3a081057061fa669dd0ef3e0497ae.jpg", "jpg", 8503);
  danbooru_generate_coefficient_sql(dump, "images/8546a5db7c443f998bb9da3b218a7a0d.jpg", "jpg", 141640);
  danbooru_generate_coefficient_sql(dump, "images/5df1a92d833b6871ec9a780a45ed986f.jpg", "jpg", 72226);
  danbooru_generate_coefficient_sql(dump, "images/0a9ead40084be165a0f4563aba44d867.jpg", "jpg", 77018);
  danbooru_generate_coefficient_sql(dump, "images/bf8ef1885f6ed162ef70b94d08b73810.jpg", "jpg", 95731);
  danbooru_generate_coefficient_sql(dump, "images/f5c66a5a24c0331d13c1e0ce56205eb4.jpg", "jpg", 28518);
  danbooru_generate_coefficient_sql(dump, "images/ab7ce3b4b752b893d25214846c0d4d3c.png", "png", 43271);
  danbooru_generate_coefficient_sql(dump, "images/e5aa1d886704b56e8df3f1fb0fcd9511.png", "png", 32951);
  danbooru_generate_coefficient_sql(dump, "images/af15eb03f2d64fffb976d1b9f0b3407c.jpg", "jpg", 94903);
  danbooru_generate_coefficient_sql(dump, "images/7fc30d97dac184cfa30a75033a4d816c.jpg", "jpg", 34486);
  danbooru_generate_coefficient_sql(dump, "images/30fa412767550037a9e8c7f9236dd272.jpg", "jpg", 3528);
  danbooru_generate_coefficient_sql(dump, "images/f17b7d987e2510971d72ec64a6045066.jpg", "jpg", 27736);
  danbooru_generate_coefficient_sql(dump, "images/adbecac13bd489bab349e5f840ecccfd.jpg", "jpg", 116217);
  danbooru_generate_coefficient_sql(dump, "images/140e44dca00d5c1d5bf4f835d2dc89c2.jpg", "jpg", 81557);
  danbooru_generate_coefficient_sql(dump, "images/debc8cbd6b94ed91f3e6949819049a94.jpg", "jpg", 62580);
  danbooru_generate_coefficient_sql(dump, "images/d7e29c001a2daebb5ea5379e56671462.jpg", "jpg", 110149);
  danbooru_generate_coefficient_sql(dump, "images/f5df92de9a75958962e62bc5a1dbb69a.jpg", "jpg", 132992);
  danbooru_generate_coefficient_sql(dump, "images/063dede19dc0d6ff11d29f744713c698.jpg", "jpg", 75070);
  danbooru_generate_coefficient_sql(dump, "images/521c6aee131a764699542576b441764b.jpg", "jpg", 11239);
  danbooru_generate_coefficient_sql(dump, "images/ab81e727124082447c3f5847c8c9eeba.jpg", "jpg", 84387);
  danbooru_generate_coefficient_sql(dump, "images/299f17488746e6e850db656bf447530c.jpg", "jpg", 54257);
  danbooru_generate_coefficient_sql(dump, "images/63f7b7e23bd595f0ea71629e182ecfc6.jpg", "jpg", 125106);
  danbooru_generate_coefficient_sql(dump, "images/0314ef043a4c47818f314eac1bcacd74.jpg", "jpg", 125578);
  danbooru_generate_coefficient_sql(dump, "images/49c1aebc8d07f55c96197a2e12efe235.jpg", "jpg", 84626);
  danbooru_generate_coefficient_sql(dump, "images/09589413ba7f6e820a732c8f28afeafc.jpg", "jpg", 124630);
  danbooru_generate_coefficient_sql(dump, "images/c97e13f19a1bd9bf08845d92951eadbc.jpg", "jpg", 131336);
  danbooru_generate_coefficient_sql(dump, "images/9180e20996ea60048789056c34e649fe.jpg", "jpg", 105617);
  danbooru_generate_coefficient_sql(dump, "images/762641e19d3b99980d235133af088d1e.jpg", "jpg", 88194);
  danbooru_generate_coefficient_sql(dump, "images/b322c7c2df9652234bfbd405971dccfc.jpg", "jpg", 117880);
  danbooru_generate_coefficient_sql(dump, "images/aea2ede3736fe4d2ad4ea2cec2bd4860.jpg", "jpg", 6184);
  danbooru_generate_coefficient_sql(dump, "images/3bca943292553c85e3c778e7f123326a.jpg", "jpg", 54886);
  danbooru_generate_coefficient_sql(dump, "images/f0b42c1f66f40adf71065ca27223ca76.jpg", "jpg", 33398);
  danbooru_generate_coefficient_sql(dump, "images/df8f1e6460292e98014ab9108f2fd841.jpg", "jpg", 140213);
  danbooru_generate_coefficient_sql(dump, "images/36b7b000af5eec658e8af042d48bfdfd.jpg", "jpg", 131526);
  danbooru_generate_coefficient_sql(dump, "images/a89e30dadefe4f2ec2de298cbe17681e.jpg", "jpg", 31665);
  danbooru_generate_coefficient_sql(dump, "images/bb98d5c98d76fd8eff1b02a8e959fda5.jpg", "jpg", 137872);
  danbooru_generate_coefficient_sql(dump, "images/f2821344235a0174f3744b04778e649d.jpg", "jpg", 131634);
  danbooru_generate_coefficient_sql(dump, "images/0509816a23557d527624413edde03e2e.jpg", "jpg", 88555);
  danbooru_generate_coefficient_sql(dump, "images/58302e0a994d33ac6a091f736a4d586e.jpg", "jpg", 132005);
  danbooru_generate_coefficient_sql(dump, "images/57ffee67492141c458cf802adb322205.jpg", "jpg", 103705);
  danbooru_generate_coefficient_sql(dump, "images/07fb38ba51fa0734fad2bc0eb75d6839.jpg", "jpg", 8664);
  danbooru_generate_coefficient_sql(dump, "images/0d9a9c01c197e982102c84f9c34fc865.jpg", "jpg", 65502);
  danbooru_generate_coefficient_sql(dump, "images/3b9ccc28652236d453b77352e62921ec.jpg", "jpg", 19859);
  danbooru_generate_coefficient_sql(dump, "images/6430a7f88e2fbd019b5f52860375cd8a.png", "png", 98036);
  danbooru_generate_coefficient_sql(dump, "images/409812ae96ab3c41026ee77d9b94659d.jpeg", "jpg", 125862);
  danbooru_generate_coefficient_sql(dump, "images/18468c890079e3178a8e9020677316cb.jpeg", "jpg", 126223);
  danbooru_generate_coefficient_sql(dump, "images/442b52470a68209ddf140b49d867eb15.jpg", "jpg", 2090);
  danbooru_generate_coefficient_sql(dump, "images/12c0081d3507d80efe8148b2f67aeecf.jpg", "jpg", 115249);
  danbooru_generate_coefficient_sql(dump, "images/f5a16a60fa20a3fcad47b0c4bf455060.jpg", "jpg", 2890);
  danbooru_generate_coefficient_sql(dump, "images/a62ea2a43687e070003c6edd3633eb28.jpg", "jpg", 130790);
  danbooru_generate_coefficient_sql(dump, "images/2d79b4c3673ca97a2983b36dd4de0001.jpg", "jpg", 82939);
  danbooru_generate_coefficient_sql(dump, "images/5b6a344505b0f1d389ad28d4be78ffe8.jpg", "jpg", 45456);
  danbooru_generate_coefficient_sql(dump, "images/ed22c3ca27abc1513da6815997d9c966.jpg", "jpg", 53996);
  danbooru_generate_coefficient_sql(dump, "images/7cad2d70af463a6a6b8750145f46aa92.jpg", "jpg", 128580);
  danbooru_generate_coefficient_sql(dump, "images/629f1111b8bb728c2a9e14d29dc3e14e.jpg", "jpg", 68740);
  danbooru_generate_coefficient_sql(dump, "images/d15ae7c4101f562decf820cc59c6a6f4.jpg", "jpg", 85321);
  danbooru_generate_coefficient_sql(dump, "images/f2d7f3df6189b5ad9d22e1b9b5ecd14f.jpg", "jpg", 42476);
  danbooru_generate_coefficient_sql(dump, "images/f45a909dd654f14116d9afcad35ddabd.jpg", "jpg", 114599);
  danbooru_generate_coefficient_sql(dump, "images/6da7ddfe99b749102d884b1e27220deb.jpg", "jpg", 74469);
  danbooru_generate_coefficient_sql(dump, "images/86e772eb970a134bee54dca123d1a739.jpg", "jpg", 16515);
  danbooru_generate_coefficient_sql(dump, "images/0f7ba68a902a52cb2beb5526c86925ce.jpg", "jpg", 57241);
  danbooru_generate_coefficient_sql(dump, "images/e040a5c651aabd13da16856f2e6bf1d0.jpg", "jpg", 132970);
  danbooru_generate_coefficient_sql(dump, "images/978a053830b160154265908a126b6dff.jpg", "jpg", 47166);
  danbooru_generate_coefficient_sql(dump, "images/4f941ecc307dcfb9a93c350b466ff9d2.jpg", "jpg", 40767);
  danbooru_generate_coefficient_sql(dump, "images/6068c8d6f8ce66f93706c622eddbee76.jpg", "jpg", 18981);
  danbooru_generate_coefficient_sql(dump, "images/0e3a31a5149ea54d38ea617d5f7b320a.jpg", "jpg", 126698);
  danbooru_generate_coefficient_sql(dump, "images/a9b18be5b598e86a37d07ad538a4e90f.jpg", "jpg", 102930);
  danbooru_generate_coefficient_sql(dump, "images/6e62c2834c1060d9ec60159df0688d5e.jpg", "jpg", 89599);
  danbooru_generate_coefficient_sql(dump, "images/2ef70438ad68a587e0a9468f45343c75.jpg", "jpg", 100265);
  danbooru_generate_coefficient_sql(dump, "images/0f6f8aa2615e1a27db39349a74c2017c.jpg", "jpg", 129);
  danbooru_generate_coefficient_sql(dump, "images/661ef6a02ae68b9aef59073a57eea8b2.jpg", "jpg", 31496);
  danbooru_generate_coefficient_sql(dump, "images/351e3e4336b4ad0919b784d6cc45c165.jpg", "jpg", 42358);
  danbooru_generate_coefficient_sql(dump, "images/4509bf8286671ef43a5d4d726bed1c83.jpg", "jpg", 64137);
  danbooru_generate_coefficient_sql(dump, "images/4a2e517a1a85a5f7d766831d838671b8.jpg", "jpg", 51799);
  danbooru_generate_coefficient_sql(dump, "images/e81d51ff2a1f8aae37459771600a0922.jpg", "jpg", 47745);
  danbooru_generate_coefficient_sql(dump, "images/f35f6ee9ad2790db2606baf96578601c.jpg", "jpg", 62698);
  danbooru_generate_coefficient_sql(dump, "images/519d5fbf96fcae44b108048574d3281d.jpg", "jpg", 7603);
  danbooru_generate_coefficient_sql(dump, "images/757fef87c0e31db7d55aad9009e17c7b.jpg", "jpg", 141813);
  danbooru_generate_coefficient_sql(dump, "images/911f20f5c11151ac32cb3c6c006b8530.jpg", "jpg", 83712);
  danbooru_generate_coefficient_sql(dump, "images/2c2baf167d6447ea12f58b64526c16ef.jpg", "jpg", 136149);
  danbooru_generate_coefficient_sql(dump, "images/9a443257ab8351ff6b776b6e771ec622.jpg", "jpg", 125550);
  danbooru_generate_coefficient_sql(dump, "images/71f301c9d79661af53da7b72b7e65011.jpg", "jpg", 76372);
  danbooru_generate_coefficient_sql(dump, "images/f98d7152a5695ff3ce1f28178f3cf5ab.jpg", "jpg", 65810);
  danbooru_generate_coefficient_sql(dump, "images/ae5eced63f0c1291f543ca503245d1be.jpg", "jpg", 67856);
  danbooru_generate_coefficient_sql(dump, "images/47acabf05cfd1f60bbe9a358ed6a261f.jpg", "jpg", 34742);
  danbooru_generate_coefficient_sql(dump, "images/0e963a5af5da5976fa67bc285b736582.jpg", "jpg", 34679);
  danbooru_generate_coefficient_sql(dump, "images/0aa97cb7f228c968056015d8ea4f4065.jpg", "jpg", 50536);
  danbooru_generate_coefficient_sql(dump, "images/25638095a096e480b93d86d299f28b4f.jpg", "jpg", 67389);
  danbooru_generate_coefficient_sql(dump, "images/1bb061c4f6502308bac9d56a6b76c49d.jpg", "jpg", 128761);
  danbooru_generate_coefficient_sql(dump, "images/6d7bda38bd500b76d27dc34eab76f271.jpg", "jpg", 61194);
  danbooru_generate_coefficient_sql(dump, "images/bc49bdb6c65067e4709fd9bced59fb90.jpg", "jpg", 82202);
  danbooru_generate_coefficient_sql(dump, "images/0568d13613237cc2a74c7bf3e82db8d9.jpg", "jpg", 70077);
  danbooru_generate_coefficient_sql(dump, "images/5a8032ead480504e699c29f6ed9b2be0.jpg", "jpg", 17419);
  danbooru_generate_coefficient_sql(dump, "images/7ad3e9fd0c24fe5a8068739a620e03f6.jpg", "jpg", 66209);
  danbooru_generate_coefficient_sql(dump, "images/8305664c83ce360cc6e907fccddc5e40.jpg", "jpg", 49966);
  danbooru_generate_coefficient_sql(dump, "images/9a081eb9342babfc649bc5cad3940ac0.jpg", "jpg", 3258);
  danbooru_generate_coefficient_sql(dump, "images/c7069b9b848ec57383c66a17202e3803.jpg", "jpg", 82052);
  danbooru_generate_coefficient_sql(dump, "images/c5de91d5bfd6d22ec4f0ea6149ded7cc.png", "png", 76840);
  danbooru_generate_coefficient_sql(dump, "images/a79ac074b5ee337f5686068c8b54f9e9.jpg", "jpg", 61276);
  danbooru_generate_coefficient_sql(dump, "images/e30d977bc76262d8d3a4e02ed57a1672.jpg", "jpg", 45360);
  danbooru_generate_coefficient_sql(dump, "images/cadf6cfb5469cf7241ed4b67b22dbe43.jpg", "jpg", 56487);
  danbooru_generate_coefficient_sql(dump, "images/df2cc84b4c9c7dda6fe464ca92e70165.jpg", "jpg", 71695);
  danbooru_generate_coefficient_sql(dump, "images/4bb0afdc349e8405a3f95052cec1ad17.jpg", "jpg", 33152);
  danbooru_generate_coefficient_sql(dump, "images/4740b8f64eb87fd49a6d690f0427d30b.jpg", "jpg", 79967);
  danbooru_generate_coefficient_sql(dump, "images/a4a08710fc968c8a99907ecef26345ef.jpeg", "jpg", 141094);
  danbooru_generate_coefficient_sql(dump, "images/2f9818e293be74794e1e43abdee0d6a1.jpeg", "jpg", 119665);
  danbooru_generate_coefficient_sql(dump, "images/4c462e35d34c908e0a7bce93f52f6a82.jpg", "jpg", 20661);
  danbooru_generate_coefficient_sql(dump, "images/95e641f8dd4be6130e856691f66a340c.jpg", "jpg", 16204);
  danbooru_generate_coefficient_sql(dump, "images/7fe64ea49ffb8086eb314b49da485aaf.jpg", "jpg", 36140);
  danbooru_generate_coefficient_sql(dump, "images/4d4e09edd58702a1506097aea4b6b844.jpg", "jpg", 8829);
  danbooru_generate_coefficient_sql(dump, "images/422c9d96d4fa71939b049573a7cc82e4.jpg", "jpg", 124551);
  danbooru_generate_coefficient_sql(dump, "images/2a8e6d12774e2a9fbaa08f2c7e346995.jpg", "jpg", 2741);
  danbooru_generate_coefficient_sql(dump, "images/74be56a6cf049889d2304196f324b4a6.jpg", "jpg", 107399);
  danbooru_generate_coefficient_sql(dump, "images/18de83fdcbbe5187d38da2880b887d47.jpg", "jpg", 74159);
  danbooru_generate_coefficient_sql(dump, "images/60454f6ecba4ea5e5d7045c1b7f2db67.jpg", "jpg", 87088);
  danbooru_generate_coefficient_sql(dump, "images/8e24998f9c14c5fdf61ca65d19dc9b1e.jpg", "jpg", 113236);
  danbooru_generate_coefficient_sql(dump, "images/aaa4811265c1740789c4d607b5a58644.jpg", "jpg", 20948);
  danbooru_generate_coefficient_sql(dump, "images/c646698044fbc6aa59f52c21d2f2b25b.jpg", "jpg", 104815);
  danbooru_generate_coefficient_sql(dump, "images/e4f042bbe806d32e47f2494a52c1a343.jpg", "jpg", 68018);
  danbooru_generate_coefficient_sql(dump, "images/faa1331f2f30981cbe65ebb6a35efc2a.gif", "gif", 67019);
  danbooru_generate_coefficient_sql(dump, "images/2137b12d5d711d068df3c41b461fa15b.jpg", "jpg", 136750);
  danbooru_generate_coefficient_sql(dump, "images/0a10e9fede7bdb1c7281985872568261.jpg", "jpg", 52156);
  danbooru_generate_coefficient_sql(dump, "images/903923047e9b53c38648c7cae0b364e4.jpg", "jpg", 78929);
  danbooru_generate_coefficient_sql(dump, "images/2d96e8a7383c0aac9d39aa9a69126429.jpg", "jpg", 7780);
  danbooru_generate_coefficient_sql(dump, "images/292914f2c72325b2e2bbe53dad6ed00f.gif", "gif", 117325);
  danbooru_generate_coefficient_sql(dump, "images/076c5a099924f65cc57d4b74308bea15.png", "png", 36460);
  danbooru_generate_coefficient_sql(dump, "images/194002f9d34842264372b7d95f74b292.jpg", "jpg", 69182);
  danbooru_generate_coefficient_sql(dump, "images/7e33b944646ad5520bcd346238a53cd4.jpg", "jpg", 67698);
  danbooru_generate_coefficient_sql(dump, "images/3c7744ac8c05e5cac83ec982713a087d.jpg", "jpg", 116499);
  danbooru_generate_coefficient_sql(dump, "images/b4686641f2b0577bf904189abcb85dc2.jpg", "jpg", 127828);
  danbooru_generate_coefficient_sql(dump, "images/1040ae64448bff4d2e720b01eb9327a2.jpg", "jpg", 36420);
  danbooru_generate_coefficient_sql(dump, "images/4269866e891f376b92bebd22da675605.jpg", "jpg", 8888);
  danbooru_generate_coefficient_sql(dump, "images/0c5c3246735a379a7cc4cea953854058.jpg", "jpg", 11209);
  danbooru_generate_coefficient_sql(dump, "images/9ba0fff1a12f34368d83d4c6a5715fc0.jpg", "jpg", 30924);
  danbooru_generate_coefficient_sql(dump, "images/f369158cc4151e33e42e1f20a86c2464.jpg", "jpg", 84537);
  danbooru_generate_coefficient_sql(dump, "images/0e87b366231fd58e57dab81043bffd7c.gif", "gif", 131223);
  danbooru_generate_coefficient_sql(dump, "images/969c2e40cca1b217c3ef51f46289bb1d.jpeg", "jpg", 19543);
  danbooru_generate_coefficient_sql(dump, "images/4a3727c85e5701ecf21a4f2bde171b95.jpg", "jpg", 97428);
  danbooru_generate_coefficient_sql(dump, "images/c864cd9741b2c44ef6e3df8de3579392.jpg", "jpg", 58945);
  danbooru_generate_coefficient_sql(dump, "images/ea3a54d944ca78e466ca61397bc73364.jpg", "jpg", 17760);
  danbooru_generate_coefficient_sql(dump, "images/15c7620fba7f9a1ee9aca8edb85d966b.jpg", "jpg", 95581);
  danbooru_generate_coefficient_sql(dump, "images/0107e000541f98595262c0f19551758a.jpg", "jpg", 69226);
  danbooru_generate_coefficient_sql(dump, "images/2730e3df99b9b11385c4ace78fa482a7.jpg", "jpg", 14529);
  danbooru_generate_coefficient_sql(dump, "images/9caad98f321b9bb20b109ed21f9d5f28.jpg", "jpg", 4562);
  danbooru_generate_coefficient_sql(dump, "images/f73f15f945e1be69a2ab220ab9c2f6eb.jpg", "jpg", 62357);
  danbooru_generate_coefficient_sql(dump, "images/ac60bc9c13f0a2ee63d2faeba496afc1.jpg", "jpg", 134009);
  danbooru_generate_coefficient_sql(dump, "images/6df3ba56982782479b3da22e73e4aac7.jpg", "jpg", 25385);
  danbooru_generate_coefficient_sql(dump, "images/b0041a618cf6f66174200bdb7d7aaef2.jpg", "jpg", 54236);
  danbooru_generate_coefficient_sql(dump, "images/f49bd408de0e470ecf872cd2de61cfc6.jpg", "jpg", 66007);
  danbooru_generate_coefficient_sql(dump, "images/eb7278fd1b862a12fc487bf96e552c39.jpg", "jpg", 122865);
  danbooru_generate_coefficient_sql(dump, "images/4d38f1a12bc28613c4894fb5f6517b50.jpg", "jpg", 69168);
  danbooru_generate_coefficient_sql(dump, "images/4acbe375e74e4637074a77f3ba2c84cc.jpg", "jpg", 129519);
  danbooru_generate_coefficient_sql(dump, "images/db98fc8697d46cf85fdd44e9aa64edc9.jpg", "jpg", 69197);
  danbooru_generate_coefficient_sql(dump, "images/764e98d9b8ad43e3eda6753787c37485.jpg", "jpg", 9527);
  danbooru_generate_coefficient_sql(dump, "images/3e1e4f291a3f0152a47a0f4897ae7331.jpg", "jpg", 20156);
  danbooru_generate_coefficient_sql(dump, "images/caf244563e11777f028cde95bddfa243.jpg", "jpg", 34504);
  danbooru_generate_coefficient_sql(dump, "images/ec84094fa046f5cc0917187cea0a526e.jpg", "jpg", 130351);
  danbooru_generate_coefficient_sql(dump, "images/237c06bea7b0b310ba9f2f4f9184380a.jpg", "jpg", 1386);
  danbooru_generate_coefficient_sql(dump, "images/7cc36fed646c9ec2341afe7d7d929e71.jpg", "jpg", 126063);
  danbooru_generate_coefficient_sql(dump, "images/236ac6d3fb7035007983455bca40fcd0.jpg", "jpg", 60104);
  danbooru_generate_coefficient_sql(dump, "images/cc7939829a4874b88f17b7f6e2eed24f.jpg", "jpg", 67260);
  danbooru_generate_coefficient_sql(dump, "images/85b91b7a2526ca80253ec3e8b4b828b4.jpg", "jpg", 130714);
  danbooru_generate_coefficient_sql(dump, "images/f046f9b255bc9a7abed6dcc883de260e.jpg", "jpg", 75010);
  danbooru_generate_coefficient_sql(dump, "images/da4894f9c202e4c5416af7b3026c0e6c.jpg", "jpg", 79946);
  danbooru_generate_coefficient_sql(dump, "images/d291c9c44924bc8954ae26f63d8d5767.jpg", "jpg", 27597);
  danbooru_generate_coefficient_sql(dump, "images/658a5b9fdae83bb8f21e1ad4f1db8140.jpg", "jpg", 21412);
  danbooru_generate_coefficient_sql(dump, "images/6cb8fa15daa6ef9c520cb1cc9f1631c0.jpg", "jpg", 136733);
  danbooru_generate_coefficient_sql(dump, "images/2a05a814730c5ae4421faf42e6132855.jpg", "jpg", 65308);
  danbooru_generate_coefficient_sql(dump, "images/b525fed8607a3455ca61c628a0cafca1.jpg", "jpg", 61836);
  danbooru_generate_coefficient_sql(dump, "images/6755a30858a348d3a2c95c8c560defd3.jpg", "jpg", 55543);
  danbooru_generate_coefficient_sql(dump, "images/4fb2e7f8b130661aad7a278844a46e7b.png", "png", 81771);
  danbooru_generate_coefficient_sql(dump, "images/1dda7ab01d8b7b38211fcf10575e7d3f.jpg", "jpg", 20119);
  danbooru_generate_coefficient_sql(dump, "images/afaf293f90275b088156a6ac63e58489.jpg", "jpg", 49654);
  danbooru_generate_coefficient_sql(dump, "images/8a6e2e31aab0382bb3d66bedf473fe14.jpg", "jpg", 62977);
  danbooru_generate_coefficient_sql(dump, "images/8a9965a6dc8f2289bf5231c64a8a21c8.jpg", "jpg", 47828);
  danbooru_generate_coefficient_sql(dump, "images/66c07c509cedb796aa325776b40b68b3.jpg", "jpg", 87950);
  danbooru_generate_coefficient_sql(dump, "images/b2a4f7bd69a25634d4a94319b9a939f1.jpg", "jpg", 96589);
  danbooru_generate_coefficient_sql(dump, "images/70b291e6d0ebc789ae302f130b723d25.jpg", "jpg", 81424);
  danbooru_generate_coefficient_sql(dump, "images/6e6446259383a81a7e155cc982c407e3.jpg", "jpg", 67158);
  danbooru_generate_coefficient_sql(dump, "images/9c4c52fbd1ad4cfec8232ca5807e106d.jpg", "jpg", 263);
  danbooru_generate_coefficient_sql(dump, "images/116c875be752993e75b55aa844aa0fad.jpg", "jpg", 50134);
  danbooru_generate_coefficient_sql(dump, "images/89cc002924c26dc1ba4b1cf9f9787810.jpg", "jpg", 5756);
  danbooru_generate_coefficient_sql(dump, "images/c8d1ac024f3c090bbd95f4dc03625b35.jpg", "jpg", 34588);
  danbooru_generate_coefficient_sql(dump, "images/ca2cd1990d9108e0bba83019a0053835.jpg", "jpg", 29331);
  danbooru_generate_coefficient_sql(dump, "images/09e52b149af0ee689cdf103f4c5378ad.jpg", "jpg", 95908);
  danbooru_generate_coefficient_sql(dump, "images/515a901d3122fc8ab5cbd14c50f433f8.jpeg", "jpg", 142232);
  danbooru_generate_coefficient_sql(dump, "images/e04239d5153314602c8d1de5b1610c50.jpg", "jpg", 19317);
  danbooru_generate_coefficient_sql(dump, "images/883a7b46af06cb56c2c886a7d3a479b7.jpg", "jpg", 26271);
  danbooru_generate_coefficient_sql(dump, "images/f9f8b2670689066abad0219dfcfbce62.jpg", "jpg", 26032);
  danbooru_generate_coefficient_sql(dump, "images/ecdf195e09bc3ed002ba09d73a39f87d.jpg", "jpg", 122783);
  danbooru_generate_coefficient_sql(dump, "images/3722f01512eadc79fc6f3b4d35ef65a5.jpg", "jpg", 73700);
  danbooru_generate_coefficient_sql(dump, "images/498888cb2d0e8fc429fceddd08b57496.gif", "gif", 28793);
  danbooru_generate_coefficient_sql(dump, "images/be345ad53d8140be0db7a9860431bbc3.jpg", "jpg", 107341);
  danbooru_generate_coefficient_sql(dump, "images/9165d50174b8af947cdb9d0e5a1cc9eb.png", "png", 140982);
  danbooru_generate_coefficient_sql(dump, "images/069ed43599da0eec5ec71ffdc63144c3.jpg", "jpg", 76716);
  danbooru_generate_coefficient_sql(dump, "images/c05c842c0a540366fe6a92d009491a16.jpg", "jpg", 120248);
  danbooru_generate_coefficient_sql(dump, "images/c52cdc78bd0ea821386f4a9d035d49a5.jpg", "jpg", 28782);
  danbooru_generate_coefficient_sql(dump, "images/7fc474a727d4eb1043277dd97666586c.jpg", "jpg", 11913);
  danbooru_generate_coefficient_sql(dump, "images/e7772f27a5e0d6e7b35c275f90bc2a40.jpg", "jpg", 142244);
  danbooru_generate_coefficient_sql(dump, "images/c84fa8c993880ab1bef32189052f59a3.jpg", "jpg", 65002);
  danbooru_generate_coefficient_sql(dump, "images/55b4af2b05d560e843a7745eea13e2c4.jpg", "jpg", 75778);
  danbooru_generate_coefficient_sql(dump, "images/8e4073178ff14ae350955982f24beb8a.jpg", "jpg", 6421);
  danbooru_generate_coefficient_sql(dump, "images/a8c74c0ab0290b5cee1a7ed35f9540fc.jpg", "jpg", 15295);
  danbooru_generate_coefficient_sql(dump, "images/4f5baf4c6518b21704c0a5ccff321002.png", "png", 56175);
  danbooru_generate_coefficient_sql(dump, "images/0921f085613c044e1468cc8d08ed2b85.jpg", "jpg", 53429);
  danbooru_generate_coefficient_sql(dump, "images/71106adff3c44352c97801b35ad1c8fa.jpg", "jpg", 106939);
  danbooru_generate_coefficient_sql(dump, "images/344d0bba3ccad467359ce24e60eb1bfa.jpg", "jpg", 54654);
  danbooru_generate_coefficient_sql(dump, "images/64e2bfa272637933db6dd5c662ed8646.jpg", "jpg", 78150);
  danbooru_generate_coefficient_sql(dump, "images/dc0bc08de65a18932fe98d22427bebe4.jpg", "jpg", 121094);
  danbooru_generate_coefficient_sql(dump, "images/205691380e0e37b3417ae8a362d56775.jpg", "jpg", 105917);
  danbooru_generate_coefficient_sql(dump, "images/f9120e198525598794211c39025b6f3e.jpg", "jpg", 129661);
  danbooru_generate_coefficient_sql(dump, "images/9ac84cf119b65b27df332a419715ad1d.jpg", "jpg", 60610);
  danbooru_generate_coefficient_sql(dump, "images/b316fcea8d463534507cb24c8577380f.jpg", "jpg", 124161);
  danbooru_generate_coefficient_sql(dump, "images/c5a36fdd81d3c4a791824a16b49890a7.jpg", "jpg", 5365);
  danbooru_generate_coefficient_sql(dump, "images/16e2ef03945a13be0f2c613408460415.jpg", "jpg", 120234);
  danbooru_generate_coefficient_sql(dump, "images/5a666b8a04f22e7ecda6281e74f42df1.jpg", "jpg", 123138);
  danbooru_generate_coefficient_sql(dump, "images/a997197f2320b5324dbb8b855598f7de.jpg", "jpg", 67881);
  danbooru_generate_coefficient_sql(dump, "images/5c27be7bf0d50826efb94c23a8050eb8.jpg", "jpg", 45397);
  danbooru_generate_coefficient_sql(dump, "images/e6266f9711c2cadff24bce4a5e73d5f5.jpg", "jpg", 50721);
  danbooru_generate_coefficient_sql(dump, "images/c5280a3081c3a6686cf36cd4f0d4cea9.jpg", "jpg", 84596);
  danbooru_generate_coefficient_sql(dump, "images/4900ef1549cdeaea510f7f1639494444.jpg", "jpg", 35223);
  danbooru_generate_coefficient_sql(dump, "images/864d05bc166bfde29aa127e4211dda9a.jpg", "jpg", 99693);
  danbooru_generate_coefficient_sql(dump, "images/960ba190a51913e3907fa838005b446f.jpg", "jpg", 45892);
  danbooru_generate_coefficient_sql(dump, "images/bf659b2bfc8e6097d6d0965b2e1b7beb.png", "png", 111342);
  danbooru_generate_coefficient_sql(dump, "images/4447184b81234f9220ddfa5fdd0a97df.jpeg", "jpg", 142509);
  danbooru_generate_coefficient_sql(dump, "images/5b88a51084dc6c42d07bee0609adc2e9.jpg", "jpg", 65019);
  danbooru_generate_coefficient_sql(dump, "images/25f4344f5149ec9331701648fbfaa58c.jpg", "jpg", 75737);
  danbooru_generate_coefficient_sql(dump, "images/daa7138c28ca6a2f3f622caa7ee5c7fb.jpg", "jpg", 22633);
  danbooru_generate_coefficient_sql(dump, "images/1445660cf65f68937b86b9d5efc0f594.jpg", "jpg", 94418);
  danbooru_generate_coefficient_sql(dump, "images/00e2032b6c994432f215adcdebc051e3.jpg", "jpg", 27585);
  danbooru_generate_coefficient_sql(dump, "images/5af2255d73da70e9c22e91203415651e.jpg", "jpg", 84379);
  danbooru_generate_coefficient_sql(dump, "images/09ca741dbba8b381150959acde2fefd3.jpg", "jpg", 29393);
  danbooru_generate_coefficient_sql(dump, "images/ece92e60531d0c7c2d8c4abed6e3d2ff.jpg", "jpg", 33325);
  danbooru_generate_coefficient_sql(dump, "images/e9107f1781e438bca503fb69675c1b8d.jpg", "jpg", 24790);
  danbooru_generate_coefficient_sql(dump, "images/b0e0896412832752b0d5d58b989fbf10.gif", "gif", 8045);
  danbooru_generate_coefficient_sql(dump, "images/1714affd3f2fdca6c484c579df8ff435.jpg", "jpg", 136866);
  danbooru_generate_coefficient_sql(dump, "images/99a5f169994eb9d273e587530b20bbc7.jpg", "jpg", 36483);
  danbooru_generate_coefficient_sql(dump, "images/592bd5fef4c1be5bc04d2179b8011b66.png", "png", 107158);
  danbooru_generate_coefficient_sql(dump, "images/f7841254eeb75384143f46cbdfedb138.jpg", "jpg", 26381);
  danbooru_generate_coefficient_sql(dump, "images/438845845a742258c85466a13b47f7e0.jpg", "jpg", 73768);
  danbooru_generate_coefficient_sql(dump, "images/3160ef45504e89355c96c87405d9fd75.jpg", "jpg", 138384);
  danbooru_generate_coefficient_sql(dump, "images/52b1af3eb36b63572cbbd318d2eddc0c.jpg", "jpg", 73923);
  danbooru_generate_coefficient_sql(dump, "images/6130f8033271faa307547aa023d00994.jpg", "jpg", 56378);
  danbooru_generate_coefficient_sql(dump, "images/87c1e42e94b442e0996d6e7def606571.jpg", "jpg", 108230);
  danbooru_generate_coefficient_sql(dump, "images/9c0523912e68cb90b206c2447e95daa6.jpeg", "jpg", 117118);
  danbooru_generate_coefficient_sql(dump, "images/da3fd9792db566872c8fb847498fd575.jpg", "jpg", 30821);
  danbooru_generate_coefficient_sql(dump, "images/c16d10ab07f76235a5f8b53521dd8511.jpg", "jpg", 97528);
  danbooru_generate_coefficient_sql(dump, "images/5592c9f6de22b77d9a6ca7177dc42407.jpg", "jpg", 48116);
  danbooru_generate_coefficient_sql(dump, "images/bf792935b050742b64054cece6e5387e.png", "png", 34177);
  danbooru_generate_coefficient_sql(dump, "images/6340499d6c0b6bb03c268bd67931ecb7.jpg", "jpg", 122734);
  danbooru_generate_coefficient_sql(dump, "images/12a1b0ff40a4872a7062173b1a057232.jpg", "jpg", 66038);
  danbooru_generate_coefficient_sql(dump, "images/f7b4ef49aed6f0e06821f7b6440ec721.jpg", "jpg", 13102);
  danbooru_generate_coefficient_sql(dump, "images/cc526c3652daa1eb09042863ff63124f.jpg", "jpg", 105119);
  danbooru_generate_coefficient_sql(dump, "images/707d4a39996bc125f944d8dd2d47ecbc.jpeg", "jpg", 129861);
  danbooru_generate_coefficient_sql(dump, "images/4832ab1d20f5d95fdf951204190157fe.jpg", "jpg", 98697);
  danbooru_generate_coefficient_sql(dump, "images/22460b05aaa46d0fc4c6999802e0a73e.jpg", "jpg", 45424);
  danbooru_generate_coefficient_sql(dump, "images/1769536e08469a4c901eff9310456c66.png", "png", 125193);
  danbooru_generate_coefficient_sql(dump, "images/7a6036e391441b384e96d18ca58045c1.jpg", "jpg", 30061);
  danbooru_generate_coefficient_sql(dump, "images/af13df3bc43d76f8d11c761ed6c45cec.jpg", "jpg", 134894);
  danbooru_generate_coefficient_sql(dump, "images/229c1832a9eab09cca0f00ff3cd11424.jpg", "jpg", 98418);
  danbooru_generate_coefficient_sql(dump, "images/39f806de69edafcc2e6091dccf1da225.jpg", "jpg", 36067);
  danbooru_generate_coefficient_sql(dump, "images/dca6d15d0d8c31a8891952f53faaa435.png", "png", 22226);
  danbooru_generate_coefficient_sql(dump, "images/e7c2ed5f576d1765ac4fb9337987d5e1.jpg", "jpg", 102925);
  danbooru_generate_coefficient_sql(dump, "images/1d1b1cc5923c63f74db34a2990cf2199.jpg", "jpg", 139107);
  danbooru_generate_coefficient_sql(dump, "images/3f8ebc3371d73662a01ca0843a36471d.jpg", "jpg", 69672);
  danbooru_generate_coefficient_sql(dump, "images/bb1401d8131e5fc1e28e2522bf735c17.jpg", "jpg", 36853);
  danbooru_generate_coefficient_sql(dump, "images/a4c0608f077bda09741673895a8e8b8f.jpg", "jpg", 45670);
  danbooru_generate_coefficient_sql(dump, "images/2d55bd0e1ad3c1320ad9ae8b8dea65fb.jpg", "jpg", 50248);
  danbooru_generate_coefficient_sql(dump, "images/c664096995f0a22203d2f1de0a54f834.jpg", "jpg", 4600);
  danbooru_generate_coefficient_sql(dump, "images/44865265f9795ca1295862353b09cead.jpg", "jpg", 30676);
  danbooru_generate_coefficient_sql(dump, "images/cf76e87be942c0e3986aa6be33278908.jpg", "jpg", 22849);
  danbooru_generate_coefficient_sql(dump, "images/f416755045f275cb2e2737ba0f1d76e2.jpg", "jpg", 15386);
  danbooru_generate_coefficient_sql(dump, "images/f84f4a3fb0acf2a1f09e59167fa7a97a.jpg", "jpg", 71164);
  danbooru_generate_coefficient_sql(dump, "images/25abef97c98ac74e310b3f87ad429863.gif", "gif", 132550);
  danbooru_generate_coefficient_sql(dump, "images/7eea4bfee26e751a7b275f1816475eed.jpg", "jpg", 121709);
  danbooru_generate_coefficient_sql(dump, "images/edbc708c80150d34400c2aa7a2fbe77a.jpg", "jpg", 106653);
  danbooru_generate_coefficient_sql(dump, "images/5ad8b04e72a05e89a2f0269c6c28c10d.jpg", "jpg", 62014);
  danbooru_generate_coefficient_sql(dump, "images/15c2a9a12fb2a0531bc06ad13f79c31b.jpg", "jpg", 102800);
  danbooru_generate_coefficient_sql(dump, "images/758ede82d142cd7a4f1a6d07cd83daed.jpg", "jpg", 86098);
  danbooru_generate_coefficient_sql(dump, "images/72b44a6c3083b753a76b51ea1aec91d2.jpg", "jpg", 128553);
  danbooru_generate_coefficient_sql(dump, "images/9982681b9d965e902595d950ba417db7.jpg", "jpg", 63037);
  danbooru_generate_coefficient_sql(dump, "images/f3c6d7677dbc8d073a1caaae457005de.jpg", "jpg", 8379);
  danbooru_generate_coefficient_sql(dump, "images/cb7f8d206472ccf6b6f2ce6c019da600.png", "png", 42941);
  danbooru_generate_coefficient_sql(dump, "images/8ea3fc816b63b26123c8fdb9b48eb113.jpg", "jpg", 67449);
  danbooru_generate_coefficient_sql(dump, "images/0b1c2dc211b32536008484487795db73.jpg", "jpg", 61594);
  danbooru_generate_coefficient_sql(dump, "images/8ad5bc70a5dee784f838221ab75c3d82.jpg", "jpg", 30008);
  danbooru_generate_coefficient_sql(dump, "images/b2b09076d90ef9815cb22b754231bc37.jpg", "jpg", 36911);
  danbooru_generate_coefficient_sql(dump, "images/2fee4f5b5b831889e5417b6c887d0737.jpg", "jpg", 18587);
  danbooru_generate_coefficient_sql(dump, "images/6c052a7998208b495a4ca1e0a507f687.jpg", "jpg", 35102);
  danbooru_generate_coefficient_sql(dump, "images/2f9d0598b94372fec46966cc281ebd26.jpg", "jpg", 5922);
  danbooru_generate_coefficient_sql(dump, "images/658283e955c0b0bd14a66115bd20cfbd.jpg", "jpg", 137818);
  danbooru_generate_coefficient_sql(dump, "images/70d8e687524d7dce9604bc2d58e65ae0.jpg", "jpg", 31298);
  danbooru_generate_coefficient_sql(dump, "images/d258eba302acc7a0f923fb3bd3757614.jpg", "jpg", 472);
  danbooru_generate_coefficient_sql(dump, "images/63bd2ff5b43b7a664324c07e37aa452b.jpg", "jpg", 67205);
  danbooru_generate_coefficient_sql(dump, "images/46d40c576109bd36c64a89272fc4d8e3.jpeg", "jpg", 126242);
  danbooru_generate_coefficient_sql(dump, "images/f5553da68fa9b2010df0e9ca9773a00a.jpg", "jpg", 28215);
  danbooru_generate_coefficient_sql(dump, "images/ed439c7cbfe344af6beebb9f6aa6f762.jpg", "jpg", 12101);
  danbooru_generate_coefficient_sql(dump, "images/67f3ade3f02c5276c655ad83c3c6b902.jpg", "jpg", 101587);
  danbooru_generate_coefficient_sql(dump, "images/a1572ccb12acd629f4a865a91b5d21a0.gif", "gif", 65315);
  danbooru_generate_coefficient_sql(dump, "images/52219a9cf8bf519b11102d60baeb5724.jpg", "jpg", 137018);
  danbooru_generate_coefficient_sql(dump, "images/895ab2d83085900cb25f3eddae8476f7.jpg", "jpg", 7386);
  danbooru_generate_coefficient_sql(dump, "images/d351a75a10218997bb56133424b07b08.jpg", "jpg", 96817);
  danbooru_generate_coefficient_sql(dump, "images/041f63c3fef386502897149fa921bcb8.jpg", "jpg", 64777);
  danbooru_generate_coefficient_sql(dump, "images/759e3d2c818a0007814307440333e829.jpg", "jpg", 38477);
  danbooru_generate_coefficient_sql(dump, "images/d664dafdb2820cedda3a699e16d99423.jpg", "jpg", 60423);
  danbooru_generate_coefficient_sql(dump, "images/99575c85fe75e1ef9117e60e11d45f42.jpg", "jpg", 81584);
  danbooru_generate_coefficient_sql(dump, "images/50211fef932c828b1b533a67a5a6d989.jpg", "jpg", 21572);
  danbooru_generate_coefficient_sql(dump, "images/27467344493c5398b74cc376bdbe50de.jpg", "jpg", 9660);
  danbooru_generate_coefficient_sql(dump, "images/25ee2e92a7acd998a76fcf68818139e9.gif", "gif", 120809);
  danbooru_generate_coefficient_sql(dump, "images/2f86b3d54d618d5b59dca2e9bddc8f68.jpg", "jpg", 57938);
  danbooru_generate_coefficient_sql(dump, "images/c76fac7199f126071a937810af8bbed3.jpg", "jpg", 86307);
  danbooru_generate_coefficient_sql(dump, "images/b9d1056f52c66c1a1b2b03b119ca0f22.jpg", "jpg", 130703);
  danbooru_generate_coefficient_sql(dump, "images/6876147ce6e3a42a6e3354ad5cb0bc53.jpg", "jpg", 89352);
  danbooru_generate_coefficient_sql(dump, "images/f39a76dc76cacda3fd96b614e0f20c49.gif", "gif", 86000);
  danbooru_generate_coefficient_sql(dump, "images/0c68ab086505f0121ff37b4bd0511166.jpg", "jpg", 92394);
  danbooru_generate_coefficient_sql(dump, "images/f45ee69a121b2651ada59386eb564817.jpg", "jpg", 52985);
  danbooru_generate_coefficient_sql(dump, "images/c22b2119d64754b038d7c4e186916f79.jpg", "jpg", 70122);
  danbooru_generate_coefficient_sql(dump, "images/73858bfe9d9031c48168197d37b54cf7.gif", "gif", 1910);
  danbooru_generate_coefficient_sql(dump, "images/cd67d1d7f3472a10de50add800a42cd8.jpg", "jpg", 5837);
  danbooru_generate_coefficient_sql(dump, "images/764c0004acffd76a51a6579373176a53.jpg", "jpg", 129309);
  danbooru_generate_coefficient_sql(dump, "images/f75b88c0776e0f571c8c3b54d10e59b9.jpg", "jpg", 72139);
  danbooru_generate_coefficient_sql(dump, "images/fd1f512cca31ea5b7e742e8bebce16a5.jpg", "jpg", 105970);
  danbooru_generate_coefficient_sql(dump, "images/d41c48081d6ad9d880a118879733646f.jpg", "jpg", 127799);
  danbooru_generate_coefficient_sql(dump, "images/070a444ae113215448de0b9f84baaa3e.jpg", "jpg", 17587);
  danbooru_generate_coefficient_sql(dump, "images/7396db94721cf229bcc4c12fe5f05d7a.jpg", "jpg", 142687);
  danbooru_generate_coefficient_sql(dump, "images/b9f1f7f1b1b85871dbcafa25f00d087e.gif", "gif", 84738);
  danbooru_generate_coefficient_sql(dump, "images/d985c2d2d16eff3b50cad2035e568020.jpg", "jpg", 88333);
  danbooru_generate_coefficient_sql(dump, "images/c07371aa19a2359b6e59af562fae6a3d.jpg", "jpg", 86435);
  danbooru_generate_coefficient_sql(dump, "images/41ff53d31d06075a8a27b68d837bfc21.gif", "gif", 41565);
  danbooru_generate_coefficient_sql(dump, "images/cae8b19dfeadaae45c65e04631473e59.jpg", "jpg", 82150);
  danbooru_generate_coefficient_sql(dump, "images/4c61997e9025afb4f17f2047cdb4d1f0.jpg", "jpg", 38390);
  danbooru_generate_coefficient_sql(dump, "images/58e9380da33edcc29a3d545c138e4c0b.jpg", "jpg", 14517);
  danbooru_generate_coefficient_sql(dump, "images/3b51045fbe547919fe5b2bd1d69afdea.jpg", "jpg", 53181);
  danbooru_generate_coefficient_sql(dump, "images/0075875e836d9ef32d5f334de91eb410.jpg", "jpg", 122354);
  danbooru_generate_coefficient_sql(dump, "images/8300c066e9c734c2788aca5898c42379.jpg", "jpg", 142452);
  danbooru_generate_coefficient_sql(dump, "images/a965edbaeae726df9e442b75a6ee9f42.jpg", "jpg", 39117);
  danbooru_generate_coefficient_sql(dump, "images/67eb0b41b6ddf5fc5f91199bb01039a7.jpg", "jpg", 26820);
  danbooru_generate_coefficient_sql(dump, "images/80afe43772c720723606c6db3c4515f0.jpg", "jpg", 135764);
  danbooru_generate_coefficient_sql(dump, "images/f804d816253885e7e64c2f87f408ff37.jpg", "jpg", 113011);
  danbooru_generate_coefficient_sql(dump, "images/778dc902187887979acaf885eaca4720.jpg", "jpg", 52490);
  danbooru_generate_coefficient_sql(dump, "images/3dffbdd5c389c40f23d6e4c40dea971e.jpg", "jpg", 69106);
  danbooru_generate_coefficient_sql(dump, "images/e4b0ed8cf13fda8f1289cf9276293b50.jpg", "jpg", 53129);
  danbooru_generate_coefficient_sql(dump, "images/e6b25ec89b692b26468a0d33c5817176.jpg", "jpg", 125375);
  danbooru_generate_coefficient_sql(dump, "images/dde56910a3c6217dd320f573d3bdaebd.jpg", "jpg", 12002);
  danbooru_generate_coefficient_sql(dump, "images/db63040544954ce00b7c6d5d8e70c5f3.jpg", "jpg", 31442);
  danbooru_generate_coefficient_sql(dump, "images/ae0dc5f0a5541999d0693b6bcedcb679.jpg", "jpg", 25724);
  danbooru_generate_coefficient_sql(dump, "images/5c7a3c4963510c36d55fdd5de0c0932f.jpg", "jpg", 92825);
  danbooru_generate_coefficient_sql(dump, "images/6f40ead204fc9956d75bf13727405d24.jpg", "jpg", 62961);
  danbooru_generate_coefficient_sql(dump, "images/022c1a381ad1b2382e7b0502f1df589f.jpg", "jpg", 14576);
  danbooru_generate_coefficient_sql(dump, "images/0526b907326a9819f056b84fd958630d.gif", "gif", 1495);
  danbooru_generate_coefficient_sql(dump, "images/56841d0bb358948c455b4e4eca2daa24.jpg", "jpg", 91955);
  danbooru_generate_coefficient_sql(dump, "images/15e99895c213f1b70debe6becb108588.jpg", "jpg", 43601);
  danbooru_generate_coefficient_sql(dump, "images/3494dfedf85fe9535cfc6e196c336822.jpg", "jpg", 141642);
  danbooru_generate_coefficient_sql(dump, "images/978aca1dd45cddee56fd5dd7bdd26908.jpg", "jpg", 41457);
  danbooru_generate_coefficient_sql(dump, "images/36f38153f3b9145ac1da5f591178428a.jpeg", "jpg", 126851);
  danbooru_generate_coefficient_sql(dump, "images/237c2d759b9666114ea287b2de6a9b33.jpg", "jpg", 84389);
  danbooru_generate_coefficient_sql(dump, "images/5a74dcd6a15a3d79dc4782cdd1a2edd6.jpg", "jpg", 24403);
  danbooru_generate_coefficient_sql(dump, "images/0ba6719260cf48a9d188d32428ce3c1a.jpg", "jpg", 43522);
  danbooru_generate_coefficient_sql(dump, "images/bb67c7f2449bb87a2b9b9e8fd44f9943.jpg", "jpg", 47996);
  danbooru_generate_coefficient_sql(dump, "images/41c7dd27e35c4e0a68bed4b65755f211.jpeg", "jpg", 119947);
  danbooru_generate_coefficient_sql(dump, "images/44c8d7aba30b988775e51e690750e2fa.jpg", "jpg", 8870);
  danbooru_generate_coefficient_sql(dump, "images/faeb758b0cf6840a98ee48a10e563a94.jpeg", "jpg", 133804);
  danbooru_generate_coefficient_sql(dump, "images/34148b2ad33a2a94108389cd4dc3bf53.jpg", "jpg", 58662);
  danbooru_generate_coefficient_sql(dump, "images/439eb3d91da1f8dfb3218758a0157630.jpg", "jpg", 76232);
  danbooru_generate_coefficient_sql(dump, "images/62ecdf83a4db6d95a1634cec46348c2d.jpg", "jpg", 2083);
  danbooru_generate_coefficient_sql(dump, "images/0cb1d233fcbbce9c8243f26400c97bda.jpg", "jpg", 92644);
  danbooru_generate_coefficient_sql(dump, "images/833c768e50acdf042a80458b723b0f4c.jpg", "jpg", 867);
  danbooru_generate_coefficient_sql(dump, "images/1c8be40e5b612b5fe92ea17b64059a75.jpg", "jpg", 71678);
  danbooru_generate_coefficient_sql(dump, "images/2f1ebede564f36521652d7803b040b0f.jpg", "jpg", 37278);
  danbooru_generate_coefficient_sql(dump, "images/cbd710a22ba42abc34c0fe6aef8b57db.jpg", "jpg", 13844);
  danbooru_generate_coefficient_sql(dump, "images/1c7f3be3ba7d15be4614fc4f38cad95b.jpg", "jpg", 27190);
  danbooru_generate_coefficient_sql(dump, "images/6e9d456b2483fbb483dbfb26b325b34f.jpg", "jpg", 62149);
  danbooru_generate_coefficient_sql(dump, "images/eb86c25318f35b030c714857d2741f02.jpg", "jpg", 41099);
  danbooru_generate_coefficient_sql(dump, "images/5b3862b3e598641ab0b6324160e26432.jpeg", "jpg", 125867);
  danbooru_generate_coefficient_sql(dump, "images/792e662813e047d401f2aba7a1933ecb.jpg", "jpg", 84494);
  danbooru_generate_coefficient_sql(dump, "images/2d2a6ec56d372ffbcda89b73b3dbe3ce.gif", "gif", 66271);
  danbooru_generate_coefficient_sql(dump, "images/3de9b90ef29b5d5dd60ab4d840302f57.jpg", "jpg", 31569);
  danbooru_generate_coefficient_sql(dump, "images/40e70c79452cefc8f606bc699c230f02.jpg", "jpg", 31891);
  danbooru_generate_coefficient_sql(dump, "images/87a60d6f7652fb4dd616fc5e5dd4c83e.jpg", "jpg", 30958);
  danbooru_generate_coefficient_sql(dump, "images/11e622effb4f36f4914d28b1748912b0.jpg", "jpg", 137811);
  danbooru_generate_coefficient_sql(dump, "images/85d003cdece44698832cc63cc62f56bf.jpg", "jpg", 4969);
  danbooru_generate_coefficient_sql(dump, "images/173d3d16e94613e1e8f72c447663ef9d.png", "png", 26589);
  danbooru_generate_coefficient_sql(dump, "images/0335d2ec4b553d1ede7ae654217121b7.jpg", "jpg", 112113);
  danbooru_generate_coefficient_sql(dump, "images/5ad22375cd7e256975c362430b9e4cc9.jpg", "jpg", 60493);
  danbooru_generate_coefficient_sql(dump, "images/1076a4c2b4b6516ebd94b9b1ad6b5df7.jpg", "jpg", 134362);
  danbooru_generate_coefficient_sql(dump, "images/f8149a0f88edd7d1a803aad0cb90187d.jpg", "jpg", 119979);
  danbooru_generate_coefficient_sql(dump, "images/69e67446226994a807dd113349ce59c3.jpg", "jpg", 59906);
  danbooru_generate_coefficient_sql(dump, "images/bbada0446c315c4edef3bb3e5e243805.jpg", "jpg", 75514);
  danbooru_generate_coefficient_sql(dump, "images/a0d7397677505655150bd1147dcc630c.png", "png", 27908);
  danbooru_generate_coefficient_sql(dump, "images/ca8b0aeff224d0b6123672a41df89531.jpg", "jpg", 66847);
  danbooru_generate_coefficient_sql(dump, "images/37379912df87502e638ce9a846c81a17.jpg", "jpg", 86935);
  danbooru_generate_coefficient_sql(dump, "images/66638a71afdb2713f7fa22b22c26fdc7.jpg", "jpg", 124182);
  danbooru_generate_coefficient_sql(dump, "images/c6fa74d819ee72ee1ef1aac220d1f0ef.jpg", "jpg", 51343);
  danbooru_generate_coefficient_sql(dump, "images/564b4121baf3ede8d6a5a8e1e3176b18.jpg", "jpg", 34314);
  danbooru_generate_coefficient_sql(dump, "images/e06594533e51b4fc6795f4445a1f025f.jpg", "jpg", 109728);
  danbooru_generate_coefficient_sql(dump, "images/7d735e17bcc444a3f2a83db571378726.jpg", "jpg", 10671);
  danbooru_generate_coefficient_sql(dump, "images/e5f81dd64160ccd94a73d2b33d33a7d5.jpg", "jpg", 87355);
  danbooru_generate_coefficient_sql(dump, "images/158013959b2da649d24cb9ea82fcc272.jpg", "jpg", 73477);
  danbooru_generate_coefficient_sql(dump, "images/47e4397a4d767ab135a1b3b21142d194.jpg", "jpg", 88858);
  danbooru_generate_coefficient_sql(dump, "images/a279e253763146ae8a1e86d126c379a1.jpg", "jpg", 55363);
  danbooru_generate_coefficient_sql(dump, "images/03d1b7600da005b39b25b73a6bfd3c33.jpg", "jpg", 15683);
  danbooru_generate_coefficient_sql(dump, "images/ae01ad47c7d5c537e102a33b3e06a247.jpg", "jpg", 85838);
  danbooru_generate_coefficient_sql(dump, "images/30c6405ca9dd8d0a2c646d53610a0fcd.jpg", "jpg", 5152);
  danbooru_generate_coefficient_sql(dump, "images/800762448ab96cffef3b31440b99ca8b.jpg", "jpg", 131577);
  danbooru_generate_coefficient_sql(dump, "images/c07b1cf3105db03d4f1b91ca875e5ae4.jpg", "jpg", 97811);
  danbooru_generate_coefficient_sql(dump, "images/0c9c88ab0b3eb913903fe6b674627c04.jpg", "jpg", 92672);
  danbooru_generate_coefficient_sql(dump, "images/8b0cba8fd296c49c3b27f419db96d5fa.jpg", "jpg", 113060);
  danbooru_generate_coefficient_sql(dump, "images/52bfcd553e9d80f1d89b288f0b60f857.jpg", "jpg", 37552);
  danbooru_generate_coefficient_sql(dump, "images/8c92174628ac12fa6227ed7db615e925.jpg", "jpg", 121736);
  danbooru_generate_coefficient_sql(dump, "images/26df51f96e54d3ba8a957e01d16e925b.gif", "gif", 2419);
  danbooru_generate_coefficient_sql(dump, "images/e2a978a39f6492fbe978c1a074681156.jpg", "jpg", 40065);
  danbooru_generate_coefficient_sql(dump, "images/c53ea663f82120b51b0bf1e8446e4664.jpg", "jpg", 132049);
  danbooru_generate_coefficient_sql(dump, "images/47dab2f183f8e579f29cbc082f1c47c5.jpg", "jpg", 131183);
  danbooru_generate_coefficient_sql(dump, "images/765b975fa06c9bba74b7d649c66fa805.jpg", "jpg", 6845);
  danbooru_generate_coefficient_sql(dump, "images/61ce6cc1d8da80465d7cfab5808378af.jpg", "jpg", 40834);
  danbooru_generate_coefficient_sql(dump, "images/de4648e18120baa27ef64a012e28a4f8.jpg", "jpg", 113775);
  danbooru_generate_coefficient_sql(dump, "images/6edebd39c007987e0961586873598591.jpg", "jpg", 45270);
  danbooru_generate_coefficient_sql(dump, "images/52eeed4cb6f437392c6437f68fc20f1a.jpg", "jpg", 5993);
  danbooru_generate_coefficient_sql(dump, "images/52056171890906ff88fbe4ea06653a37.jpg", "jpg", 125763);
  danbooru_generate_coefficient_sql(dump, "images/8b9a4a7a0afbdfd95878c5eb8f675bdb.jpg", "jpg", 38773);
  danbooru_generate_coefficient_sql(dump, "images/f0f40fe87a0ade1aa0c8e11d8a72ae58.jpg", "jpg", 76238);
  danbooru_generate_coefficient_sql(dump, "images/a04d0c2eb89aef5bdeeedf829bf78ba0.jpg", "jpg", 85493);
  danbooru_generate_coefficient_sql(dump, "images/a411b511afc7011e0f608aacdd07674e.jpg", "jpg", 93014);
  danbooru_generate_coefficient_sql(dump, "images/a336225427aef030b41a0223801a4c49.jpg", "jpg", 74727);
  danbooru_generate_coefficient_sql(dump, "images/292d159e9a6265586377180317ac3d1c.jpg", "jpg", 24911);
  danbooru_generate_coefficient_sql(dump, "images/992370559af04f345affd99af4eb89cc.jpg", "jpg", 17104);
  danbooru_generate_coefficient_sql(dump, "images/e3bae37501dc3d2b7fb3898c804ed979.jpg", "jpg", 55470);
  danbooru_generate_coefficient_sql(dump, "images/b6cdfc1a7f7bed10fff54cc49c4c5155.jpg", "jpg", 16385);
  danbooru_generate_coefficient_sql(dump, "images/24ee6cc209bd325a26832b50f1aaddb6.jpg", "jpg", 37865);
  danbooru_generate_coefficient_sql(dump, "images/cd6491e86a69ec298a7b05f8b5362ea1.jpg", "jpg", 100521);
  danbooru_generate_coefficient_sql(dump, "images/ff73a4ae853baf812e94a82219b27b52.jpg", "jpg", 26162);
  danbooru_generate_coefficient_sql(dump, "images/960354bc8fa79cb3ee68dc9efdb5514b.jpg", "jpg", 27181);
  danbooru_generate_coefficient_sql(dump, "images/6f20f8dc4487700b5e428712b253e77d.jpg", "jpg", 113818);
  danbooru_generate_coefficient_sql(dump, "images/e288e683f4a8683d29ad9f91453755ae.jpg", "jpg", 13395);
  danbooru_generate_coefficient_sql(dump, "images/801b5c1a617dd272446fd0a5c16cdc56.jpg", "jpg", 125831);
  danbooru_generate_coefficient_sql(dump, "images/42f2fce308683f77abfe923cd145e90f.jpg", "jpg", 8828);
  danbooru_generate_coefficient_sql(dump, "images/a8f6cab4e00b2a9601858eda08ec10cf.jpg", "jpg", 16191);
  danbooru_generate_coefficient_sql(dump, "images/8c5d428570fc21e1efe029098d0c3174.jpg", "jpg", 112300);
  danbooru_generate_coefficient_sql(dump, "images/820336107d839225559dfd3636367c5f.jpg", "jpg", 72130);
  danbooru_generate_coefficient_sql(dump, "images/2f8496f23a60310388a2f741f09db6ab.jpg", "jpg", 97794);
  danbooru_generate_coefficient_sql(dump, "images/c2cf05d8e8325bfd28b05fea93480b8e.jpg", "jpg", 47527);
  danbooru_generate_coefficient_sql(dump, "images/9ac5d437b259ca979cbdaa9cf05c3766.jpg", "jpg", 2669);
  danbooru_generate_coefficient_sql(dump, "images/e9618f2ce913ba74429cfed00f7c97fe.jpg", "jpg", 15174);
  danbooru_generate_coefficient_sql(dump, "images/117ab58899ec1b3487bf0ea7c00dc9ce.jpg", "jpg", 110507);
  danbooru_generate_coefficient_sql(dump, "images/55368678513034670f8f43a22190f538.jpg", "jpg", 58128);
  danbooru_generate_coefficient_sql(dump, "images/32c35709523ee69bb12bf5e399d116da.jpg", "jpg", 66042);
  danbooru_generate_coefficient_sql(dump, "images/567483a514f44727778e87f7327e697d.jpg", "jpg", 114689);
  danbooru_generate_coefficient_sql(dump, "images/c21c7c99537b0ce02ed1216827f18d3d.jpg", "jpg", 50496);
  danbooru_generate_coefficient_sql(dump, "images/6c6f471fc73685f28c68852ff0f2e71f.png", "png", 39496);
  danbooru_generate_coefficient_sql(dump, "images/a93809143e49128633a1c8ebd456ccb6.jpg", "jpg", 45450);
  danbooru_generate_coefficient_sql(dump, "images/28f53ef8ea9d50f6ce11e1c1acd13b74.jpg", "jpg", 111200);
  danbooru_generate_coefficient_sql(dump, "images/ca453ff23f5aad783c0e6538537ffacd.jpg", "jpg", 4198);
  danbooru_generate_coefficient_sql(dump, "images/7d5877f8b1f01afbd02d841c25d10298.jpg", "jpg", 39947);
  danbooru_generate_coefficient_sql(dump, "images/4808d314bb1dd9e35f1461f489619f83.jpg", "jpg", 66915);
  danbooru_generate_coefficient_sql(dump, "images/76c49768d70d552733a8c69dff94b678.jpg", "jpg", 74985);
  danbooru_generate_coefficient_sql(dump, "images/ce688dd57322186ebbe8d065a2f0d663.jpg", "jpg", 93781);
  danbooru_generate_coefficient_sql(dump, "images/f26c884dcd4a39036574cb0b347fa359.jpg", "jpg", 64834);
  danbooru_generate_coefficient_sql(dump, "images/f26de96faecaf7549cdebac1e3beee89.jpg", "jpg", 95585);
  danbooru_generate_coefficient_sql(dump, "images/eca3244b3fc76a1ad9d9d30b62240140.jpg", "jpg", 56819);
  danbooru_generate_coefficient_sql(dump, "images/7bb11b1d665fda17a5bf6009c24cd230.jpg", "jpg", 119064);
  danbooru_generate_coefficient_sql(dump, "images/10ac348e0b5d8de577a62b23c9b6825a.jpg", "jpg", 47516);
  danbooru_generate_coefficient_sql(dump, "images/1a0e7986965756dc21eb6011d6e39085.jpg", "jpg", 37372);
  danbooru_generate_coefficient_sql(dump, "images/bd5f5efdbef5668c73cad32ac00654e5.jpg", "jpg", 4415);
  danbooru_generate_coefficient_sql(dump, "images/0da67be6a6e97d2b6d71b658b94453b7.jpg", "jpg", 79479);
  danbooru_generate_coefficient_sql(dump, "images/a130f224e244dbf9ba06dcf2e2c11bf4.jpg", "jpg", 107762);
  danbooru_generate_coefficient_sql(dump, "images/c568301c6ad552f0f87f9dd86e9c075e.jpg", "jpg", 89489);
  danbooru_generate_coefficient_sql(dump, "images/02467dc2a9bca78d715ad886cfe6bf33.jpg", "jpg", 40011);
  danbooru_generate_coefficient_sql(dump, "images/6559136268847bd1b3e3270a4ed7e9ae.jpg", "jpg", 137014);
  danbooru_generate_coefficient_sql(dump, "images/3ab3f392d897985cacc556a42a531c2b.jpg", "jpg", 93463);
  danbooru_generate_coefficient_sql(dump, "images/9f29636b1311ee000f1368b874220188.jpeg", "jpg", 129163);
  danbooru_generate_coefficient_sql(dump, "images/479964782c0e4ed0437747a0806fa4fe.jpg", "jpg", 84956);
  danbooru_generate_coefficient_sql(dump, "images/20c154d10e7595320d4a93f8d53a63d3.jpg", "jpg", 113308);
  danbooru_generate_coefficient_sql(dump, "images/1b83555c89bb3b2a52e59adcfb4f3529.jpg", "jpg", 10447);
  danbooru_generate_coefficient_sql(dump, "images/f130a51b8ecab8977f56d2abb4ac6fec.jpg", "jpg", 25808);
  danbooru_generate_coefficient_sql(dump, "images/24837ed71e61c623ea6e36c510c593ea.jpg", "jpg", 66303);
  danbooru_generate_coefficient_sql(dump, "images/51a68ae1710487ea9a6abe6ffad3696e.jpg", "jpg", 58783);
  danbooru_generate_coefficient_sql(dump, "images/70a0aff8bd51895c5db9aff3f9efbcbe.jpg", "jpg", 54763);
  danbooru_generate_coefficient_sql(dump, "images/c714cd85685d7622487e058dc5f6d90d.jpg", "jpg", 124636);
  danbooru_generate_coefficient_sql(dump, "images/2115edb0d1c6bdb5fa7cd5a44c1c6e72.jpg", "jpg", 23898);
  danbooru_generate_coefficient_sql(dump, "images/982cf736087a1cffa970806047ee48c0.jpg", "jpg", 113391);
  danbooru_generate_coefficient_sql(dump, "images/60cce7ce27076491105a7b8511da0a44.jpg", "jpg", 44352);
  danbooru_generate_coefficient_sql(dump, "images/15a30595ea64397e3cc8683a8b90c779.jpg", "jpg", 130740);
  danbooru_generate_coefficient_sql(dump, "images/8153377522be7893be25aa4628d62494.jpg", "jpg", 47863);
  danbooru_generate_coefficient_sql(dump, "images/403079634d8278d680681a15cef14c84.jpg", "jpg", 127380);
  danbooru_generate_coefficient_sql(dump, "images/850d8fc8f7eef723789d2804f4e56a48.jpg", "jpg", 75506);
  danbooru_generate_coefficient_sql(dump, "images/0e62f98ee408378ac9a8da7189ef4736.jpg", "jpg", 57974);
  danbooru_generate_coefficient_sql(dump, "images/b7170ce000b01b59fe4b43ff01ad38ea.jpg", "jpg", 95045);
  danbooru_generate_coefficient_sql(dump, "images/dab8b92b73bbab778b5bf241f3bb4779.jpg", "jpg", 47843);
  danbooru_generate_coefficient_sql(dump, "images/ee086cec90318e07991504211319d611.jpg", "jpg", 70313);
  danbooru_generate_coefficient_sql(dump, "images/eca52675b3d0e4db3c8d459eba01c947.jpg", "jpg", 17560);
  danbooru_generate_coefficient_sql(dump, "images/874aec56b06bc2233d5061444ba76e0a.jpg", "jpg", 69499);
  danbooru_generate_coefficient_sql(dump, "images/4aa04abf6e4b28b1cfa826e3a75cfcd8.jpg", "jpg", 15754);
  danbooru_generate_coefficient_sql(dump, "images/5a46780fbaebb80c257d2dcf41e83254.jpg", "jpg", 75338);
  danbooru_generate_coefficient_sql(dump, "images/7466be223ce6e88c442de7bd612a1093.jpg", "jpg", 29272);
  danbooru_generate_coefficient_sql(dump, "images/6cfdf68a7249e73beaae5326df5b7eee.jpg", "jpg", 115099);
  danbooru_generate_coefficient_sql(dump, "images/d7938623dc648343b8de92d36d759da0.jpg", "jpg", 71873);
  danbooru_generate_coefficient_sql(dump, "images/7e76b3e0edae62a9ca512945f39623da.jpg", "jpg", 49312);
  danbooru_generate_coefficient_sql(dump, "images/6418aeb7a4e597296b9a8418f80a2ce1.jpg", "jpg", 61692);
  danbooru_generate_coefficient_sql(dump, "images/1b68ae95367c813dd5ae0ef83826092a.jpg", "jpg", 124646);
  danbooru_generate_coefficient_sql(dump, "images/e807f7a48e70687dfbc4d31fe72f0b88.jpg", "jpg", 35550);
  danbooru_generate_coefficient_sql(dump, "images/320258eff96ea04dc17a2f45fe3d12a1.jpg", "jpg", 136969);
  danbooru_generate_coefficient_sql(dump, "images/b1f2556457e421d818a0a87aaff388b2.jpg", "jpg", 13691);
  danbooru_generate_coefficient_sql(dump, "images/40cde96532866dea9e544549df71d37d.jpg", "jpg", 95722);
  danbooru_generate_coefficient_sql(dump, "images/8153fc530b3a03dfad15274e0f6060f6.jpg", "jpg", 8686);
  danbooru_generate_coefficient_sql(dump, "images/ef3bae8bf25d6dac5bd16e2cb4a45106.png", "png", 21755);
  danbooru_generate_coefficient_sql(dump, "images/4e32030fe074da0c247bf932c0108b93.jpg", "jpg", 136680);
  danbooru_generate_coefficient_sql(dump, "images/6cb218d36b10ee68cc4efa6d60ebd96f.jpg", "jpg", 59915);
  danbooru_generate_coefficient_sql(dump, "images/cb6add639873fdf1ee3ab5f415fad8b3.jpg", "jpg", 36983);
  danbooru_generate_coefficient_sql(dump, "images/c9931375afcc39e5e0cabbb87a6f18f8.png", "png", 108499);
  danbooru_generate_coefficient_sql(dump, "images/c02cba35278b0bb74e63c492340ad594.jpg", "jpg", 77410);
  danbooru_generate_coefficient_sql(dump, "images/f566b54ddd9b667b2315fc065a206606.jpg", "jpg", 66983);
  danbooru_generate_coefficient_sql(dump, "images/b844581dd6f3d274cc21bf3c5ede28d5.jpg", "jpg", 17069);
  danbooru_generate_coefficient_sql(dump, "images/3fc305078df01d1eb886c3626ddab135.jpg", "jpg", 85325);
  danbooru_generate_coefficient_sql(dump, "images/ff87e4175f7791a2aacdc7b65fb7bd9a.jpg", "jpg", 4634);
  danbooru_generate_coefficient_sql(dump, "images/e68c71a2e0975bd6d792c0208d2578ed.png", "png", 30091);
  danbooru_generate_coefficient_sql(dump, "images/73ac589f07d297f9970d5e1fb2197250.jpg", "jpg", 16479);
  danbooru_generate_coefficient_sql(dump, "images/7eb56e51cb84cf0910c67ec842001562.jpg", "jpg", 137094);
  danbooru_generate_coefficient_sql(dump, "images/e927401314c137d8ee3166df57012f25.jpg", "jpg", 62686);
  danbooru_generate_coefficient_sql(dump, "images/324d6542e1e0b23a348100e10793647c.jpg", "jpg", 90641);
  danbooru_generate_coefficient_sql(dump, "images/e4bd6ea59aeb588d8428c3b1f0611d46.jpg", "jpg", 105216);
  danbooru_generate_coefficient_sql(dump, "images/35e1a8b31bd043af930e20aa3f7cd937.jpg", "jpg", 96203);
  danbooru_generate_coefficient_sql(dump, "images/8772d260288c597b2aca6f2c30fa14c4.jpg", "jpg", 109543);
  danbooru_generate_coefficient_sql(dump, "images/7978035a7ab45decef6002bf29e198d0.jpg", "jpg", 95056);
  danbooru_generate_coefficient_sql(dump, "images/80c4368ccf947dcacd6f9b513f670a6e.jpg", "jpg", 57598);
  danbooru_generate_coefficient_sql(dump, "images/148599ab5526cbaf399155e683324a92.jpg", "jpg", 128867);
  danbooru_generate_coefficient_sql(dump, "images/effffca5508ceba3fd34908889aec7d0.jpg", "jpg", 6251);
  danbooru_generate_coefficient_sql(dump, "images/90a6a1ee5fa60165a577657403f572a0.jpg", "jpg", 113934);
  danbooru_generate_coefficient_sql(dump, "images/32d50d20b106d2f563672e566a232df5.jpg", "jpg", 82589);
  danbooru_generate_coefficient_sql(dump, "images/cb9c10238315ce192e67b164a137de35.jpg", "jpg", 56354);
  danbooru_generate_coefficient_sql(dump, "images/24dceb0e78d4069a26b79a255cf9e9f4.jpg", "jpg", 115959);
  danbooru_generate_coefficient_sql(dump, "images/9ea6a07934d67fdba14d9153fc3f77d3.jpg", "jpg", 13905);
  danbooru_generate_coefficient_sql(dump, "images/231164496093f5f781a06ef252f957c7.jpg", "jpg", 142610);
  danbooru_generate_coefficient_sql(dump, "images/7f2b1e086623a870e9eb40402d5a9b8c.jpg", "jpg", 55810);
  danbooru_generate_coefficient_sql(dump, "images/ac085e1af5e2829f52ed88d27ab41f07.jpg", "jpg", 42677);
  danbooru_generate_coefficient_sql(dump, "images/371ff44df724e86f79b9aef44422cbe6.jpg", "jpg", 70546);
  danbooru_generate_coefficient_sql(dump, "images/05cea7d1ba8e1ad5c66b6bcbbc2cbb0f.jpg", "jpg", 141049);
  danbooru_generate_coefficient_sql(dump, "images/02017b741186e1348d899f4f6c5b333c.jpg", "jpg", 23788);
  danbooru_generate_coefficient_sql(dump, "images/f720b7bdeada1019878aa9c9b942dcda.jpg", "jpg", 33458);
  danbooru_generate_coefficient_sql(dump, "images/6601e006e2cf5e61816136c274c1b04f.jpg", "jpg", 31347);
  danbooru_generate_coefficient_sql(dump, "images/3f1789da0d0b954f45caaea52c3ec68f.jpg", "jpg", 84989);
  danbooru_generate_coefficient_sql(dump, "images/89424ab88a4d6803b0f4d242954f46e6.jpg", "jpg", 57420);
  danbooru_generate_coefficient_sql(dump, "images/6a6faca1e904d4b33c16960260f60f1a.jpg", "jpg", 11451);
  danbooru_generate_coefficient_sql(dump, "images/1c63830224632d4a167cb4b09dcb0d41.jpg", "jpg", 3986);
  danbooru_generate_coefficient_sql(dump, "images/f990b54dff2d22b783aa85186ece4c92.jpg", "jpg", 77995);
  danbooru_generate_coefficient_sql(dump, "images/5fc022d7c8ad10acba2d241b01d85020.jpg", "jpg", 90372);
  danbooru_generate_coefficient_sql(dump, "images/8e464befe14c65c6c5b6102b359eb0e1.jpg", "jpg", 11983);
  danbooru_generate_coefficient_sql(dump, "images/931098ef23f15f77e9ac23869eb68a10.jpg", "jpg", 87892);
  danbooru_generate_coefficient_sql(dump, "images/e28edbdfe6779e43537a5e67bf8081eb.jpg", "jpg", 71815);
  danbooru_generate_coefficient_sql(dump, "images/968f760318a1bd21fe0519f4201ec619.gif", "gif", 30150);
  danbooru_generate_coefficient_sql(dump, "images/dcafe3d612ecc0c44053ad2dae136875.jpg", "jpg", 90855);
  danbooru_generate_coefficient_sql(dump, "images/fde3820eece1a9ebb03dd029d1803b2f.jpg", "jpg", 136574);
  danbooru_generate_coefficient_sql(dump, "images/6a60f3766c4db644c5af9edf03785675.png", "png", 83625);
  danbooru_generate_coefficient_sql(dump, "images/dce9ce780505e051e91ceafe720f882c.jpg", "jpg", 33519);
  danbooru_generate_coefficient_sql(dump, "images/2f7578a7394056a4c13288f05f183f08.png", "png", 30661);
  danbooru_generate_coefficient_sql(dump, "images/8aa8b9d63c3a334f989d785450966ef7.jpg", "jpg", 10523);
  danbooru_generate_coefficient_sql(dump, "images/cb33c25e045a141dc6535dce904acab2.jpg", "jpg", 45097);
  danbooru_generate_coefficient_sql(dump, "images/71f12d2fba46ee8acf9804dee577c6da.png", "png", 35046);
  danbooru_generate_coefficient_sql(dump, "images/62ac16745b7d825d0680b17ccac9b4a4.jpg", "jpg", 73081);
  danbooru_generate_coefficient_sql(dump, "images/44ed8534c4dc39639e10585aee66baef.jpg", "jpg", 128135);
  danbooru_generate_coefficient_sql(dump, "images/35a1bedfc5caa4624bc82a9d43c688f3.jpg", "jpg", 106897);
  danbooru_generate_coefficient_sql(dump, "images/9e600092352b9c371e0e6cd90de9f1ef.jpg", "jpg", 25791);
  danbooru_generate_coefficient_sql(dump, "images/304d6e606592374df5414f43d4f829d6.png", "png", 124924);
  danbooru_generate_coefficient_sql(dump, "images/f74cc0011564f128b6f5ac875ddd14cf.png", "png", 12239);
  danbooru_generate_coefficient_sql(dump, "images/d6ebfbde58c75054276a3b2c8016da0d.jpg", "jpg", 106345);
  danbooru_generate_coefficient_sql(dump, "images/400fb3c678bab05cf07bd64d148ce3be.jpg", "jpg", 11411);
  danbooru_generate_coefficient_sql(dump, "images/ae821a9228818efb8ea7d57c210f7f57.jpg", "jpg", 122808);
  danbooru_generate_coefficient_sql(dump, "images/4593bd3ef5b0a2837c54e98b52f6ab64.jpg", "jpg", 43317);
  danbooru_generate_coefficient_sql(dump, "images/ca6366a42fddda3ce586317f60d5957b.jpg", "jpg", 89294);
  danbooru_generate_coefficient_sql(dump, "images/87b984673ca9a29ed83d17038f7fa52b.jpg", "jpg", 11449);
  danbooru_generate_coefficient_sql(dump, "images/6ff2e78e1e1fd62c47523d75ce912c6c.jpg", "jpg", 76169);
  danbooru_generate_coefficient_sql(dump, "images/678b8b2dc18e1c20930ff0645614833d.png", "png", 44687);
  danbooru_generate_coefficient_sql(dump, "images/7e8fe9b22d795816041e559d175c2023.jpg", "jpg", 111148);
  danbooru_generate_coefficient_sql(dump, "images/fade3405482ee466212696b622b61f8b.jpg", "jpg", 87038);
  danbooru_generate_coefficient_sql(dump, "images/c9e3e77a1a0e268294793e2c249982f3.jpg", "jpg", 38852);
  danbooru_generate_coefficient_sql(dump, "images/083d195a398f7a365c945fa411dab796.jpg", "jpg", 118049);
  danbooru_generate_coefficient_sql(dump, "images/6920a4cfa5b1f2499f6e72ed202d2888.jpg", "jpg", 73997);
  danbooru_generate_coefficient_sql(dump, "images/eaf05a117a50201e36ab13066e7588b0.jpg", "jpg", 12880);
  danbooru_generate_coefficient_sql(dump, "images/e58f041f62480f0b272d0aa2466086b0.jpg", "jpg", 28724);
  danbooru_generate_coefficient_sql(dump, "images/b996e930686c4df4b2b2f3326647128a.jpg", "jpg", 91450);
  danbooru_generate_coefficient_sql(dump, "images/f324d00856674263a353ebd69a20d0eb.jpg", "jpg", 86798);
  danbooru_generate_coefficient_sql(dump, "images/f62de5d6c91c67d80d1a38f55e3c35a7.jpg", "jpg", 12054);
  
  fclose(dump);
  
  return 0;
}
