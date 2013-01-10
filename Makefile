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
# to initilize, "make init".
#
# * create all directories
# * checkout all sources
#
# "make all" creates release ISO and FTP directories for all
# FreeBSD $RELEASE_MAJOR.$RELEASE_MINOR_VERSIONS
#
# "make update-stable release-stable" creates one for -STABLE
#
# SEE ALSO
#   http://www.freebsd.org/doc/en/articles/releng/index.html (outdated but still useful)
#   release(7)
#   /usr/src/release/Makefile
#   /usr/src/release/generate-release.sh
#
# TODO
# - support cross-build
# - support branched portstree

RELEASE_DIR?=		/usr/home/release
CHROOT_DIR?=		${RELEASE_DIR}/chroot
RELEASE_MAJOR?=		9
RELEASE_MINOR_VERSIONS?=	1
SVNROOT?=		svn://svn.freebsd.org/base
PORTSDIR?=		/usr/ports
SYSCTL=			/sbin/sysctl
ARCH!=			uname -m
NCPU!=			${SYSCTL} -n hw.ncpu
MAKE_JOBS_NUMBER!=	echo ${NCPU} \* 2 | bc
LOCAL_PATCHES?=
PATCH_FLAGS?=
PXE_HOST?=		pxe.dcjp02.reallyenglish.com

.if defined(DEBUG)
SVN_FLAGS=
GIT_FLAGS=
.else
SVN_FLAGS=	--quiet
GIT_FLAGS=	--quiet
.endif

GIT!=			which git
SVN!=			which svn
.if !defined(GIT)
	@echo "git not found in PATH." 1>&2
	@echo "please install devel/git" 1>&2 && exit 1
.endif
.if !defined(SVN)
	@echo "svn not found in PATH." 1>&2
	@echo "please install devel/subversion" 1>&2 && exit 1
.endif

# git is used as it's much easier to fork repos. i.e. creating your own
# portstree. also, use git:// which is faster than https://
# XXX for now, the official github repository is used. but we should fork it to
# github.com/reallyenglish.
PORTS_GIT_URL=		git://github.com/freebsd/freebsd-ports.git

# release the latest RELEASE branches.
# to release -STABLE, "make update-stable release-stable"
all:	update release

# let's make release faster
#
# * use local ports (PORTSDIR)
# * use multiple cores (-j)
# * do not build doc (NODOC)
release:
.for V in ${RELEASE_MINOR_VERSIONS}
	${INSTALL} -d ${CHROOT_DIR}/releng/${RELEASE_MAJOR}.${V}
	make -C ${RELEASE_DIR}/sources/releng/${RELEASE_MAJOR}.${V}/src \
		-j${MAKE_JOBS_NUMBER} \
		buildworld buildkernel
	make -C ${RELEASE_DIR}/sources/releng/${RELEASE_MAJOR}.${V}/src/release \
		clean
	make -C ${RELEASE_DIR}/sources/releng/${RELEASE_MAJOR}.${V}/src/release \
		release \
		PORTSDIR=${PORTSDIR} \
		NODOC=y
.endfor

release-stable:
	${INSTALL} -d ${CHROOT_DIR}/stable/${RELEASE_MAJOR}
	make -C ${RELEASE_DIR}/sources/stable/${RELEASE_MAJOR}/src \
		-j${MAKE_JOBS_NUMBER} \
		buildworld buildkernel
	make -C ${RELEASE_DIR}/sources/releng/${RELEASE_MAJOR}.${V}/src/release \
		clean
	make -C ${RELEASE_DIR}/sources/stable/${RELEASE_MAJOR}/src/release \
		-j ${MAKE_JOBS_NUMBER} \
		release \
		PORTSDIR=${PORTSDIR} \
		NODOC=y

init:	create-dirs checkout checkout-stable checkout-head

create-dirs:
	${INSTALL} -d ${RELEASE_DIR}/sources
	${INSTALL} -d ${RELEASE_DIR}/sources/releng
	${INSTALL} -d ${RELEASE_DIR}/sources/stable
	${INSTALL} -d ${RELEASE_DIR}/portstrees
	${INSTALL} -d ${RELEASE_DIR}/chroot
	${INSTALL} -d ${RELEASE_DIR}/conf
	${INSTALL} -d ${RELEASE_DIR}/conf/boot

