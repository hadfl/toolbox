#!/bin/bash

/usr/bin/diff <(/usr/bin/pkg search -l 'depend::' | /usr/bin/awk '{ print $3 }' | \
    /usr/bin/sort | /usr/bin/sed -r 's/^([^@]+).*/\1/' | /usr/bin/uniq) \
    <(/usr/bin/pkg list | /usr/bin/awk '{ print $1 }') | /usr/bin/grep '>'

