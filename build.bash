#!/bin/bash

# BEGIN CONFIGURATION
BINUTILS_VERSION=2.22
GCC_VERSION=4.7.2
MPFR_VERSION=3.1.1
GMP_VERSION=5.0.4
MPC_VERSION=0.9
JOBS=4

export CFLAGS="-O2 -ggdb"
export CXXFLAGS="-O2 -ggdb"

# END CONFIGURATION

die() {
    echo "$@"
    exit 1
}

SEC_NUM=0

set_title () {
	case $TERM in
		xterm*|rxvt*|Eterm|aterm|kterm|gnome*|interix)
			echo -ne "\033]0;$1\007"
			;;
		screen)
			echo -ne "\033_$1\033\\"
			;;
		*)
			einfo "Unsupported terminal for title setting"
			;;
	esac
}

ebegin() {
	einfo "$1 ..."
	set_title "$1"
	((SEC_NUM=SEC_NUM+1))
}

eend() {
	((SEC_NUM=SEC_NUM-1))
	einfo "$1 [ok]"
}

einfo() {
	echo -ne "\033[1;30m>\033[0;36m>\033[1;36m> \033[0m${@}\n"
}

ewarn() {
	echo -ne "\033[1;30m>\033[0;33m>\033[1;33m> \033[0m${@}\n"
}

eerror() {
	echo -ne "\033[1;30m>\033[0;31m>\033[1;31m> ${@}\033[0m\n"
}

skip_has () {
	name="$1"

	[ -z "$SKIP" ] && return 1

	oIFS="$IFS"
	IFS=":"
	for s in $SKIP; do
		[ "$s" = "$name" ] && {
			IFS="$oIFS"
			return 0
		}
	done
	IFS="$oIFS"
	return 1
}

run () {
	if skip_has "$1"; then
		einfo "Skipping \"$1\""
		return 0;
	fi

	ebegin "building \"$1\""
	do_$1
	eend   "$1"
}

extract () {
	local PD="$1"
	local PF="$DIST/$PD"
	echo -n "ex $PD "
	case "$PD" in
	*.tar.bz2)
		tar -jxf "$PF" -C "$SRC"
		;;
	*.tar.gz)
		tar -zxf "$PF" -C "$SRC"
		;;
	*.zip)
		unzip -qo "$PF" -d "$SRC"
		;;
	*)
		die "Don't know how to extract $PF"
		;;
	esac
	[ $? -eq 0 ] || die "Could not extract \"$1\""
	echo "[ok]"
}

make_or_die() {
	make -C "$BUILD/$1" -j "$JOBS" || die "** $1 build failed"
	make -C "$BUILD/$1" -j "$JOBS" install || die "** $1 install failed"
}

download()
{
	dln="$(basename "$2")"
	(
	echo -n "dl $2 -> $1 "
	cd "$DIST"
	{
		[ -e "$dln" ] || wget -c "$2" || exit $?
		if [ "$dln" != "$1" ]; then
			[ -e "$dln" ] && rm -f "$1" && \
			ln "$dln" "$1" || exit 3
		fi
	} || die "[fail]"
	) || exit && echo "[ok]"
}

[ -e build.bash ] || cd $(dirname $0)
[ -e build.bash ] || die "Current working directory must be source directory"

RUNDIR=$(dirname "$0")

