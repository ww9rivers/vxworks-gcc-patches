#!/bin/bash

# BEGIN CONFIGURATION
BINUTILS_VERSION=2.22
GCC_VERSION=4.6.3
MPFR_VERSION=3.1.0
GMP_VERSION=5.0.2
MPC_VERSION=0.9
JOBS=4
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

[ $# -eq 4 ] || [ $# -eq 5 ] || die "usage: build.bash PREFIX DIST SRC BUILD [SKIPS]"
PREFIX="$(realpath -m "$1")" # need an absolute here.
DIST="$2"
SRC="$(realpath -m "$3")"
BUILD="$4"
SKIP="${5:-}"

# Must be absolute path as it is used in "conf", where we change directory.
export WIND_BASE=$(realpath -m "$SRC/gccdist/WindRiver/vxworks-6.3")

export PATH="$(realpath -m "$PREFIX/bin"):$PATH"

[ -d "$DIST"   ] || mkdir "$DIST"   || exit
[ -d "$SRC"    ] || mkdir "$SRC"    || exit
[ -d "$PREFIX" ] || mkdir "$PREFIX" || exit
[ -d "$BUILD"  ] || mkdir "$BUILD"  || exit
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
	SAFE_PN="${1//+/x}"
	(
	echo "$BUILD/$PN"
	cd "$BUILD/$PN" && eval "conf_$SAFE_PN"
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
	patch -d "$SRC/gccdist" -p1 <  wrs_headers-vxtypes.patch || exit
}
run wrs_headers

prep_gcc ()
{
	patch -d "$SRC/gcc-$GCC_VERSION" -p1 < "gcc.patch" || exit 1
	patch -d "$SRC/gcc-$GCC_VERSION" -p1 < "gcc-4.6.2-vxworks-libstdcxx.patch" || exit 1
	patch -d "$SRC/gcc-$GCC_VERSION" -p1 < gcc-vxworks-libstdcxx-nominmax.patch || exit 1
	#( cd "$SRC/gcc-$GCC_VERSION" && ./contrib/download_prerequisites ) || exit
}

conf_gcc ()
{
	"$SRC/gcc-$GCC_VERSION/configure" \
	    --prefix="$PREFIX" \
	    --target=powerpc-wrs-vxworks \
	    --with-gnu-as \
	    --with-gnu-ld \
	    --with-headers="$WIND_BASE/target/h" \
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
}

do_gcc () {
	download "gcc-$GCC_VERSION.tar.bz2" \
		"http://ftp.gnu.org/gnu/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.bz2"
	download "mpfr-$MPFR_VERSION.tar.bz2" \
		"http://www.mpfr.org/mpfr-current/mpfr-$MPFR_VERSION.tar.bz2"
	download "gmp-$GMP_VERSION.tar.bz2" \
		"ftp://ftp.gmplib.org/pub/gmp-$GMP_VERSION/gmp-$GMP_VERSION.tar.bz2"
	download "mpc-$MPC_VERSION.tar.gz" \
		"http://www.multiprecision.org/mpc/download/mpc-$MPC_VERSION.tar.gz"
	extract "mpfr-$MPFR_VERSION.tar.bz2"
	extract "gmp-$GMP_VERSION.tar.bz2"
	extract "mpc-$MPC_VERSION.tar.gz"
	extract "gcc-$GCC_VERSION.tar.bz2"

	ln -s "$SRC/mpfr-$MPFR_VERSION" "$SRC/gcc-$GCC_VERSION/mpfr"
	ln -s "$SRC/gmp-$GMP_VERSION"   "$SRC/gcc-$GCC_VERSION/gmp"
	ln -s "$SRC/mpc-$MPC_VERSION"   "$SRC/gcc-$GCC_VERSION/mpc"

	prep_gcc
	conf gcc
	make_or_die gcc
}
run gcc

conf_libstdcxx ()
{
	CPPFLAGS="-DNOMINMAX" CFLAGS="-DNOMINMAX" CXXFLAGS="-DNOMINMAX" \
		"../../$SRC/gcc-$GCC_VERSION/libstdc++-v3/configure" \
		--host=powerpc-wrs-vxworks \
		--prefix="$PREFIX" \
		--enable-libstdcxx-debug \

	#	CFLAGS="-g -isystem $PREFIX/powerpc-wrs-vxworks/sys-include/ -isystem $PREFIX/powerpc-wrs-vxworks/sys-include/wrn/coreip/ -D_WRS_KERNEL -DCPU=PPC603 -DNOMINMAX" \
	#	CXXFLAGS="-isystem $PREFIX/powerpc-wrs-vxworks/sys-include/ -isystem $PREFIX/powerpc-wrs-vxworks/sys-include/wrn/coreip/ -D_WRS_KERNEL -DCPU=PPC603 -DNOMINMAX" \
	#	CPPFLAGS="-g -isystem $PREFIX/powerpc-wrs-vxworks/sys-include/ -isystem $PREFIX/powerpc-wrs-vxworks/sys-include/wrn/coreip/ -D_WRS_KERNEL -DCPU=PPC603 -DNOMINMAX"
}

do_libstdcxx () {
	conf libstdc++
	make_or_die libstdc++
}

run libstdcxx
