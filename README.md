freebsd-release
===============

release(7) the latest FreeBSD release and stable

REQUIREMENT
===========

- git
- subversion

USAGE
=====

    # make init
    # make

make init
=========

- creates directory structure
- svn checkout RELENG, STABLE and HEAD

make all
========

- do release(7)

make update, update-stable, update-head
=======================================

- svn checkout src

SEE ALSO
========

https://github.com/trombik/freebsd-release
