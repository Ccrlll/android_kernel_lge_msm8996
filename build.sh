#!/usr/bin/env bash

# Colors
RED='\033[0;31m'   # Red for errors
GREEN='\033[0;32m'   # Green for success
BLUE='\033[1;34m'   # Blue for info
NORMAL='\033[0m'   # Reset color

# Kernel architecture & Directory
export ARCH="arm64"
# CONFIG="custom/us996d_defconfig" # Change to your defconfig directory.
ROOT="${PWD}"
TOOL="${HOME}/toolchain"
OUT="${ROOT}/out"

# Clang & GCC32
CLANG="${TOOL}/clang"
GCC32="${TOOL}/gcc-arm32"
LINK_CLANG="https://gitlab.com/crdroidandroid/android_prebuilts_clang_host_linux-x86_clang-r547379.git"
LINK_GCC32="https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9"

# Output
KERNEL="Ponkan™" # Change to your kernel name.
ANYKERNEL="${TOOL}/AnyKernel3" # Change this based on your AnyKernel directory.
OUTPUT="${OUT}/arch/arm64/boot"
BUILD_TYPE=0

# Build flags & Path
export KBUILD_BUILD_HOST=Ccrlll
export KBUILD_BUILD_USER=github
export PATH="${CLANG}/bin:${GCC32}/bin:$PATH"

# Check and clone Anykernel if missing
if ! [ -d "${ANYKERNEL}" ]; then
	echo -e "${RED}Anykernel is missing. Cloning to ${ANYKERNEL}.${NORMAL}"
	if ! git clone -q https://github.com/Ccrlll/AnyKernel3.git ${ANYKERNEL}; then
		echo -e "${RED}Cloning Anykernel failed!${NORMAL}"
	fi
fi

# Check and clone Clang if missing
if ! [ -d "${CLANG}" ]; then
  echo -e "${RED}CLANG not found! Cloning Clang to ${CLANG}.${NORMAL}"
  if ! git clone -b 15.0 --depth=1 --no-tags --single-branch ${LINK_CLANG} ${CLANG}; then
    echo -e "${RED}Cloning Clang failed!${NORMAL}"
  fi
fi

# Check and clone GCC32 if missing
if ! [ -d "${GCC32}" ]; then
  echo -e "${RED}CLANG not found! Cloning Clang to ${GCC32}.${NORMAL}"
  if ! git clone -b android-9.0.0_r48 --depth=1 --no-tags --single-branch ${LINK_GCC32} ${GCC32}; then
    echo -e "${RED}Cloning Clang failed!${NORMAL}"
  fi
fi

# Clean kernel build & build directory
if [ -d ${OUT} ]; then
	rm -rf ${OUT}
fi

if [ -f ${ROOT}/.config ]; then
	make clean && make mrproper
fi

clear
sleep 3
make_defconfig() {
	mkdir -p ${OUT} && 
    ${PWD}/scripts/kconfig/merge_config.sh -O ${OUT} \
	${PWD}/arch/arm64/configs/vendor/lge/lge_msm8996_defconfig \
	${PWD}/arch/arm64/configs/vendor/lge/vs995.config

	make -s ARCH="${ARCH}" O="${OUT}" olddefconfig
}

compile() {
	cd ${ROOT}
	echo -e ${GREEN}"######### Compiling kernel #########"${NORMAL}
	make -j$(nproc --all) \
	O=${OUT} \
	ARCH=${ARCH} \
	CC="ccache clang" \
	LD="ld.lld" \
	AR="llvm-ar" \
	NM="llvm-nm" \
	OBJCOPY="llvm-objcopy" \
	OBJDUMP="llvm-objdump" \
	STRIP="llvm-strip" \
	CLANG_TRIPLE="aarch64-linux-gnu-" \
	CROSS_COMPILE="aarch64-linux-android-" \
	CROSS_COMPILE_ARM32="arm-linux-androideabi-" \
	LLVM=1 \
	KCFLAGS="-Wno-error=implicit-function-declaration"
}

completion() {
	cd ${OUT}
	COMPILED_IMAGE="${OUTPUT}/Image.gz-dtb"

	if [ -f ${COMPILED_IMAGE} ]; then
		echo -e ${GREEN}"#### Build completed successfully (hh:mm:ss) ####"${NORMAL}
		BUILD_TYPE=1
	else
		echo -e ${RED}"#### Failed to build targets (hh:mm:ss) ####"${NORMAL}
	fi
}

copy_and_zip() {
	cd ${ROOT}
	local files_to_copy=("$@")
	local anykernel_files=("${ANYKERNEL}/Image.gz-dtb" "${ANYKERNEL}/${KERNEL}-"*".zip")

	# Remove existing files if they exist
	for file in "${anykernel_files[@]}"; do
		echo -e ${NORMAL}"#### Deleting old $file ####" ${NORMAL}
		if [[ -f $file ]]; then
			rm -f "$file"
		fi
	done

	# Copy new files
	echo -e ${BLUE}"#### Copying files to ${ANYKERNEL} dir... ####" ${NORMAL}
	cp -f "${files_to_copy[@]}" ${ANYKERNEL}
	echo -e ${GREEN}"#### Successful copying files... ####" ${NORMAL}

	# Create zip file
	echo -e ${BLUE}"#### Making zip file... ####" ${NORMAL}
	cd "${ANYKERNEL}" && zip -r "${KERNEL}-$(date +"%Y%m%d").zip" *
	echo -e ${GREEN}"#### Success! output is on ${ANYKERNEL} ####" ${NORMAL}
}
make_defconfig
compile
completion

# Check for necessary files and call the function accordingly
if [ $BUILD_TYPE -eq 2 ]; then
    copy_and_zip "${OUTPUT}/Image.gz-dtb"
else
    echo -e ${RED}"#### Images not found, Aborting... ####" ${NORMAL}
fi

cd ${ROOT}