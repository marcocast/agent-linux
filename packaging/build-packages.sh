#!/bin/bash

set -e

VENDOR="activeeon-dev@activeeon.com"
DESCRIPTION="The ProActive Agent enables desktop computers as an important source of computational power"
URL="http://activeeon.com"

VERSION=${VERSION:-1.0.3}
JRE_VERSION=${JRE_VERSION:-7u67-b01}
[ -n "$NODE" ] || ( echo "NODE variable should point to the unpacked ProActiveNode"; exit 1 )

THIS=$(cd $(dirname $0); pwd)
REPO=$(dirname $THIS)
BUILD=$REPO/build/

export GEM_HOME=~/gems

WGET="wget --no-check-certificate --no-cookies --no-clobber"

KIND=$1
[ -n "$KIND" ] || ( echo "usage: $0 <deb|rpm>"; exit 1 )

install_fpm () {
    [ -f "$GEM_HOME/bin/fpm" ] || gem install fpm 
}

download_jres () {
    mkdir -p $BUILD/jre
    $WGET --header "Cookie: oraclelicense=accept-securebackup-cookie" -P $BUILD/jre http://download.oracle.com/otn-pub/java/jdk/$JRE_VERSION/jre-${JRE_VERSION%-*}-linux-x64.tar.gz
    $WGET --header "Cookie: oraclelicense=accept-securebackup-cookie" -P $BUILD/jre http://download.oracle.com/otn-pub/java/jdk/$JRE_VERSION/jre-${JRE_VERSION%-*}-linux-i586.tar.gz
}

package () {
    local KIND=$1
    local ARCH=$2
    [ -n "$KIND" ] || ( echo "usage: package <deb|rpm> <i386|amd64>"; exit 1 )
    [ -n "$ARCH" ] || ( echo "usage: package <deb|rpm> <i386|amd64>"; exit 1 )

    local PREFIX=$BUILD/$KIND/$ARCH

    rm -fr $PREFIX

    mkdir -p $PREFIX/etc/init.d
    cp $REPO/packaging/$KIND/proactive-agent $PREFIX/etc/init.d

    mkdir -p $PREFIX/opt/proactive-agent
    rsync -avP --delete $REPO/proactive-agent $REPO/proactive-agent.1 $REPO/palinagent $REPO/config* $REPO/data $REPO/LICENSE.txt \
        $PREFIX/opt/proactive-agent/

    mkdir -p $PREFIX/opt/proactive-node
    rsync -avP --delete $NODE/ $PREFIX/opt/proactive-node/

    mkdir -p $PREFIX/opt/jre
    case $ARCH in
        amd64)
            local JRE=$BUILD/jre/jre-${JRE_VERSION%-*}-linux-x64.tar.gz
            ;;
        i386)
            local JRE=$BUILD/jre/jre-${JRE_VERSION%-*}-linux-i586.tar.gz
    esac
    tar -C $PREFIX/opt/jre --strip-components 1 -xf $JRE

    mkdir -p $BUILD/distributions
    ~/gems/bin/fpm -s dir -t $KIND -C $PREFIX -p $BUILD/distributions/ \
        -n "proactive-agent" \
        -v $VERSION \
        -a $ARCH \
        --maintainer "$VENDOR" \
        --vendor "$VENDOR" \
        --description "$DESCRIPTION" \
        --url "$URL" \
        -d python -d python-lxml \
        --post-install $REPO/packaging/$KIND/postinst  \
        --pre-uninstall $REPO/packaging/$KIND/prerm \
        --post-uninstall $REPO/packaging/$KIND/postrm \
        .
}

install_fpm

download_jres

for ARCH in amd64 i386; do
    package $KIND $ARCH
done
