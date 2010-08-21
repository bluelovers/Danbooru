#!/usr/bin/env bash

PGOPTIONS="-c statement_timeout=0" psql -hdbserver -c "UPDATE post_tag_histories SET source = (SELECT source FROM posts WHERE id = post_id)" danbooru 
