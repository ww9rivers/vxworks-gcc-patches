#!/bin/bash

# For now, run this as root so install works.  Not ideal, but it works...
# If someone wants to, getting GCC to stage everything would be a lot better, but I'm lazy
BINUTILS_VERSION=2.21
GCC_VERSION=4.5.2
MPFR_VERSION=3.0.1
GMP_VERSION=5.0.2
PREFIX=/usr/local/powerpc-wrs-vxworks

export PATH=$PATH:$PREFIX/bin

echo "Getting the vxworks header files."
[ -e updated_vxworks63gccdist.zip ] || wget ftp://ftp.ni.com/pub/devzone/tut/updated_vxworks63gccdist.zip
unzip updated_vxworks63gccdist.zip

echo "Patching the header files"
cd gccdist/WindRiver/vxworks-6.3/target/h/
ln -s vxWorks.h VxWorks.h
cat ../../../../../vxworks-headers.patch | sed "s/\/usr\/local\/powerpc-wrs-vxworks/`echo $PREFIX | sed 's/\\//\\\\\\//g'`/" | patch -p1

cd ../../../../../

mkdir -p $PREFIX/powerpc-wrs-vxworks/wind_base
mkdir $PREFIX/powerpc-wrs-vxworks/wind_base/target
ln -s ../../sys-include/ $PREFIX/powerpc-wrs-vxworks/wind_base/target/h
cp -rp gccdist/WindRiver/vxworks-6.3/host $PREFIX/powerpc-wrs-vxworks/wind_base/host

echo "Building binutils"
[ -e http://ftp.gnu.org/gnu/binutils/binutils-$BINUTILS_VERSION.tar.bz2 ] || wget http://ftp.gnu.org/gnu/binutils/binutils-$BINUTILS_VERSION.tar.bz2
echo "Extracting binutils-2.21.tar.bz2"
tar xjf binutils-2.21.tar.bz2
mkdir binutils-2.21-build-x64
cd binutils-2.21-build-x64
../binutils-2.21/configure --prefix=$PREFIX --target=powerpc-wrs-vxworks
make -j32
make install -j2
cd ..

echo "Building gcc"
[ -e http://ftp.gnu.org/gnu/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.bz2 ] || wget http://ftp.gnu.org/gnu/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.bz2
echo "Extracting gcc-$GCC_VERSION.tar.bz2"
tar xjf gcc-$GCC_VERSION.tar.bz2
[ -e wget http://www.mpfr.org/mpfr-current/mpfr-$MPFR_VERSION.tar.bz2 ] || wget http://www.mpfr.org/mpfr-current/mpfr-$MPFR_VERSION.tar.bz2 
echo "Extracting mpfr-$MPFR_VERSION.tar.bz2"
tar xjf mpfr-$MPFR_VERSION.tar.bz2
[ -e wget ftp://ftp.gmplib.org/pub/gmp-$GMP_VERSION/gmp-$GMP_VERSION.tar.bz2] || wget ftp://ftp.gmplib.org/pub/gmp-$GMP_VERSION/gmp-$GMP_VERSION.tar.bz2
echo "Extracting gmp-$GMP_VERSION.tar.bz2"
tar xjf gmp-$GMP_VERSION.tar.bz2
cd gcc-$GCC_VERSION
ln -s ../mpfr-$MPFR_VERSION mpfr
ln -s ../gmp-$GMP_VERSION gmp
cd ..

cat gcc-diff.patch | patch -p1

mkdir gcc-$GCC_VERSION-build-x64
cd gcc-$GCC_VERSION-build-x64

../gcc-$GCC_VERSION/configure --prefix=$PREFIX --target=powerpc-wrs-vxworks --with-gnu-as --with-gnu-ld --with-headers=../gccdist/WindRiver/vxworks-6.3/target/h --disable-shared --disable-libssp CFLAGS='-D_WRS_KERNEL -g -O2' --disable-multilib --with-float=hard --enable-languages=c,c++ --enable-threads=vxworks --without-gconv --disable-libgomp --disable-nls --disable-libmudflap --with-cpu-PPC603
export WIND_BASE=$PREFIX/powerpc-wrs-vxworks/wind_base/

# Build gcc propper
make all-gcc -j32
make install-gcc -j2

# Make the library
make -j32
make install -j2
cd ..

echo "Building the stdlib"
mkdir libstdc++-v3-build-x64
cd libstdc++-v3-build-x64

../gcc-$GCC_VERSION/libstdc++-v3/configure --host=powerpc-wrs-vxworks --prefix=$PREFIX/ CFLAGS="-g -isystem $PREFIX/powerpc-wrs-vxworks/sys-include/ -isystem $PREFIX/powerpc-wrs-vxworks/sys-include/wrn/coreip/ -D_WRS_KERNEL -DCPU=PPC603 -DNOMINMAX" CXXFLAGS="-isystem $PREFIX/powerpc-wrs-vxworks/sys-include/ -isystem $PREFIX/powerpc-wrs-vxworks/sys-include/wrn/coreip/ -D_WRS_KERNEL -DCPU=PPC603 -DNOMINMAX" CCFLAGS="-g -isystem $PREFIX/powerpc-wrs-vxworks/sys-include/wrn/coreip/ -isystem $PREFIX/powerpc-wrs-vxworks/sys-include/ -D_WRS_KERNEL -DCPU=PPC603 -DNOMINMAX" CPPFLAGS="-g -isystem $PREFIX/powerpc-wrs-vxworks/sys-include/ -isystem $PREFIX/powerpc-wrs-vxworks/sys-include/wrn/coreip/ -D_WRS_KERNEL -DCPU=PPC603 -DNOMINMAX" --enable-libstdcxx-debug
make -j32
make install -j2
