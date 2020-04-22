#!/bin/bash

hexo clean
hexo g
git add .
git commit -m "update"
git push
