# FreeBSD release(8) Makefile
#
# Copyright (c) 2012 Tomoyuki Sakurai <tomoyukis@reallyenglish.com> All rights
# reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
# USAGE
#
# "make all" does release(7) and publish distributions.
#
# 	> sudo make
#
# release a specific TARGET
#
# 	> sudo make TARGET=i386
#
# NOTES
#
# required disk space per TARGET is 10 GB (chroot) + 240 MB (dist files), as of
# 10.0-RELEASE.
#
# SEE ALSO
#   http://www.freebsd.org/doc/en/articles/releng/index.html (outdated but still useful)
#   release(7)
#   /usr/src/release/Makefile
#   /usr/src/release/release.sh
#
# TODO
# - create "upload" target

SRC_BRANCH?=	releng/10.0
VERSION=	${SRC_BRANCH:C/.*\///}

TARGET?=	amd64
TARGET_ARCH?=	${TARGET}

PATCH_DIR=	${.CURDIR}/patches/${SRC_BRANCH}
CHROOT_DIR=	${.CURDIR}/chroot/${SRC_BRANCH}/${TARGET}
RELEASE_CONF=	${.CURDIR}/conf/release.conf
SRC_DIR=	${CHROOT_DIR}/usr/src
WWW_ROOT?=	${.CURDIR}/www
WWW_DIR?=	${WWW_ROOT}/pub/FreeBSD/releases/${TARGET}/${TARGET_ARCH}/${VERSION}-RELEASE
MTREE_FILE?=	${.CURDIR}/www.mtree

PATCH?=	/usr/bin/patch
# use -p1 for git style patches
PATCH_FLAGS?=	-p1

all:	init mkdir checkout-src patch release publish

init:
	@if ! . ${RELEASE_CONF} ; then \
		echo "cannot open ${RELEASE_CONF}"; \
		exit 1; \
	fi
	@if ! svn help >/dev/null 2>&1; then \
		echo 1>&2 "cannot find svn"; \
		exit 1; \
	fi

mkdir:
	mkdir -p ${CHROOT_DIR}
	# BUG copying resolv.conf fails
	mkdir -p ${CHROOT_DIR}/etc
	mkdir -p ${CHROOT_DIR}/usr
	mkdir -p ${WWW_ROOT}
	(cd ${WWW_ROOT} && mtree -uf ${MTREE_FILE})

checkout-src:
	# checkout src because we want to patch it
	( \
		export MY_CHROOTDIR=${CHROOT_DIR}; \
		export MY_TARGET=${TARGET}; \
		export MY_TARGET_ARCH=${TARGET_ARCH}; \
		export MY_SRCBRANCH=base/${SRC_BRANCH}; \
		. ${RELEASE_CONF}; \
		svn co --force $${SVNROOT}/$${SRCBRANCH} ${SRC_DIR}; \
	)

patch:	revert do-patch
revert:
	# revert everything before patching
	( \
		cd ${SRC_DIR} && \
		svn revert --depth=infinity . \
	)

do-patch:
	# patch file name must be prefix by patch-
	( \
		for F in `ls ${PATCH_DIR}/patch-* 2>/dev/null`; do \
			${PATCH} -t -d ${SRC_DIR} ${PATCH_FLAGS} < $${F}; \
		done; \
	)
	# clean up leftovers
	( \
		cd ${SRC_DIR}; \
		for F in `svn st | grep '^\?'|cut -f8 -d" " | grep 'orig$$'`; do \
			rm $${F}; \
		done; \
		for F in `svn st | grep '^\?'|cut -f8 -d" " | grep 'rej$$'`; do \
			rm $${F}; \
		done; \
	)

release:
	# you cannot override defaults by export these variables because release.sh
	# does not support environment variables. instead, replace variables in
	# RELEASE_CONF. this way, only single RELEASE_CONF can be used for all
	# TARGET.
	( \
		export MY_CHROOTDIR=${CHROOT_DIR}; \
		export MY_TARGET=${TARGET}; \
		export MY_TARGET_ARCH=${TARGET_ARCH}; \
		export MY_SRCBRANCH=base/${SRC_BRANCH}; \
		sh ${SRC_DIR}/release/release.sh -c ${RELEASE_CONF}; \
	)

publish: publish-patch
	# .iso images are not copied mostly due to disk space
	cp -a ${CHROOT_DIR}/R/ftp/* ${WWW_DIR}/

publish-patch:
	(cd ${SRC_DIR} && svn diff > ${WWW_DIR}/patch.txt)

makemtree:
	@(cd ${.CURDIR} && mtree -cdjn -k uname,gname,mode,nochange,link -p ${WWW_ROOT} > ${MTREE_FILE})
