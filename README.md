freebsd-release
===============

release(7) the latest FreeBSD release. supports 10.x and newer.

USAGE
=====

release the latest release for same TARGET and TARGET_ARCH on build host.

    # make

cross build i386 on amd64

    # make TARGET=i386 TARGET_ARCH=i386
 	# sudo make TARGET=i386

currently, supported architectures include amd64 and i386 (update mtree file to
support more architectures).

local patches support
---------------------

run "make all" at least once and see if release can be built. copy the patch to
PATCH_DIR (see "make -V PATCH_DIR"). run "make patch all". the subsequent "make
all" creates patched release. if you want revert all local modifications, "make
revert".

make all
========

- do release(7)

make publish
============

- copy created distfiles and ISO images to WWW_DIR
- create patch.txt by "svn diff" in /usr/src

make patch
==========

- do "make revert"
- apply patches under PATCH_DIR

make revert
===========

- revert any local modification in /usr/src

SEE ALSO
========

https://github.com/trombik/freebsd-release