checkout:
.for V in ${RELEASE_MINOR_VERSIONS}
	${INSTALL} -d ${RELEASE_DIR}/sources/releng/${RELEASE_MAJOR}.${V}
	(cd ${RELEASE_DIR}/sources/releng/${RELEASE_MAJOR}.${V} && \
		${SVN} checkout ${SVN_FLAGS} \
		${SVNROOT}/releng/${RELEASE_MAJOR}.${V} src)
.endfor

checkout-stable:
	${INSTALL} -d ${RELEASE_DIR}/sources/stable/${RELEASE_MAJOR}
	(cd ${RELEASE_DIR}/sources/stable/${RELEASE_MAJOR} && \
		${SVN} checkout ${SVN_FLAGS} \
		${SVNROOT}/stable/${RELEASE_MAJOR} src)

update:
.for V in ${RELEASE_MINOR_VERSIONS}
	if [ -d ${RELEASE_DIR}/sources/releng/${RELEASE_MAJOR}.${V}/src ]; then \
		(cd ${RELEASE_DIR}/sources/releng/${RELEASE_MAJOR}.${V}/src && \
			${SVN} ${SVN_FLAGS} update); \
	else \
		echo "please make checkout first" 1>&2 && exit 1; \
	fi
.endfor

update-stable:
	if [ -d ${RELEASE_DIR}/sources/stable/${RELEASE_MAJOR}/src ]; then \
		(cd ${RELEASE_DIR}/sources/stable/${RELEASE_MAJOR}/src && \
			${SVN} ${SVN_FLAGS} update); \
	else \
		echo "please make checkout-stable first" 1>&2 && exit 1; \
	fi

clone-ports:
	(cd ${RELEASE_DIR}/portstrees && \
		${GIT} clone ${GIT_FLAGS} ${PORTS_GIT_URL} freebsd-ports)

pull-ports:
	if [ -d ${RELEASE_DIR}/portstrees/freebsd-ports ]; then \
		(cd ${RELEASE_DIR}/portstrees/freebsd-ports && \
			${GIT} pull ${GIT_FLAGS}); \
	else \
		echo "please make clone-ports first" 1>&2 && exit 1; \
	fi

# two targets to get HEAD sources.
# no release-head target because we don't need it.
# also, building HEAD on non-HEAD is not supported.
# use snapshot or build HEAD on your own host.
checkout-head:
	(cd ${RELEASE_DIR}/sources && \
		${SVN} checkout ${SVN_FLAGS} ${SVNROOT}/head head)

update-head:
	(cd ${RELEASE_DIR}/sources/head && ${SVN} ${SVN_FLAGS} update)

upload:
.for V in ${RELEASE_MINOR_VERSIONS}
	# XXX [KNOWN BUG] gzipped mfsroot doesn't work
	if [ -f ${RELEASE_DIR}/chroot/releng/${RELEASE_MAJOR}.${V}/R/cdrom/disc1/boot/mfsroot.gz ]; then \
		gunzip ${RELEASE_DIR}/chroot/releng/${RELEASE_MAJOR}.${V}/R/cdrom/disc1/boot/mfsroot.gz ; \
	fi
	ssh ${PXE_HOST} \
		rm -rf /tftproot/pub/FreeBSD/${ARCH}/${RELEASE_MAJOR}.${V}-RELEASE
	scp -r \
		${RELEASE_DIR}/chroot/releng/${RELEASE_MAJOR}.${V}/R/cdrom/disc1 \
		${PXE_HOST}:/tftproot/pub/FreeBSD/${ARCH}/${RELEASE_MAJOR}.${V}-RELEASE
	# copy loader.conf and beastie.4th (with "PXEBOOT" in the menu) for pxeboot
	scp ${RELEASE_DIR}/conf/boot/* \
		${PXE_HOST}:/tftproot/pub/FreeBSD/${ARCH}/${RELEASE_MAJOR}.${V}-RELEASE/boot/
.endfor
