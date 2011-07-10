#!/bin/bash

BINUTILS_VERSION=2.21
GCC_VERSION=4.5.2
MPFR_VERSION=3.0.1
GMP_VERSION=5.0.2
MPC_VERSION=0.8.2
PATCHROOT="$HOME/src/FIRST/gcc-patches"
PREFIX="$HOME/vxworks"
SRC="$HOME/src/FIRST/gcc-src"
BUILD="$HOME/src/FIRST/gcc-build"
JOBS=4

function download()
{
    [ -e "$SRC/$1" ] || wget -O "$SRC/$1" "$2"
}

function die()
{
    echo "$1"
    exit 1
}

export PATH="$PREFIX/bin:$PATH"
export WIND_BASE="$PREFIX/powerpc-wrs-vxworks/wind_base"

# Download
echo "Downloading..."
[ -d "$SRC" ] || mkdir "$SRC"
download "gccdist.zip" "ftp://ftp.ni.com/pub/devzone/tut/updated_vxworks63gccdist.zip"
download "binutils-$BINUTILS_VERSION.tar.bz2" "http://ftp.gnu.org/gnu/binutils/binutils-$BINUTILS_VERSION.tar.bz2"
download "gcc-$GCC_VERSION.tar.bz2" "http://ftp.gnu.org/gnu/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.bz2"
download "mpfr-$MPFR_VERSION.tar.bz2" "http://www.mpfr.org/mpfr-current/mpfr-$MPFR_VERSION.tar.bz2"
download "gmp-$GMP_VERSION.tar.bz2" "ftp://ftp.gmplib.org/pub/gmp-$GMP_VERSION/gmp-$GMP_VERSION.tar.bz2"
download "mpc-$MPC_VERSION.tar.gz" "http://www.multiprecision.org/mpc/download/mpc-$MPC_VERSION.tar.gz"

# Extract
echo "Extracting files (this will take a long time)..."
cd "$SRC"
echo "  gccdist.zip"
unzip -q gccdist.zip
echo "  binutils-$BINUTILS_VERSION.tar.bz2"
tar --bzip2 -xf "binutils-$BINUTILS_VERSION.tar.bz2"
echo "  gcc-$GCC_VERSION.tar.bz2"
tar --bzip2 -xf "gcc-$GCC_VERSION.tar.bz2"
echo "  mpfr-$MPFR_VERSION.tar.bz2"
tar --bzip2 -xf "mpfr-$MPFR_VERSION.tar.bz2"
echo "  gmp-$GMP_VERSION.tar.bz2"
tar --bzip2 -xf "gmp-$GMP_VERSION.tar.bz2"
echo "  mpc-$MPC_VERSION.tar.gz"
tar --gzip -xf "mpc-$MPC_VERSION.tar.gz"

# Patch!
echo "Patching..."
cd "$SRC/gccdist/WindRiver/vxworks-6.3/target/h"
sed "s:/usr/local/powerpc-wrs-vxworks:$(echo $PREFIX):" < "$PATCHROOT/vxworks-headers.patch" | patch -p1
cd "$SRC/gcc-$GCC_VERSION"
patch -p2 < "$PATCHROOT/gcc-diff.patch" # -p2 intentional.

# Set up headers
echo "Headers..."
[ -d "$PREFIX" ] || mkdir "$PREFIX"
mkdir -p "$WIND_BASE/target"
ln -s "$PREFIX/powerpc-wrs-vxworks/sys-include" "$WIND_BASE/target/h"
cp -R "$SRC/gccdist/WindRiver/vxworks-6.3/host" "$WIND_BASE/host" # must be a copy, because build adds more.

# Build
[ -d "$BUILD" ] || mkdir "$BUILD"
cd "$BUILD"
mkdir binutils gcc libstdc++

echo "binutils:"
cd "$BUILD/binutils"
"$SRC/binutils-$BINUTILS_VERSION/configure" --prefix="$PREFIX" --target=powerpc-wrs-vxworks
make -j "$JOBS" || die "** binutils build failed"
make -j "$JOBS" install || die "** binutils install failed"

echo "gcc:"
ln -s "$SRC/mpfr-$MPFR_VERSION" "$SRC/gcc-$GCC_VERSION/mpfr"
ln -s "$SRC/gmp-$GMP_VERSION" "$SRC/gcc-$GCC_VERSION/gmp"
ln -s "$SRC/mpc-$MPC_VERSION" "$SRC/gcc-$GCC_VERSION/mpc"
cd "$BUILD/gcc"
"$SRC/gcc-$GCC_VERSION/configure" \
    --prefix="$PREFIX" \
    --target=powerpc-wrs-vxworks \
    --with-gnu-as \
    --with-gnu-ld \
    --with-headers="$SRC/gccdist/WindRiver/vxworks-6.3/target/h" \
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
    --with-cpu-PPC603 \
    CFLAGS="-g -O2" \

# TODO: Document if necessary
make -j "$JOBS" || die "** gcc build failed"
make -j "$JOBS" install || die "** gcc install failed"


echo "libstdc++:"
cd "$BUILD/libstdc++"
"$SRC/gcc-$GCC_VERSION/libstdc++-v3/configure" \
    --host=powerpc-wrs-vxworks \
    --prefix="$PREFIX" \
    --enable-libstdcxx-debug \
    CFLAGS="-g -isystem $PREFIX/powerpc-wrs-vxworks/sys-include/ -isystem $PREFIX/powerpc-wrs-vxworks/sys-include/wrn/coreip/ -D_WRS_KERNEL -DCPU=PPC603 -DNOMINMAX" \
    CXXFLAGS="-isystem $PREFIX/powerpc-wrs-vxworks/sys-include/ -isystem $PREFIX/powerpc-wrs-vxworks/sys-include/wrn/coreip/ -D_WRS_KERNEL -DCPU=PPC603 -DNOMINMAX" \
    CPPFLAGS="-g -isystem $PREFIX/powerpc-wrs-vxworks/sys-include/ -isystem $PREFIX/powerpc-wrs-vxworks/sys-include/wrn/coreip/ -D_WRS_KERNEL -DCPU=PPC603 -DNOMINMAX"

make -j "$JOBS" || die "** libstdc++ build failed"
make -j "$JOBS" install || die "** libstdc++ install failed" 
