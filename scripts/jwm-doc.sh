#!/bin/sh

WEBROOT=`pwd`/`dirname $0`/..
WEBDIR="$WEBROOT/projects/jwm"
REPO="git@github.com:joewing/jwm.git"
BUILDDIR="/tmp/jwm"

# Check out JWM.
git clone $REPO $BUILDDIR
cd $BUILDDIR

# Generate source documentation.
doxygen
rm -rf $WEBDIR/doc
mv doc/html $WEBDIR/doc
cd -
rm -rf /tmp/jwm
