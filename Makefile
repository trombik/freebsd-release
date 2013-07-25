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
# "make all" creates release ISO and FTP directories for all
# FreeBSD $RELEASE_MAJOR.$RELEASE_MINOR_VERSIONS
#
# SEE ALSO
#   http://www.freebsd.org/doc/en/articles/releng/index.html (outdated but still useful)
#   release(7)
#   /usr/src/release/Makefile
#   /usr/src/release/generate-release.sh
#
# TODO
# - test "upload" target
# - KERNCONF="GENERIC XENHVM"

RELEASE_DIR?=		release
RELEASE_MAJOR?=		9
RELEASE_MINOR?=	1
PATCH_DIR?=	patches
SYSCTL=			/sbin/sysctl
.if !defined(TARGET)
TARGET!=		uname -m
.endif
.if !defined(TARGET_ARCH)
TARGET_ARCH!=	uname -p
.endif
NCPU!=			${SYSCTL} -n hw.ncpu
MAKE_JOBS_NUMBER!=	echo ${NCPU} \* 2 | bc
LOCAL_PATCHES?=
PXE_HOST?=		pxe.dcjp02.reallyenglish.com
OBJDIR?=	obj
PUBLIC_WWWDIR?=	www

all:	patch generate_release ${PUBLIC_WWWDIR}

init:

generate_release:
	(cd ${.CURDIR} && mkdir -p ${RELEASE_DIR}/${RELEASE_MAJOR}.${RELEASE_MINOR}/${TARGET})
	(cd ${.CURDIR} && mkdir -p ${OBJDIR}/`realpath ${RELEASE_DIR}/${RELEASE_MAJOR}.${RELEASE_MINOR}/${TARGET}`/usr/src)
	(cd ${.CURDIR} && /usr/bin/env \
		MAKE_FLAGS="-j${MAKE_JOBS_NUMBER}" \
		TARGET=${TARGET} \
		TARGET_ARCH=${TARGET_ARCH} \
		MAKEOBJDIRPREFIX=`realpath ${OBJDIR}` \
		sh ${.CURDIR}/generate-release.sh releng/${RELEASE_MAJOR}.${RELEASE_MINOR} `realpath ${RELEASE_DIR}/${RELEASE_MAJOR}.${RELEASE_MINOR}/${TARGET}`)

makemtree:
	@(cd ${.CURDIR} && mtree -cind -k uname,gname,mode,nochange,link -p ${PUBLIC_WWWDIR} > ${PUBLIC_WWWDIR}.mtree)

${PUBLIC_WWWDIR}:
	(cd ${.CURDIR} && \
	install -o root -g wheel -m 0755 -d ${PUBLIC_WWWDIR} && \
	mtree -Ud -f  ${PUBLIC_WWWDIR}.mtree -p ${PUBLIC_WWWDIR} \
	)

# ISO images: powerpc/powerpc64/ISO-IMAGES/9.1/
# distfiles:  powerpc/powerpc64/9.1-RELEASE
publish:	makepatch
	(cd ${.CURDIR} && cp -a ${RELEASE_DIR}/${RELEASE_MAJOR}.${RELEASE_MINOR}/${TARGET}/R/ftp/* ${PUBLIC_WWWDIR}/pub/FreeBSD/releases/${TARGET}/${TARGET_ARCH}/${RELEASE_MAJOR}.${RELEASE_MINOR}-RELEASE/)
.for F in bootonly.iso memstick release.iso
	(cd ${.CURDIR} && cp -a ${RELEASE_DIR}/${RELEASE_MAJOR}.${RELEASE_MINOR}/${TARGET}/R/${F} ${PUBLIC_WWWDIR}/pub/FreeBSD/releases/${TARGET}/${TARGET_ARCH}/ISO-IMAGES/FreeBSD-${RELEASE_MAJOR}.${RELEASE_MINOR}-RELEASE-${TARGET_ARCH}-${F})
.endfor

patch:	revert do-patch

do-patch:
	( \
		cd ${.CURDIR} && \
		for F in ${PATCH_DIR}/patch-*; do \
			patch -t -d ${RELEASE_DIR}/${RELEASE_MAJOR}.${RELEASE_MINOR}/${TARGET}/usr/src < $${F}; \
		done; \
	)
revert:
	( \
		cd ${.CURDIR} && cd ${RELEASE_DIR}/${RELEASE_MAJOR}.${RELEASE_MINOR}/${TARGET}/usr/src && \
		svn revert --depth=infinity . \
	)

makepatch:
	(cd ${.CURDIR} && cd ${RELEASE_DIR}/${RELEASE_MAJOR}.${RELEASE_MINOR}/${TARGET}/usr/src && svn diff) | (cd ${.CURDIR} && cat - > ${PUBLIC_WWWDIR}/pub/FreeBSD/releases/${TARGET}/${TARGET_ARCH}/${RELEASE_MAJOR}.${RELEASE_MINOR}-RELEASE/patch-src.txt)

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
