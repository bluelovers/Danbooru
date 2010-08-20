#!/usr/bin/env bash

psql -hdbserver -c "UPDATE post_tag_histories SET source = (SELECT source FROM posts WHERE id = post_id)" danbooru 
