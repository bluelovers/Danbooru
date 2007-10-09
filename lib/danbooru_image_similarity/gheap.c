/* -*- Mode: C; tab-width: 4; indent-tabs-mode: t; c-basic-offset: 4 -*- */
/* gheap.c - implementation of fixed-size and dynamic heap data structures
 * Copyright (C) 1999 Jaka Mocnik
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

// #include <config.h>

#include "gheap.h"

#define MAX_LEVELS 64
#define INITIAL_LEVELS 5

GHeap *g_heap_new(guint size, GCompareFunc cf)
{
	GHeap *h;

	g_return_val_if_fail(cf != NULL, NULL);

	h = (GHeap *)g_new0(GHeap, 1);

	h->compare = cf;
	h->size = size;
	h->last_index = 1;

	h->heap = g_malloc(sizeof(gpointer)*size);

	return h;
}

void g_heap_destroy(GHeap *h)
{
	g_return_if_fail(h != NULL);

	if(h->heap)
		g_free(h->heap);
}

gboolean g_heap_insert(GHeap *h, gpointer el)
{
	guint idx, p_idx;

	g_return_val_if_fail(h != NULL, FALSE);
	g_return_val_if_fail(el != NULL, FALSE);

	idx = h->last_index;

	/* insert as the lowest, right-most one */
	if(idx > h->size)
		return FALSE;
	
	h->heap[idx-1] = el;
	h->last_index++;

	/* sift the element up */
	p_idx = idx/2;
	while(p_idx > 0 && h->compare(el, h->heap[p_idx-1]) < 0) {
		h->heap[idx-1] = h->heap[p_idx-1];
		h->heap[p_idx-1] = el;
		idx = p_idx;
		p_idx /= 2;
	}

	return TRUE;
}

gpointer g_heap_remove(GHeap *h)
{
	gpointer removed, root;
	guint idx, c_idx;
	gboolean sifted;
	
	g_return_val_if_fail(h != NULL, NULL);
	
	if(h->last_index == 1)
		return NULL;
	
	removed = h->heap[0];
	
	h->last_index--;
	
	/* put the lowest, right-most element in root */
	root = h->heap[0] = h->heap[h->last_index-1];

	/* sift it down */
	idx = 1;

	do {
		sifted = FALSE;

		/* choose the lesser child */
		c_idx = 2*idx;

		if((c_idx + 1 < h->last_index) &&
		   (h->compare(h->heap[c_idx-1], h->heap[c_idx]) > 0))
			c_idx++;

		/* sift it down the lesser child's branch? */
		if((c_idx < h->last_index) &&
		   (h->compare(root, h->heap[c_idx-1]) > 0)) {
			h->heap[idx-1] = h->heap[c_idx-1];
			h->heap[c_idx-1] = root;
			idx = c_idx;
			sifted = TRUE;
		}
	} while(sifted);

	return removed;
}

GDynamicHeap *g_dynamic_heap_new(guint max_levels, GCompareFunc cf)
{
	guint i, space;
	guint initial_levels, initial_space;
	GDynamicHeap *dh;

	g_return_val_if_fail(cf != NULL, NULL);
	g_return_val_if_fail(max_levels <= MAX_LEVELS, NULL);

	dh = g_new0(GDynamicHeap, 1);

	dh->compare = cf;

	dh->level = g_malloc(sizeof(gpointer *)*max_levels);
	dh->level_size = g_new0(guint64, max_levels);
	dh->max_levels = max_levels;

	dh->level_size[0] = 1;
	for(i = 1; i < dh->max_levels; i++)
		dh->level_size[i] = 2*dh->level_size[i - 1];

	initial_levels = MIN(INITIAL_LEVELS, max_levels);
	initial_space = 0;
	space = 1;
	for(i = 0; i < initial_levels; i++) {
		initial_space += space;
		space *= 2;
	}

	dh->level[0] = g_malloc(sizeof(gpointer *)*initial_space);
	for(i = 1; i < initial_levels; i++)
		dh->level[i] = dh->level[i-1] + dh->level_size[i-1];
	for(; i < max_levels; i++)
		dh->level[i] = NULL;

	dh->last_level = 0;

	return dh;
}

