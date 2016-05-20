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

# Update PO files.
cd $REPO
git pull
make update-po
git commit -am "Update PO files."

# Check out JWM.
rm -rf $BUILDDIR
git clone $REPO $BUILDDIR > /dev/null 2>&1
cd $BUILDDIR

# Create a tag.
if [ `git tag | grep "v$VERSION"` ] ; then
    echo "Already tagged"
else
    git tag -a "v$VERSION" -m "Version $VERSION"
    git push --tags
    cd $REPO
    git push --tags
    cd $BUILDDIR
fi

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

# Update the web page.
mv $NAME.tar.xz $WEBDIR/projects/jwm/releases
cd $WEBDIR
git pull
REVISION_FILE="$WEBDIR/release-inc.shtml"
echo "<!--#set var=\"RELEASE\" value=\"$VERSION\"-->" > $REVISION_FILE
git add releases/$NAME.tar.xz
git commit -am "JWM release v$VERSION."
git push
