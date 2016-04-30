#!/bin/sh

set -e

WWWROOT=/var/www/htdocs/joewing.net
JWM_REPO=file:///$HOME/devel/jwm
JWM_BUILD=/tmp/jwm

# Generate JWM documentation
rm -rf $JWM_BUILD
git clone --depth 1 $JWM_REPO $JWM_BUILD
cd $JWM_BUILD
doxygen
mkdir -p $WWWROOT/projects/jwm/doc
mv doc/html/* $WWWROOT/projects/jwm/doc
cd $DIR
rm -rf $JWM_BUILD

