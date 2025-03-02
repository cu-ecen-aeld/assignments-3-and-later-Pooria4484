#!/bin/bash
# Script outline to install and build kernel for assignment full-test.
# Author: Siddhant Jajoo, modified by Grok for Pooria.

set -e
set -u

OUTDIR=/home/pooria/colorado/manual-linux
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.15.163
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-none-linux-gnu-

if [ $# -lt 1 ]
then
    echo "Using default directory ${OUTDIR} for output"
else
    OUTDIR=$1
    echo "Using passed directory ${OUTDIR} for output"
fi

mkdir -p ${OUTDIR}

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
    git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi
if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}

    # Build the kernel with virt config for QEMU
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} virtconfig || make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} -j$(nproc)
fi

echo "Adding the Image in outdir"
cp ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ${OUTDIR}/

echo "Creating the staging directory for the root filesystem"
cd "$OUTDIR"
if [ -d "${OUTDIR}/rootfs" ]
then
    echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
    sudo rm -rf ${OUTDIR}/rootfs
fi

# Create necessary base directories, including /conf/ and /home/conf/
mkdir -p ${OUTDIR}/rootfs/{bin,sbin,etc,proc,sys,usr/{bin,sbin},dev,home/conf,lib,lib64,conf}

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]
then
    git clone git://busybox.net/busybox.git
    cd busybox
    git checkout ${BUSYBOX_VERSION}
    make CROSS_COMPILE=${CROSS_COMPILE} defconfig
else
    cd busybox
fi

# Make and install busybox
make CROSS_COMPILE=${CROSS_COMPILE} -j$(nproc)
make CROSS_COMPILE=${CROSS_COMPILE} CONFIG_PREFIX=${OUTDIR}/rootfs install

# Set the setuid bit on the BusyBox binary
echo "Setting setuid bit on BusyBox binary"
sudo chmod u+s ${OUTDIR}/rootfs/bin/busybox || { echo "Failed to set setuid on BusyBox"; exit 1; }

echo "Library dependencies"
${CROSS_COMPILE}readelf -a ${OUTDIR}/rootfs/bin/busybox | grep "program interpreter"
${CROSS_COMPILE}readelf -a ${OUTDIR}/rootfs/bin/busybox | grep "Shared library"

# Add library dependencies to rootfs
SYSROOT=$(${CROSS_COMPILE}gcc --print-sysroot)
echo "Detected SYSROOT: $SYSROOT"

# Extract interpreter and library names
INTERPRETER=$(basename "$(${CROSS_COMPILE}readelf -a ${OUTDIR}/rootfs/bin/busybox | grep "program interpreter" | awk -F: '{print $2}' | tr -d '[]' | xargs)")
LIBS=$(${CROSS_COMPILE}readelf -a ${OUTDIR}/rootfs/bin/busybox | grep "Shared library" | awk -F: '{print $2}' | tr -d '[]' | xargs)

echo "Interpreter: $INTERPRETER"
echo "Libraries: $LIBS"

# Copy the interpreter (from ${SYSROOT}/lib/)
echo "Copying interpreter: ${INTERPRETER}"
if [ -f "${SYSROOT}/lib/${INTERPRETER}" ]; then
    cp "${SYSROOT}/lib/${INTERPRETER}" ${OUTDIR}/rootfs/lib/ || { echo "Failed to copy interpreter ${SYSROOT}/lib/${INTERPRETER}"; exit 1; }
else
    echo "Interpreter ${INTERPRETER} not found in ${SYSROOT}/lib"; exit 1;
fi

# Copy the shared libraries (search both lib/ and lib64/)
echo "Copying shared libraries..."
for lib in $LIBS; do
    if [ -f "${SYSROOT}/lib64/${lib}" ]; then
        echo "Copying ${lib} from ${SYSROOT}/lib64/"
        cp "${SYSROOT}/lib64/${lib}" ${OUTDIR}/rootfs/lib/ || { echo "Failed to copy library ${SYSROOT}/lib64/${lib}"; exit 1; }
    elif [ -f "${SYSROOT}/lib/${lib}" ]; then
        echo "Copying ${lib} from ${SYSROOT}/lib/"
        cp "${SYSROOT}/lib/${lib}" ${OUTDIR}/rootfs/lib/ || { echo "Failed to copy library ${SYSROOT}/lib/${lib}"; exit 1; }
    else
        echo "Searching for ${lib} in ${SYSROOT}..."
        LIB_PATH=$(find "${SYSROOT}" -name "${lib}" | head -n 1)
        if [ -n "$LIB_PATH" ]; then
            echo "Found ${lib} at ${LIB_PATH}, copying..."
            cp "${LIB_PATH}" ${OUTDIR}/rootfs/lib/ || { echo "Failed to copy library ${LIB_PATH}"; exit 1; }
        else
            echo "Library ${lib} not found in ${SYSROOT}"; exit 1;
        fi
    fi
