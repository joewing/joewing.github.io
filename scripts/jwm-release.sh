#!/bin/bash

if [ $# -ne 1 ] ; then
    echo "usage: $0 <major>.<minor>.<revision>"
    exit -1
fi
VERSION=$1

echo "Building JWM v$VERSION"
NAME="jwm-$VERSION"

WEBDIR="/var/www/joewing.net"
REPO="$HOME/devel/jwm"
BUILDDIR="/tmp/jwm"
CONFIG_FLAGS=""

# Make sure the repo is clean.
cd $REPO
if [ `git status -s | grep -v "??" | wc -l` -ne 0 ] ; then
    echo "Working directory not clean"
    exit -1
fi

# Update PO files.
git pull
./autogen.sh
make update-po
if [ `git status -s | grep -v "??" | wc -l` -ne 0 ] ; then
    git commit -S -am "Update PO files."
fi

# Create a tag.
if [ `git tag | grep "v$VERSION"` ] ; then
    echo "Already tagged"
else
    git tag -s -a "v$VERSION" -m "Version $VERSION"
    git push --tags
fi

# Check out a copy.
rm -rf $BUILDDIR
git clone $REPO $BUILDDIR > /dev/null 2>&1
cd $BUILDDIR

# Configure JWM.
git log --name-status --decorate > ChangeLog
cp ChangeLog $WEBDIR/projects/jwm/snapshots/ChangeLog
./autogen.sh
./configure $CONFIG_FLAGS > /dev/null 2>&1

# Create the tarball.
make tarball VERSION=$VERSION > /dev/null 2>&1

# Remove our temporary directory.
cd ..
rm -rf $BUILDDIR

# Create a signature.
gpg -sb --output $NAME.sig $NAME.tar.xz

# Update the web page.
mv $NAME.sig $WEBDIR/projects/jwm/releases
mv $NAME.tar.xz $WEBDIR/projects/jwm/releases
cd $WEBDIR
git pull
REVISION_FILE="$WEBDIR/projects/jwm/release-inc.shtml"
echo "<!--#set var=\"RELEASE\" value=\"$VERSION\"-->" > $REVISION_FILE
git add $WEBDIR/projects/jwm/releases/$NAME.tar.xz
git add $WEBDIR/projects/jwm/releases/$NAME.sig
git commit -S -am "JWM release v$VERSION."
git push
