#!/bin/bash
#
#
# simple build script for dhcpy6d
#
#

OS=unknown

function get_os() {
  if [ -f /etc/debian_version ]; then
    OS=debian
  elif [ -f /etc/redhat-release ]; then
    yum install -y sudo which
    OS=redhat
  fi
}

function create_manpages() {
  if ! which rst2man; then
    if [ "$OS" == "debian" ]; then
      sudo apt -y install python3-docutils
    fi
    if [ "$OS" == "redhat" ]; then
      sudo yum -y install python3-docutils
    fi
  fi

  echo "Creating manpages from RST files"
  rst2man doc/dhcpy6d.rst man/man8/dhcpy6d.8
  rst2man doc/dhcpy6d.conf.rst man/man5/dhcpy6d.conf.5
  rst2man doc/dhcpy6d-clients.conf.rst man/man5/dhcpy6d-clients.conf.5
}

# find out where script runs at
get_os

if [ "$OS" == "debian" ]; then
  echo "Building .deb package"

  create_manpages

  # install missing packages
  if ! which debuild; then
    sudo apt -y install build-essential devscripts dh-python dh-systemd python3-setuptools
  fi

  if [ ! -d /usr/share/doc/python3-all ]; then
    sudo apt -y install python3-all
  fi

  debuild --no-tgz-check -- clean
  debuild --no-tgz-check -- binary-indep

elif [ "$OS" == "redhat" ]; then
  echo "Building .rpm package"

  create_manpages

  # install missing packages
  if ! which rpmbuild; then
    sudo yum -y install python3-devel python3-setuptools rpm-build
  fi

  TOPDIR=$HOME/dhcpy6d.$$
  SPEC=redhat/dhcpy6d.spec

  # create source folder for rpmbuild
  mkdir -p $TOPDIR/SOURCES

  # init needed in TOPDIR/SOURCES
  cp -pf lib/systemd/system/dhcpy6d.service $TOPDIR/SOURCES/dhcpy6d

  # use setup.py sdist build output to get package name
  FILE=$(python3 setup.py sdist --dist-dir $TOPDIR/SOURCES | grep "creating dhcpy6d-" | head -n1 | cut -d" " -f2)
  echo Source file: $FILE.tar.gz

  # version
  VERSION=$(echo $FILE | cut -d"-" -f 2)

  # replace version in the spec file
  sed -i "s|Version:.*|Version: $VERSION|" $SPEC

  # workaround for less changes, but achieve build with new GitHub source
  # TDDO: clean up that build process
  cp ${TOPDIR}/SOURCES/${FILE}.tar.gz ${TOPDIR}/SOURCES/v${VERSION}.tar.gz

  # finally build binary rpm
  rpmbuild -bb --define "_topdir $TOPDIR" $SPEC

  echo $TOPDIR

  # get rpm file
  cp -f $(find $TOPDIR/RPMS -name "$FILE-?.*noarch.rpm") .

  # clean
  #rm -rf $TOPDIR
else
  echo "Package creation is only supported on Debian and RedHat derivatives."
fi
