HOST=$ARCH-w64-mingw32
PREFIX=$PWD/$HOST

export MINGW_ROOT=$PWD/$(find llvm-mingw* -type d | head -n 1)
export PATH=$PATH:$MINGW_ROOT/bin:$PREFIX/bin
export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:$PREFIX/lib/pkgconfig

export CFLAGS="-O2 -I$PREFIX/include"
export LDFLAGS="-L$PREFIX/lib"
export CXXFLAGS=$CFLAGS
export CPPFLAGS=$CFLAGS

echo Building for $HOST

# For some reason MinGW ARM is missing serveral libs compared to x86
# Build lib for $ARCH from i686 version
# $1 : The lib filename, in MinGW convention
#      xyz.dll -> libxyz.a
function build_lib() {
    if [ $ARCH == "i686" ] || [ $ARCH == 'x86_64' ]; then return; fi
    LIBFILE=$1
    MODULE=$(echo $LIBFILE | sed 's/lib\(.*\?\)\.a/\1/g')
    DLLFILE=$(echo $MODULE | tr '/a-z/' '/A-Z/').dll
    (
        echo LIBRARY $DLLFILE
        echo EXPORTS
        $HOST-nm $MINGW_ROOT/i686-w64-mingw32/lib/$LIBFILE --just-symbol-name |
            sed '/^$/d' | sed "/^$DLLFILE/d" | sed '/\.idata/d' | sed '/__imp/d' | sed '/__NULL_IMPORT/d' |
            sed '/_NULL_THUNK_DATA/d' | sed '/__IMPORT_DESCRIPTOR/d' | sed 's/@.*$//g' | sed 's/^_//g'
    ) > $MODULE.def
    $HOST-dlltool -d $MODULE.def -l $MINGW_ROOT/$HOST/lib/$LIBFILE
}

build_lib "libpowrprof.a"
build_lib "libsetupapi.a"

# zlib
pushd $(find zlib-* -type d | head -n 1)
make -j $(nproc) -f win32/Makefile.gcc PREFIX=$HOST- || exit 1
make -f win32/Makefile.gcc install SHARED_MODE=1 \
     BINARY_PATH=$PREFIX/bin \
     INCLUDE_PATH=$PREFIX/include \
     LIBRARY_PATH=$PREFIX/lib || exit 1
popd

# Ghostscript headers
pushd $(find ghostscript-* -type d | head -n 1)
mkdir $PREFIX/include/ghostscript
cp psi/iapi.h psi/ierrors.h base/gserrors.h $PREFIX/include/ghostscript/
popd

# Winpcap headers
pushd WpdPack/Include
cp -R *.* $PREFIX/include
popd

# libpng
pushd $(find libpng-* -type d | head -n 1)
./configure --prefix=$PREFIX --host=$HOST || exit 1
make -j $(nproc) || exit 1
make install     || exit 1
popd

# SDL2
pushd $(find SDL2-* -type d | head -n 1)
patch -p1 < ../patches/sdl2-fix-arm-build.patch
aclocal
autoconf
./configure --prefix=$PREFIX --host=$HOST --disable-video-opengl || exit 1
make -j $(nproc) || exit 1
make install     || exit 1
popd

# openal-soft
pushd $(find openal-soft-* -type d | head -n 1)
patch -p1 < ../patches/openal-assume-neon-on-windows-arm.patch
sed -i "s/\/usr\/\${HOST}/$(echo $PREFIX | sed 's/\//\\\//g')/g" XCompile.txt
cmake . -DCMAKE_TOOLCHAIN_FILE=XCompile.txt -DHOST=$HOST \
        -DDSOUND_LIBRARY=$MINGW_ROOT/$HOST/lib \
        -DDSOUND_INCLUDE_DIR=$MINGW_ROOT/$HOST/include || exit 1
make -j $(nproc) || exit 1
make install     || exit 1
pushd $PREFIX/lib
ln -s libOpenAL32.dll.a libopenal.a
popd
popd

# freetype
pushd $(find freetype-* -type d | head -n 1)
./configure --prefix=$PREFIX --host=$HOST || exit 1
make -j $(nproc) || exit 1
make install     || exit 1
popd

# 86Box
pushd 86Box
for p in ../patches/86Box/*.patch; do patch -p1 < "$p"; done
cd src
if [ $ARCH == "i686"    ]; then 86BOX_ARGS=""                 ; fi
if [ $ARCH == "x86_64"  ]; then 86BOX_ARGS="X64=y"            ; fi
if [ $ARCH == "armv7"   ]; then 86BOX_ARGS="ARM=y   XINPUT=y" ; fi
if [ $ARCH == "aarch64" ]; then 86BOX_ARGS="ARM64=y XINPUT=y" ; fi
make -f win/Makefile_ndr.mingw $86BOX_ARGS -j $(nproc)
cp 86Box.exe pcap_if.exe $PREFIX/bin
popd

find $PREFIX/bin