void g_dynamic_heap_destroy(GDynamicHeap *dh)
{
	gint i;

	g_return_if_fail(dh != NULL);

	g_free(dh->level[0]);

	for(i = MIN(INITIAL_LEVELS, dh->max_levels);
		i < dh->max_levels && dh->level[i] != NULL;
		i++)
		g_free(dh->level[i]);

	g_free(dh->level);
	g_free(dh->level_size);
}

void g_dynamic_heap_insert(GDynamicHeap *dh, gpointer el)
{
	guint idx, lev, p_idx, p_lev;

	g_return_if_fail(dh != NULL);
	g_return_if_fail(el != NULL);
	g_return_if_fail(dh->last_level < dh->max_levels);

	idx = dh->last_index;
	lev = dh->last_level;

	/* allocate a new level if necessary */
	if(idx == 0 && dh->level[lev] == NULL)
		dh->level[lev] = g_malloc(sizeof(gpointer)*dh->level_size[lev]);

	/* insert as the lowest, right-most one */
	dh->level[lev][idx] = el;

	dh->last_index++;
	if(dh->last_index >= dh->level_size[dh->last_level]) {
		dh->last_index = 0;
		dh->last_level++;
	}

	/* sift the element up */
	p_lev = lev - 1;
	p_idx = idx/2;
	while(lev > 0 && (dh->compare(el, dh->level[p_lev][p_idx]) < 0)) {
		dh->level[lev][idx] = dh->level[p_lev][p_idx];
		dh->level[p_lev][p_idx] = el;
		lev = p_lev;
		idx = p_idx;
		p_lev--;
		p_idx /= 2;
	}
}

gpointer g_dynamic_heap_remove(GDynamicHeap *dh)
{
	gpointer removed, root;
	guint idx, lev, c_idx, c_lev;
	gboolean sifted;

	g_return_val_if_fail(dh != NULL, NULL);

	if(dh->last_level == 0 && dh->last_index == 0)
		return NULL;

	removed = dh->level[0][0];

	/* decrease the last_level and last_index */
	if(dh->last_index == 0) {
		if(dh->level[dh->last_level + 1] != NULL &&
		   dh->last_level + 1 >= MIN(INITIAL_LEVELS, dh->max_levels))
			g_free(dh->level[dh->last_level + 1]);
		dh->last_level--;
		dh->last_index = dh->level_size[dh->last_level];
	}
	else
		dh->last_index--;

	if(dh->last_level == 0 && dh->last_index == 0)
		return removed;

	/* put the lowest, right-most element in root */
	root = dh->level[0][0] = dh->level[dh->last_level][dh->last_index - 1];

	/* sift it down */
	idx = lev = 0;

	do {
		sifted = FALSE;

		/* choose the lesser child */
		c_idx = 2*idx;
		c_lev = lev + 1;

		if((c_lev < dh->last_level ||
			(c_lev == dh->last_level && c_idx + 1 < dh->last_index)) &&
		   (dh->compare(dh->level[c_lev][c_idx], dh->level[c_lev][c_idx + 1]) > 0))
			c_idx++;

		/* sift it down the lesser child's branch? */
		if((c_lev < dh->last_level ||
			(c_lev == dh->last_level && c_idx < dh->last_index)) &&
		   (dh->compare(root, dh->level[c_lev][c_idx]) > 0)) {
			dh->level[lev][idx] = dh->level[c_lev][c_idx];
			dh->level[c_lev][c_idx] = root;
			idx = c_idx;
			lev = c_lev;
			sifted = TRUE;
		}
	} while(sifted);

	return removed;
}
