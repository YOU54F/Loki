#!/bin/bash

set -eu

declare -r revision="$(git rev-parse --short HEAD)"

declare -r gmp_tarball='/tmp/gmp.tar.xz'
declare -r gmp_directory='/tmp/gmp-6.2.1'

declare -r mpfr_tarball='/tmp/mpfr.tar.xz'
declare -r mpfr_directory='/tmp/mpfr-4.2.0'

declare -r mpc_tarball='/tmp/mpc.tar.gz'
declare -r mpc_directory='/tmp/mpc-1.3.1'

declare -r binutils_tarball='/tmp/binutils.tar.xz'
declare -r binutils_directory='/tmp/binutils-2.40'

declare -r gcc_tarball='/tmp/gcc.tar.gz'
declare -r gcc_directory='/tmp/gcc-13.2.0'

declare -r optflags='-Os'
declare -r linkflags='-Wl,-s'

if [ "$(uname -s)" == 'Darwin' ]; then
	declare -r max_jobs="$(($(sysctl -n hw.ncpu) * 8))"
else
	declare -r max_jobs="$(($(nproc) * 12))"
fi
declare build_type="${1}"

if [ -z "${build_type}" ]; then
	build_type='native'
fi

declare is_native='0'

if [ "${build_type}" == 'native' ]; then
	is_native='1'
fi

if [ "$(uname -s)" != 'Darwin' ]; then
	declare OBGGCC_TOOLCHAIN='/tmp/obggcc-toolchain'
fi

declare CROSS_COMPILE_TRIPLET=''

declare cross_compile_flags=''

if ! (( is_native )); then
	if [ "$(uname -s)" != 'Darwin' ]; then
		source "./submodules/obggcc/toolchains/${build_type}.sh"
	fi
	cross_compile_flags+="--host=${CROSS_COMPILE_TRIPLET} "
fi

if ! [ -f "${gmp_tarball}" ]; then
	wget --no-verbose 'https://ftp.gnu.org/gnu/gmp/gmp-6.2.1.tar.xz' --output-document="${gmp_tarball}"
	tar --directory="$(dirname "${gmp_directory}")" --extract --file="${gmp_tarball}"
fi

if ! [ -f "${mpfr_tarball}" ]; then
	wget --no-verbose 'https://ftp.gnu.org/gnu/mpfr/mpfr-4.2.0.tar.xz' --output-document="${mpfr_tarball}"
	tar --directory="$(dirname "${mpfr_directory}")" --extract --file="${mpfr_tarball}"
fi

if ! [ -f "${mpc_tarball}" ]; then
	wget --no-verbose 'https://ftp.gnu.org/gnu/mpc/mpc-1.3.1.tar.gz' --output-document="${mpc_tarball}"
	tar --directory="$(dirname "${mpc_directory}")" --extract --file="${mpc_tarball}"
fi

if ! [ -f "${binutils_tarball}" ]; then
	wget --no-verbose 'https://ftp.gnu.org/gnu/binutils/binutils-2.40.tar.xz' --output-document="${binutils_tarball}"
	tar --directory="$(dirname "${binutils_directory}")" --extract --file="${binutils_tarball}"
fi

if ! [ -f "${gcc_tarball}" ]; then
	wget --no-verbose 'https://mirrors.kernel.org/gnu/gcc/gcc-13.2.0/gcc-13.2.0.tar.xz' --output-document="${gcc_tarball}"
	tar --directory="$(dirname "${gcc_directory}")" --extract --file="${gcc_tarball}"
fi

[ -d "${gcc_directory}/build" ] || mkdir "${gcc_directory}/build"

declare -r toolchain_directory="/tmp/loki"
cp binutils-apple-silicon.patch /tmp

[ -d "${gmp_directory}/build" ] || mkdir "${gmp_directory}/build"

cd "${gmp_directory}/build"

../configure \
	--prefix="${toolchain_directory}" \
	--enable-shared \
	--enable-static \
	${cross_compile_flags} \
	CFLAGS="${optflags}" \
	CXXFLAGS="${optflags}" \
	LDFLAGS="${linkflags}"

make all --jobs
make install

[ -d "${mpfr_directory}/build" ] || mkdir "${mpfr_directory}/build"

cd "${mpfr_directory}/build"

../configure \
	--prefix="${toolchain_directory}" \
	--with-gmp="${toolchain_directory}" \
	--enable-shared \
	--enable-static \
	${cross_compile_flags} \
	CFLAGS="${optflags}" \
	CXXFLAGS="${optflags}" \
	LDFLAGS="${linkflags}"

make all --jobs
make install

[ -d "${mpc_directory}/build" ] || mkdir "${mpc_directory}/build"

cd "${mpc_directory}/build"

../configure \
	--prefix="${toolchain_directory}" \
	--with-gmp="${toolchain_directory}" \
	--enable-shared \
	--enable-static \
	${cross_compile_flags} \
	CFLAGS="${optflags}" \
	CXXFLAGS="${optflags}" \
	LDFLAGS="${linkflags}"

