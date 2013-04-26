freebsd-release
===============

release(7) the latest FreeBSD release. supports 9.x and newer.

REQUIREMENT
===========

- git
- subversion

USAGE
=====

release the latest release for same TARGET and TARGET_ARCH on build host.

    # make

publish the result to PUBLIC_WWWDIR

    # make publish

cross build i386 on amd64

    # make TARGET=i386 TARGET_ARCH=i386

currently, supported architectures include amd64 and i386 (update mtree file to
support more architectures).

make init
=========

NOOP

make all
========

- do release(7)

make publish
============

- copy created distfiles and ISO images to PUBLIC_WWWDIR

SEE ALSO
========

https://github.com/trombik/freebsd-release
