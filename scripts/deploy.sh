#!/bin/sh

set -xe

JWM_REPO=file:///$HOME/devel/jwm
JWM_BUILD=/tmp/jwm

WWWROOT=/var/www/htdocs/joewing.net
SRCDIR=`pwd`/`dirname $0`/..
TMPDIR=/tmp/www

# Create the webpage in the temporary directory.
DIR=`pwd`
rm -rf $TMPDIR
mkdir $TMPDIR
cp -r $SRCDIR/* $TMPDIR
cd $TMPDIR
python scripts/generate.py

# Generate JWM documentation
rm -rf $JWM_BUILD
git clone $JWM_REPO $JWM_BUILD
cd $JWM_BUILD
doxygen
mv doc/html $TMPDIR/projects/jwm/doc
cd $DIR
rm -rf $JWM_BUILD

# Sync with the main website.
rsync -av $TMPDIR/ $WWWROOT
mkdir -p $WWWROOT/stats

# Clean up
rm -rf $TMPDIR