make all --jobs
make install

# sed cmd modified for macos
if [ "$(uname -s)" == 'Darwin' ]; then
	sed -i '' 's/#include <stdint.h>/#include <stdint.h>\n#include <stdio.h>/g' "${toolchain_directory}/include/mpc.h"
else
	sed -i 's/#include <stdint.h>/#include <stdint.h>\n#include <stdio.h>/g' "${toolchain_directory}/include/mpc.h"
fi

[ -d "${binutils_directory}/build" ] || mkdir "${binutils_directory}/build"

declare -r targets=(
	'amd64'
	'arm64'
	'i386'
	'powerpc/powerpc'
	'powerpc/powerpc64'
	'powerpc/powerpc64_elfv2'
	'riscv/riscv64'
	'sparc64/sparc64'
)

for target in "${targets[@]}"; do
	declare extra_configure_flags=''
	
	declare version='12.3-RELEASE'
	
	if [ "${target}" == 'riscv/riscv64' ]; then
		extra_configure_flags+='--disable-libatomic --disable-libitm'
		version='13.0-RELEASE'
	elif [ "${target}" == 'powerpc/powerpc64_elfv2' ]; then
		# https://reviews.freebsd.org/D20383
		extra_configure_flags+='--with-abi=elfv2'
		version='13.0-RELEASE'
	fi
	
	declare url="http://ftp-archive.freebsd.org/pub/FreeBSD-Archive/old-releases/$(cut -d '_' -f '1' <<< "${target}")/${version}/base.txz"
	declare output="/tmp/freebsd-${target//\//_}-base.tar.xz"
	
	case "${target}" in
		amd64)
			declare triplet='x86_64-unknown-freebsd12.3';;
		arm64)
			declare triplet='aarch64-unknown-freebsd12.3';;
		i386)
			declare triplet='i386-unknown-freebsd12.3';;
		powerpc/powerpc)
			declare triplet='powerpc-unknown-freebsd12.3';;
		powerpc/powerpc64)
			declare triplet='powerpc64-unknown-freebsd12.3';;
		powerpc/powerpc64_elfv2)
			declare triplet='powerpc64-unknown-freebsd13.0';;
		riscv/riscv64)
			declare triplet='riscv64-unknown-freebsd13.0';;
		sparc64/sparc64)
			declare triplet='sparc64-unknown-freebsd12.3';;
	esac
	wget --no-verbose "${url}" --output-document="${output}"
	
	# Apply patches requires for Apple Silicon
	if [ "$(uname -s)" == 'Darwin' ]; then
		cd "${binutils_directory}"
		# Only apply patch if required, as this loops for multiple targets
		if patch --forward -p1 --dry-run < /tmp/binutils-apple-silicon.patch; then
			patch --forward -p1 < /tmp/binutils-apple-silicon.patch
		else
			true
		fi
	fi

	cd "${binutils_directory}/build"
	if [ "$(uname -s)" == 'Darwin' ]; then
		rm -rf ./*
	else
		rm --force --recursive ./*
	fi
	
	../configure \
		--target="${triplet}" \
		--prefix="${toolchain_directory}" \
		--enable-gold \
		--enable-ld \
		--enable-lto \
		--disable-gprofng \
		--with-static-standard-libraries \
		--with-sysroot="${toolchain_directory}/${triplet}" \
		${cross_compile_flags} \
		CFLAGS="${optflags}" \
		CXXFLAGS="${optflags}" \
		LDFLAGS="${linkflags}"
	
	make all --jobs="${max_jobs}"
	make install
	
	tar --directory="${toolchain_directory}/${triplet}" --strip=2 --extract --file="${output}" './usr/lib' './usr/include'
	tar --directory="${toolchain_directory}/${triplet}" --extract --file="${output}"  './lib'
	
	pushd "${toolchain_directory}/${triplet}/lib"
	
	if [ -f './libc++.so' ]; then
		chmod 777 './libc++.so'
		echo 'GROUP ( ./libc++.so.1 ./libcxxrt.so )' > './libc++.so'
		chmod 444 './libc++.so'
	fi
	
	chmod 777 './libc.so'
	
	if [ "${target}" == 'riscv/riscv64' ] || [ "${target}" == 'powerpc/powerpc64_elfv2' ]; then
		echo 'GROUP ( ./libc.so.7 ./libc_nonshared.a )' > './libc.so'
	else
		echo 'GROUP ( ./libc.so.7 ./libc_nonshared.a ./libssp_nonshared.a )' > './libc.so'
	fi
	
	chmod 444 './libc.so'
	
	find . -type l | xargs ls -l | grep '/lib/' | awk '{print "unlink "$9" && ln -s $(basename "$11") $(basename "$9")"}' | bash 
	
	pushd
	
	cd "${gcc_directory}/build"
	
	if [ "$(uname -s)" == 'Darwin' ]; then
		rm -rf ./*
	else
		rm --force --recursive ./*
	fi

	if [ "$(uname -s)" != 'Darwin' ]; then
		declare extra_ld_flags=LDFLAGS="-Wl,-rpath-link,${OBGGCC_TOOLCHAIN}/${CROSS_COMPILE_TRIPLET}/lib ${linkflags}"
	else 
		declare extra_ld_flags=''
	fi
	
	../configure \
		--target="${triplet}" \
		--prefix="${toolchain_directory}" \
		--with-linker-hash-style='gnu' \
		--with-gmp="${toolchain_directory}" \
		--with-mpc="${toolchain_directory}" \
		--with-mpfr="${toolchain_directory}" \
		--with-bugurl='https://github.com/AmanoTeam/Loki/issues' \
		--with-gcc-major-version-only \
		--with-pkgversion="Loki v0.4-${revision}" \
		--with-sysroot="${toolchain_directory}/${triplet}" \
		--with-native-system-header-dir='/include' \
		--includedir="${toolchain_directory}/${triplet}/include" \
		--enable-__cxa_atexit \
		--enable-cet='auto' \
		--enable-checking='release' \
		--enable-default-ssp \
		--enable-gnu-indirect-function \
		--enable-languages='c,c++' \
		--enable-libstdcxx-backtrace \
		--enable-link-serialization='1' \
		--enable-linker-build-id \
		--enable-lto \
		--enable-plugin \
		--enable-shared \
		--enable-threads='posix' \
		--enable-libssp \
		--enable-ld \
		--enable-gold \
		--disable-libstdcxx-pch \
		--disable-werror \
		--disable-libgomp \
		--disable-bootstrap \
		--disable-multilib \
		--disable-gnu-unique-object \
		--without-headers \
		${extra_configure_flags} \
		${cross_compile_flags} \
		CFLAGS="${optflags}" \
		CXXFLAGS="${optflags}" \
		"${extra_ld_flags}"
	
	LD_LIBRARY_PATH="${toolchain_directory}/lib" PATH="${PATH}:${toolchain_directory}/bin" make \
		CFLAGS_FOR_TARGET="${optflags} ${linkflags}" \
		CXXFLAGS_FOR_TARGET="${optflags} ${linkflags}" \
		all --jobs="${max_jobs}"
	make install
	
	cd "${toolchain_directory}/${triplet}/bin"
	
	for name in *; do
		rm "${name}"
		ln -s "../../bin/${triplet}-${name}" "${name}"
	done
	
	if [ "$(uname -s)" == 'Darwin' ]; then
		rm -r "${toolchain_directory}/share"
		rm -r "${toolchain_directory}/lib/gcc/${triplet}/"*"/include-fixed"
	else
		rm --recursive "${toolchain_directory}/share"
		rm --recursive "${toolchain_directory}/lib/gcc/${triplet}/"*"/include-fixed"
	fi
	if [ "$(uname -s)" == 'Darwin' ]; then
		file "${toolchain_directory}/libexec/gcc/${triplet}/"*"/cc1"
		file "${toolchain_directory}/libexec/gcc/${triplet}/"*"/cc1plus"
		file "${toolchain_directory}/libexec/gcc/${triplet}/"*"/lto1"
		otool -L "${toolchain_directory}/libexec/gcc/${triplet}/"*"/cc1"
		otool -L  "${toolchain_directory}/libexec/gcc/${triplet}/"*"/cc1plus"
		otool -L  "${toolchain_directory}/libexec/gcc/${triplet}/"*"/lto1"

		for binary in "${toolchain_directory}/libexec/gcc/${triplet}/"*"/cc1" "${toolchain_directory}/libexec/gcc/${triplet}/"*"/cc1plus" "${toolchain_directory}/libexec/gcc/${triplet}/"*"/lto1"; do
			for dep in $(otool -L "${binary}" | awk -v dir="${toolchain_directory}" '$0 ~ dir {print $1}'); do
				install_name_tool -change "${dep}" "@loader_path/../../../../lib/$(basename "${dep}")" "${binary}"
			done
		done

		otool -L "${toolchain_directory}/libexec/gcc/${triplet}/"*"/cc1"
		otool -L  "${toolchain_directory}/libexec/gcc/${triplet}/"*"/cc1plus"
		otool -L  "${toolchain_directory}/libexec/gcc/${triplet}/"*"/lto1"
	else
		patchelf --add-rpath '$ORIGIN/../../../../lib' "${toolchain_directory}/libexec/gcc/${triplet}/"*"/cc1"
		patchelf --add-rpath '$ORIGIN/../../../../lib' "${toolchain_directory}/libexec/gcc/${triplet}/"*"/cc1plus"
		patchelf --add-rpath '$ORIGIN/../../../../lib' "${toolchain_directory}/libexec/gcc/${triplet}/"*"/lto1"
	fi
done
