#!/bin/bash

git pull
hexo clean
hexo g
git add .
git commit -m "update"
git push