done

# Duplicate libraries to lib64/ as a fallback
echo "Duplicating libraries to /lib64/..."
cp ${OUTDIR}/rootfs/lib/* ${OUTDIR}/rootfs/lib64/ || { echo "Failed to duplicate libraries to lib64"; exit 1; }

# Verify libraries are copied
echo "Verifying libraries in rootfs/lib..."
ls -l ${OUTDIR}/rootfs/lib/
echo "Verifying libraries in rootfs/lib64..."
ls -l ${OUTDIR}/rootfs/lib64/

# Make device nodes
sudo mknod -m 666 ${OUTDIR}/rootfs/dev/null c 1 3
sudo mknod -m 666 ${OUTDIR}/rootfs/dev/console c 5 1

# Clean and build the writer utility
cd ${FINDER_APP_DIR}
make clean
make CROSS_COMPILE=${CROSS_COMPILE}

# Copy the finder related scripts and executables to the /home directory on the target rootfs
mkdir -p ${OUTDIR}/rootfs/home
cp ${FINDER_APP_DIR}/writer ${OUTDIR}/rootfs/home/
cp ${FINDER_APP_DIR}/finder.sh ${OUTDIR}/rootfs/home/
cp ${FINDER_APP_DIR}/finder-test.sh ${OUTDIR}/rootfs/home/
cp ${FINDER_APP_DIR}/autorun-qemu.sh ${OUTDIR}/rootfs/home/

# Ensure all scripts are executable
echo "Setting executable permissions on scripts..."
sudo chmod +x ${OUTDIR}/rootfs/home/finder.sh || { echo "Failed to make finder.sh executable"; exit 1; }
sudo chmod +x ${OUTDIR}/rootfs/home/finder-test.sh || { echo "Failed to make finder-test.sh executable"; exit 1; }
sudo chmod +x ${OUTDIR}/rootfs/home/autorun-qemu.sh || { echo "Failed to make autorun-qemu.sh executable"; exit 1; }

# Copy conf contents to both /conf/ and /home/conf/ in the rootfs
echo "Copying conf contents to /conf/ and /home/conf/..."
cp -r ${FINDER_APP_DIR}/conf/* ${OUTDIR}/rootfs/conf/ || { echo "Failed to copy conf contents to /conf/"; exit 1; }
cp -r ${FINDER_APP_DIR}/conf/* ${OUTDIR}/rootfs/home/conf/ || { echo "Failed to copy conf contents to /home/conf/"; exit 1; }

# Verify conf contents in both locations
echo "Verifying contents of /conf/..."
ls -l ${OUTDIR}/rootfs/conf/
echo "Verifying contents of /home/conf/..."
ls -l ${OUTDIR}/rootfs/home/conf/

# Verify finder scripts
echo "Verifying finder scripts in /home/..."
ls -l ${OUTDIR}/rootfs/home/

# Chown the root directory
sudo chown -R root:root ${OUTDIR}/rootfs

# Create initramfs.cpio.gz with init running autorun-qemu.sh and debugging
cd ${OUTDIR}/rootfs
sudo sh -c "echo '#!/bin/sh' > init"
sudo sh -c "echo 'mount -t proc none /proc' >> init"
sudo sh -c "echo 'mount -t sysfs none /sys' >> init"
sudo sh -c "echo 'cd /home' >> init"  # Working directory is /home
sudo sh -c "echo 'echo \"Current directory: \$(/bin/pwd)\"' >> init"  # Debug
sudo sh -c "echo 'ls -l /home/' >> init"  # Debug
sudo sh -c "echo 'exec /home/autorun-qemu.sh' >> init"
sudo chmod +x init
find . -print0 | cpio -o -H newc --null | gzip > ${OUTDIR}/initramfs.cpio.gz

echo "Script completed successfully!"