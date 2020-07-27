
export HOST=$ARCH-w64-mingw32
export MINGW_ROOT=/opt/$(find llvm-mingw* -maxdepth 1 -type d | head -n 1)
export PREFIX=/opt/$HOST
export PATH=$PATH:$MINGW_ROOT/bin:$PREFIX/bin
export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:$PREFIX/lib/pkgconfig

echo Building for $HOST

# Winpcap headers
pushd WpdPack/Include
sudo cp -R * $PREFIX/include
popd

# 86Box
export CFLAGS="-I$PREFIX/include"
export LDFLAGS="-L$PREFIX/lib"
export CXXFLAGS=$CFLAGS
export CPPFLAGS=$CFLAGS

pushd 86box
for p in ../patches/86box-*.patch; do patch -p1 < "$p"; done
cd src

# Old Dynarec
if [ $ARCH == "i686"    ]; then PLAT="DYNAREC=y"         ; fi
if [ $ARCH == "x86_64"  ]; then PLAT="X64=y DYNAREC=y"   ; fi
if [ $ARCH == "armv7"   ]; then PLAT="ARM=y DYNAREC=n"   ; fi
if [ $ARCH == "aarch64" ]; then PLAT="ARM64=y DYNAREC=n" ; fi
ARGS="$PLAT DINPUT=n WINDRES=$HOST-windres STRIP=$HOST-strip"
make -f win/Makefile.mingw $ARGS -j $(nproc) || exit 1
cp 86Box.exe 86Box_oldyn.exe
make -f win/Makefile.mingw clean

if [ $ARCH == "i686"    ]; then PLAT=""        ; fi
if [ $ARCH == "x86_64"  ]; then PLAT="X64=y"   ; fi
if [ $ARCH == "armv7"   ]; then PLAT="ARM=y"   ; fi
if [ $ARCH == "aarch64" ]; then PLAT="ARM64=y" ; fi
ARGS="$PLAT NEW_DYNAREC=y DYNAREC=y DINPUT=n WINDRES=$HOST-windres STRIP=$HOST-strip"
make -f win/Makefile.mingw $ARGS -j $(nproc) || exit 1
popd

BIN="86box/src/86Box.exe                \
     86box/src/86Box_oldyn.exe          \
     86box/src/pcap_if.exe              \
     $PREFIX/bin/OpenAL32.dll           \
     $PREFIX/bin/libfreetype-6.dll      \
     $PREFIX/bin/SDL2.dll               \
     $PREFIX/bin/libpng16-16.dll        \
     $PREFIX/bin/zlib1.dll              \
     $MINGW_ROOT/$HOST/bin/libc++.dll   \
     $MINGW_ROOT/$HOST/bin/libunwind.dll"

mkdir output
cp $BIN output

pushd output
mv libfreetype-6.dll freetype.dll
zip ../86Box.zip *
popd
