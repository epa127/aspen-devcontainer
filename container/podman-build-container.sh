#! /bin/bash

cd `dirname $0`

arch="`arch`"
os="`uname`"
disk_size=12

# Check if the Podman machine already exists
if podman machine list | grep -q "^podman-machine-default"; then
    echo "Podman machine already exists. Jumping straight to building the image..."
else
    # Initializing Podman Machine
    echo "Initializing Podman machine on $os ($arch)..."
    podman machine init --disk-size="$disk_size"
    podman machine start
fi

tag=
platform=
while test "$#" -ne 0; do
    if test "$1" = "-a" -o "$1" = "--arm" -o "$1" = "--arm64"; then
        if test "`arch`" = "arm64" -o "`arch`" = "aarch64"; then
            platform=linux/arm64
            shift
        else
            echo "\`podman-build-container.sh --arm\` only works on ARM64 hosts" 1>&2
            exit 1
        fi
    elif test "$1" = "-x" -o "$1" = "--x86-64" -o "$1" = "--x86_64" -o "$1" = "--amd64"; then
        platform=linux/amd64
    else
        armtext=
        if test "`arch`" = "arm64" -o "`arch`" = "aarch64"; then
            armtext=" [-a|--arm] [-x|--x86-64]"
        fi
        echo "Usage: podman-build-container.sh$armtext" 1>&2
        exit 1
    fi
done

tag=localhost/cs2690:amd64
platform=linux/amd64

if test $platform = linux/arm64; then
    exec podman build -t "$tag" -f Dockerfile.arm64 --platform linux/amd64 .
else
    exec podman build -t "$tag" -f Dockerfile --platform linux/amd64 .
fi
