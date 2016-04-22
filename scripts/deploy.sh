#!/bin/sh

set -e

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

# Sync with the main website.
cp -r $TMPDIR/* $WWWROOT
mkdir -p $WWWROOT/stats
mkdir -p $WWWROOT/snapshots

# Clean up
rm -rf $TMPDIR
