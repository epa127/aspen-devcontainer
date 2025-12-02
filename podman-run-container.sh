#! /bin/bash

maindir=""
destdir=cs2690
container_name=cs2690-devenv

clean=false
verbose=false
arch="`uname -m`"
tag=
platform=
use_cc=true
while test "$#" -ne 0; do
    if test "$1" = "-V" -o "$1" = "--verbose"; then
        verbose=true
        shift
    elif test "$1" = "-a" -o "$1" = "--arm" -o "$1" = "--arm64"; then
        if test "$arch" = "arm64" -o "$arch" = "aarch64"; then
            platform=linux/amd64
            shift
        else
            echo "\`podman-run-container.sh --arm\` only works on ARM64 hosts" 1>&2
            exit 1
        fi
    elif test "$1" = "-x" -o "$1" = "--x86-64" -o "$1" = "--x86_64" -o "$1" = "--amd64"; then
        platform=linux/amd64
    elif test "$1" = "--no-cc"; then
        use_cc=false
        shift
    else
        armtext=
        if test "$arch" = "arm64" -o "$arch" = "aarch64"; then
            armtext=" [-a|--arm] [-x|--x86-64]"
        fi
        echo "Usage: podman-run-container.sh $armtext [-V|--verbose]" 1>&2
        exit 1
    fi
done

if test -z "$platform" -a \( "$arch" = "arm64" -o "$arch" = "aarch64" \); then
    platform=linux/amd64
elif test -z "$platform"; then
    platform=linux/amd64
fi
if test -z "$tag" -a "$platform" = linux/arm64; then
    tag=cs2690:amd64
elif test -z "$tag"; then
    tag=cs2690:amd64
fi

vexec () {
    if $verbose; then
        echo "$@"
    fi
    exec "$@"
}

if stat --format %i / >/dev/null 2>&1; then
    statformatarg="--format"
else
    statformatarg="-f"
fi
myfileid=`stat $statformatarg %d:%i "${BASH_SOURCE[0]}" 2>/dev/null`

dir="`pwd`"
subdir=""
while test "$dir" != / -a "$dir" != ""; do
    thisfileid=`stat $statformatarg %d:%i "$dir"/podman-run-container.sh 2>/dev/null`
    if test -n "$thisfileid" -a "$thisfileid" = "$myfileid"; then
        maindir="$dir"
        break
    fi
    subdir="/`basename "$dir"`$subdir"
    dir="`dirname "$dir"`"
done

if test -z "$maindir" && expr "${BASH_SOURCE[0]}" : / >/dev/null 2>&1; then
    maindir="`dirname "${BASH_SOURCE[0]}"`"
    subdir=""
fi

ssharg=
sshenvarg=
if test -n "$SSH_AUTH_SOCK" -a "`uname`" = Darwin; then
    ssharg=" -v /run/host-services/ssh-auth.sock:/run/host-services/ssh-auth.sock"
    sshenvarg=" -e SSH_AUTH_SOCK=/run/host-services/ssh-auth.sock"
fi

if test -n "$maindir"; then
    existing_image="`podman ps -f status=running -f ancestor=$tag -f volume=/host_mnt"$maindir" --no-trunc --format "{{.CreatedAt}},{{.ID}}" | sort -r | head -n 1`"
    if test -n "$existing_image"; then
        created_at="`echo $existing_image | sed 's/,.*//'`"
        image="`echo $existing_image | sed 's/^.*,//'`"
        image12="`echo $image | head -c 12`"
        echo "* Using running container $image12, created $created_at" 1>&2
        echo "- To start a new container, exit then \`podman-run-container.sh -f\`" 1>&2
        echo "- To kill this container, exit then \`podman kill $image12\`" 1>&2
        vexec podman exec -it$sshenvarg $image /bin/bash
    fi
fi

netarg=
if test `uname` = Darwin; then
    if ! netstat -n -a -p tcp | grep '\.6169[  ].*LISTEN' >/dev/null; then
        netarg="$netarg "'--expose=6169/tcp -p 6169:6169/tcp'
    fi
    if ! netstat -n -a -p tcp | grep '\.12949[ 	].*LISTEN' >/dev/null; then
        netarg="$netarg "'--expose=12949/tcp -p 12949:12949/tcp'
    fi
elif test -x /bin/netstat; then
    if ! netstat -n -a -p tcp | grep '\.6169[  ].*LISTEN' >/dev/null; then
        netarg="$netarg "'--expose=6169/tcp -p 6169:6169/tcp'
    fi
    if ! netstat -n -l -t | grep ':12949[ 	]' >/dev/null; then
        netarg="$netarg "'--expose=12949/tcp -p 12949:12949/tcp'
    fi
fi

if test -z "$maindir"; then
    echo "Error: could not determine your directory."
    exit 1
fi

vexec podman run -it --rm\
    --name $container_name \
    --platform $platform \
    --privileged \
    --cap-add=SYS_PTRACE --cap-add=NET_ADMIN --security-opt seccomp=unconfined \
    -v "$maindir/home":/home/aspen \
    -w "/home/aspen" \
    --net=host \
    -e DISPLAY=host.docker.internal:0 \
    -e ADD_CROSS_COMPILATION_TOOLCHAIN_TO_PATH=$use_cc \
    --volume="$HOME/.Xauthority:/root/.Xauthority:rw" \
    $tag
