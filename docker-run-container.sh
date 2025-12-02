#!/bin/bash
# Smart container launcher for aspen-rs
# Always runs x86_64 (amd64) container for compatibility with project toolchains.

set -e
cd "$(dirname "$0")"

# --- Configurable defaults ---
IMAGE_NAME="aspen-rs-image"
TAG="latest"
CONTAINER_NAME="aspen-rs-devenv"
PLATFORM="linux/amd64"
HOST_ARCH="$(uname -m)"
VERBOSE=false

# --- Parse flags ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        -V|--verbose)
            VERBOSE=true
            shift
            ;;
        -x|--x86|--amd64|--x86_64)
            PLATFORM="linux/amd64"
            TAG="latest"
            shift
            ;;
        -a|--arm|--arm64)
            if [[ "$HOST_ARCH" == "arm64" || "$HOST_ARCH" == "aarch64" ]]; then
                PLATFORM="linux/arm64"
                TAG="arm64"
                shift
            else
                echo "Error: --arm64 builds only supported on ARM hosts." >&2
                exit 1
            fi
            ;;
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [--x86|--arm] [--tag <name>] [-V|--verbose]"
            echo
            echo "Examples:"
            echo "  $0                # run amd64 container (default)"
            echo "  $0 --arm          # run native arm64 container (Apple Silicon only)"
            echo "  $0 --tag dev      # run cs2690:dev image"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# --- Summary ---
if $VERBOSE; then
    echo "Running container:"
    echo "  Host architecture : $HOST_ARCH"
    echo "  Target platform   : $PLATFORM"
    echo "  Image tag         : ${IMAGE_NAME}:${TAG}"
    echo "  Container name    : ${CONTAINER_NAME}"
    echo
fi

# --- SSH agent forwarding (for macOS) ---
SSH_ARGS=()
if [[ -n "$SSH_AUTH_SOCK" && "$(uname)" == "Darwin" ]]; then
    SSH_ARGS+=(
        "-v" "/run/host-services/ssh-auth.sock:/run/host-services/ssh-auth.sock"
        "-e" "SSH_AUTH_SOCK=/run/host-services/ssh-auth.sock"
    )
fi

# --- Port forwarding (optional dev ports) ---
NET_ARGS=()
for PORT in 6169 12949; do
    if ! netstat -an | grep -q "\.${PORT}[[:space:]].*LISTEN"; then
        NET_ARGS+=("--expose=${PORT}/tcp" "-p" "${PORT}:${PORT}/tcp")
    fi
done

# --- Volume mounts ---
WORKDIR="$(pwd)"
HOME_DIR="$WORKDIR/home"
mkdir -p "$HOME_DIR"

# --- If an existing container is running, reuse it ---
EXISTING_ID=$(docker ps -q -f name="$CONTAINER_NAME")
if [[ -n "$EXISTING_ID" ]]; then
    echo "* Reusing running container $CONTAINER_NAME ($EXISTING_ID)"
    exec docker exec -it "$CONTAINER_NAME" /bin/bash
fi

# --- Run container ---
CMD=(
    docker run -it --rm
    --name "$CONTAINER_NAME"
    --platform "$PLATFORM"
    --privileged
    --cap-add=SYS_PTRACE
    --cap-add=NET_ADMIN
    --security-opt seccomp=unconfined
    -v "$HOME_DIR:/home/aspen"
    -w "/home/aspen"
    --net=host
    -e DISPLAY=host.docker.internal:0
    --volume="$HOME/.Xauthority:/root/.Xauthority:rw"
    "${NET_ARGS[@]}"
    "${SSH_ARGS[@]}"
    "${IMAGE_NAME}:${TAG}"
)

if $VERBOSE; then
    echo "${CMD[@]}"
fi

exec "${CMD[@]}"