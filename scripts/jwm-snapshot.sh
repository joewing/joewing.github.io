#!/bin/sh

set -e

WEBDIR="/var/www/joewing.net"
REPO="$HOME/devel/jwm"
BUILDDIR="/tmp/jwm"
CONFIG_FLAGS=""

# Check out JWM.
cd $REPO
git pull -r
rm -rf $BUILDDIR
git clone $REPO $BUILDDIR > /dev/null 2>&1
cd $BUILDDIR

# Pick a version number.
VERSION=`git log --oneline | wc -l | tr -d ' '`
NAME="jwm-$VERSION"

# Create a tag.
if [ `git tag | grep "s$VERSION"` ] ; then
    echo "Already tagged"
else
    git tag -s -a "s$VERSION" -m "Snapshot $VERSION"
    git push --tags
    cd $REPO
    git push --tags
    cd $BUILDDIR
fi

# Configure JWM.
NEW_INIT="jwm, git-$VERSION, joewing\@joewing\.net"
sed "s/AC_INIT.*/AC_INIT\(${NEW_INIT}\)/" configure.ac > configure.ac.new
mkdir -p $WEBDIR/projects/jwm/snapshots
git log --name-status --decorate > $WEBDIR/projects/jwm/snapshots/ChangeLog
mv configure.ac.new configure.ac
./autogen.sh
./configure $CONFIG_FLAGS

# Create the snapshot.
make tarball VERSION=$VERSION > /dev/null 2>&1

# Remove our temporary directory.
cd ..
rm -rf $BUILDDIR

# Create a signature.
gpg -sb --output $NAME.sig $NAME.tar.xz

# Put the snapshot in the right place.
mv $NAME.sig $WEBDIR/projects/jwm/snapshots
mv $NAME.tar.xz $WEBDIR/projects/jwm/snapshots
cd $WEBDIR
git pull
REVISION_FILE="$WEBDIR/projects/jwm/snapshot-inc.shtml"
echo "<!--#set var=\"SNAPSHOT\" value=\"$VERSION\"-->" > $REVISION_FILE
git commit -S -am "JWM snapshot $VERSION."
git push
