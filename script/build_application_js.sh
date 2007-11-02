#!/bin/bash

JS=/home/albert/miezaru/public/javascripts

echo "" > $JS/application.js

for i in prototype effects controls common cookie comment favorite forum image_resize notes pool post post_mode_menu related_tags ; do
    cat $JS/$i.js >> $JS/application.js
done