[ $# -gt 3 ] || die "usage: build.bash PREFIX DIST SRC BUILD [SKIPS]"
PREFIX="$1" # need an absolute here.
DIST="$2"
SRC="$3" # need an absolute here
BUILD="$4"
SKIP="${5:-}"
WIND_BASE="$PREFIX/powerpc-wrs-vxworks/wind_base"

mkdir -p $DIST
mkdir -p $SRC
mkdir -p $PREFIX
mkdir -p $BUILD
mkdir -p $WIND_BASE
mkdir -p $PREFIX/bin

# Must be absolute path as it is used in "conf", where we change directory.
export WIND_BASE=$(realpath "$WIND_BASE")
PREFIX=$(realpath "$PREFIX")
SRC=$(realpath "$SRC")

export PATH="$(realpath "$PREFIX/bin"):$PATH"

for d in gccdist binutils gcc libstdc++; do
	if ! skip_has "$d"; then
		df="$BUILD/$d"
		[ -d "$df" ] && rm -rf "$df"
		mkdir -p "$df"

		s="$SRC/$d"
		if [ -d "$s" ]; then
			rm -rf "$s"
		fi
	fi
done

conf ()
{
	PN="$1"
	(
	echo "$BUILD/$PN"
	cd "$BUILD/$PN" && eval "conf_$PN"
	) || die "conf of $PN failed"
}

conf_binutils ()
{
	"$SRC/binutils-$BINUTILS_VERSION/configure" \
		--prefix="$PREFIX" \
		--target=powerpc-wrs-vxworks \
		--disable-nls
}

do_binutils () {
	download "binutils-$BINUTILS_VERSION.tar.bz2" \
		"http://ftp.gnu.org/gnu/binutils/binutils-$BINUTILS_VERSION.tar.bz2"
	extract "binutils-$BINUTILS_VERSION.tar.bz2"
	conf binutils
	make_or_die binutils
}
run binutils

do_wrs_headers () {
	download "gccdist.zip" \
		"ftp://ftp.ni.com/pub/devzone/tut/updated_vxworks63gccdist.zip"
	extract gccdist.zip
	mkdir -p "$WIND_BASE/target"
	mkdir -p "$PREFIX/powerpc-wrs-vxworks/sys-include"
	mv $SRC/gccdist/WindRiver/vxworks-6.3/target/h $PREFIX/powerpc-wrs-vxworks/sys-include
	ln -s $PREFIX/powerpc-wrs-vxworks/sys-include/wrn/coreip $PREFIX/powerpc-wrs-vxworks/include
	cp -R "$SRC/gccdist/WindRiver/vxworks-6.3/host" "$WIND_BASE/host"
}
run wrs_headers

prep_gcc ()
{
	patch -l -d "$SRC/gcc-$GCC_VERSION" -p1 < fixinclude-skip-machine-name.patch || exit 1
	patch -l -d "$SRC/gcc-$GCC_VERSION" -p1 < fixinclude-assert.patch || exit 1
	patch -l -d "$SRC/gcc-$GCC_VERSION" -p1 < fixinclude-stdint.patch || exit 1
	patch -l -d "$SRC/gcc-$GCC_VERSION" -p1 < fixinclude-unistd.patch || exit 1
	patch -l -d "$SRC/gcc-$GCC_VERSION" -p1 < fixinclude-regs.patch || exit 1
	patch -l -d "$SRC/gcc-$GCC_VERSION" -p1 < fixinclude-ioctl.patch || exit 1
	patch -l -d "$SRC/gcc-$GCC_VERSION" -p1 < fixinclude-write.patch || exit 1
	patch -l -d "$SRC/gcc-$GCC_VERSION" -p1 < gcc-$GCC_VERSION.patch || exit 1
	patch -l -d "$SRC/gcc-$GCC_VERSION" -p1 < gcc-$GCC_VERSION-vxworks-libstdcxx.patch || exit 1
	patch -l -d "$SRC/gcc-$GCC_VERSION" -p1 < gcc-vxworks-libstdcxx-nominmax.patch || exit 1
	#( cd "$SRC/gcc-$GCC_VERSION" && ./contrib/download_prerequisites ) || exit
}

conf_gcc ()
{
	"$SRC/gcc-$GCC_VERSION/configure" \
	    --prefix="$PREFIX" \
	    --target=powerpc-wrs-vxworks \
	    --with-headers="$PREFIX/powerpc-wrs-vxworks/sys-include"
	    --with-gnu-as \
	    --with-gnu-ld \
	    --disable-shared \
	    --disable-libssp \
	    --disable-multilib \
	    --with-float=hard \
	    --enable-languages=c,c++ \
	    --enable-threads=vxworks \
	    --without-gconv \
	    --disable-libgomp \
	    --disable-nls \
	    --disable-libmudflap \
	    --with-cpu-PPC603
	cd "$SRC/gcc-$GCC_VERSION/fixincludes" && ./genfixes || exit 1
}

do_gcc () {
	download "gcc-$GCC_VERSION.tar.bz2" \
		"http://ftp.gnu.org/gnu/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.bz2"
	extract "gcc-$GCC_VERSION.tar.bz2"

	local OLD_DIRECTORY=$(pwd)
	cd $SRC/gcc-$GCC_VERSION
	./contrib/download_prerequisites
	cd $OLD_DIRECTORY

	prep_gcc
	export C_INCLUDE_PATH="$SRC/gcc-$GCC_VERSION/mpfr/src"
	export LD_LIBRARY_PATH="$BUILD/gcc/mpfr/src/.libs"
	export LIBRARY_PATH="$LD_LIBRARY_PATH"
	conf gcc
	make_or_die gcc
}
run gcc

do_custom_scripts () {
	cp munch.sh "$WIND_BASE"
	cp strip_syms.sh "$WIND_BASE" 
}
run custom_scripts
