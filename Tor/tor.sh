#!/bin/bash

ARCHS=($ARCHS)

# We need gettext to build tor
# This extends the path to look in some common locations (for example, if installed via Homebrew)
PATH=$PATH:/usr/local/bin:/usr/local/opt/gettext/bin:/usr/local/opt/automake/bin:/usr/local/opt/aclocal/bin

# Generate the configure script (necessary for version control distributions)
if [[ ! -f ./configure ]]; then
    ./autogen.sh --add-missing
fi

REBUILD=0

declare -a LIBS=(`make show-libs`)
echo "LIBRARIES: ${LIBS[@]}"

# If the built binaries include a different set of architectures, then rebuild the target
if [[ ${ACTION:-build} = "build" ]] || [[ $ACTION = "install" ]]; then
    for LIB in ${LIBS[@]}
    do
        for ARCH in ${ARCHS[@]}
        do
            if [[ $(lipo -info "${BUILT_PRODUCTS_DIR}/$(basename $LIB)" 2>&1) != *"${ARCH}"* ]]; then
                REBUILD=1;
            fi
        done
    done
fi

# If rebuilding or cleaning then delete the built products
if [[ ${ACTION:-build} = "clean" ]] || [[ $REBUILD = 1 ]]; then
    make clean 2>/dev/null
    for LIB in ${LIBS[@]}
    do
        rm "${BUILT_PRODUCTS_DIR}/$(basename $LIB)" 2> /dev/null
    done
fi

if [[ $REBUILD = 0 ]]; then
    exit;
fi

# Disable PT_DENY_ATTACH because it is private API
PSEUDO_SYS_INCLUDE_DIR="${CONFIGURATION_TEMP_DIR}/tor-sys"
mkdir -p "${PSEUDO_SYS_INCLUDE_DIR}/sys"
touch "${PSEUDO_SYS_INCLUDE_DIR}/sys/ptrace.h"

if [[ "${BITCODE_GENERATION_MODE}" = "bitcode" ]]; then
    BITCODE_CFLAGS="-fembed-bitcode"
elif [[ "${BITCODE_GENERATION_MODE}" = "marker" ]]; then
    BITCODE_CFLAGS="-fembed-bitcode-marker"
fi

if [[ "${CONFIGURATION}" = "Debug" ]]; then
    DEBUG_CFLAGS="-g -O0"
fi

mkdir -p "${BUILT_PRODUCTS_DIR}"

# Build each architecture one by one using clang
for ARCH in ${ARCHS[@]}
do
    make clean

    ./configure --enable-restart-debugging --enable-silent-rules --enable-pic --disable-module-dirauth --disable-tool-name-check --disable-unittests --enable-static-openssl --enable-static-libevent --disable-asciidoc --disable-system-torrc --disable-linker-hardening --disable-dependency-tracking --disable-manpage --disable-html-manual --prefix="${CONFIGURATION_TEMP_DIR}/tor-${ARCH}" --with-libevent-dir="${BUILT_PRODUCTS_DIR}" --with-openssl-dir="${BUILT_PRODUCTS_DIR}" --enable-lzma --enable-zstd=no CC="$(xcrun -f --sdk ${PLATFORM_NAME} clang) -arch ${ARCH} -isysroot ${SDKROOT}" CPP="$(xcrun -f --sdk ${PLATFORM_NAME} clang) -E -arch ${ARCH} -isysroot ${SDKROOT}" CPPFLAGS="${DEBUG_CFLAGS} ${BITCODE_CFLAGS} -I${SRCROOT}/Tor/tor/core -I${SRCROOT}/Tor/openssl/include -I${BUILT_PRODUCTS_DIR}/openssl-${ARCH} -I${SRCROOT}/Tor/libevent/include -I${BUILT_PRODUCTS_DIR}/libevent-${ARCH} -I${BUILT_PRODUCTS_DIR}/libevent-${ARCH}/include -I${BUILT_PRODUCTS_DIR}/liblzma-${ARCH} -I${BUILT_PRODUCTS_DIR}/liblzma-${ARCH}/include -I${PSEUDO_SYS_INCLUDE_DIR} -isysroot ${SDKROOT}" cross_compiling="yes" ac_cv_func__NSGetEnviron="no" ac_cv_func_clock_gettime="no" ac_cv_func_getentropy="no" LDFLAGS="-lz ${BITCODE_CFLAGS}"

    # There seems to be a race condition with the above configure and the later cp.
    # Just sleep a little so the correct file is copied and delete the old one before.
    sleep 2s
    rm src/lib/cc/orconfig.h

    cp orconfig.h "src/lib/cc/"

    make -j$(sysctl hw.ncpu | awk '{print $2}')

    cp micro-revision.i "${BUILT_PRODUCTS_DIR}/micro-revision.i"

    for LIB in ${LIBS[@]}
    do
        cp $LIB "${BUILT_PRODUCTS_DIR}/$(basename $LIB).${ARCH}.a"
    done
    make clean
done

# Combine the built products into a fat binary
for LIB in ${LIBS[@]}
do
    FILENAME=$(basename $LIB)

    xcrun --sdk $PLATFORM_NAME lipo -create "${BUILT_PRODUCTS_DIR}/$FILENAME."*.a -output "${BUILT_PRODUCTS_DIR}/$FILENAME"
    rm "${BUILT_PRODUCTS_DIR}/$FILENAME."*.a
done
