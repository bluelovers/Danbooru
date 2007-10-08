/* -*- Mode: C; tab-width: 4; indent-tabs-mode: t; c-basic-offset: 4 -*- */
/* gheap.h - fixed-size and dynamic heap data structures
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

#ifndef __G_HEAP_H__
#define __G_HEAP_H__

#include <glib.h>

typedef struct _GHeap GHeap;
typedef struct _GDynamicHeap GDynamicHeap;

struct _GHeap
{
	guint size;
	guint last_index;

	gpointer *heap;

	GCompareFunc compare;
};

struct _GDynamicHeap
{
	gpointer **level;
	guint64 *level_size;
	guint max_levels;

	guint last_level;
	guint64 last_index;

	GCompareFunc compare;
};

GHeap *g_heap_new(guint, GCompareFunc);
void g_heap_destroy(GHeap *);
gboolean g_heap_insert(GHeap *, gpointer);
gpointer g_heap_remove(GHeap *);

GDynamicHeap *g_dynamic_heap_new(guint, GCompareFunc);
void g_dynamic_heap_destroy(GDynamicHeap *);
void g_dynamic_heap_insert(GDynamicHeap *, gpointer);
gpointer g_dynamic_heap_remove(GDynamicHeap *);

#endif
