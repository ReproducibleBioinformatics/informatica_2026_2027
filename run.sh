#!/usr/bin/env bash
set -euo pipefail

# JupyterLab with R — macOS (Intel and Apple Silicon) and Linux.
# Run with:  bash run.sh
# Then open: http://localhost:8888
# Files saved in the shared folder stay on your computer after you stop it.

IMAGE="ghcr.io/reproduciblebioinformatics/informatica_2026_2027:latest"
NAME="informatica-jupyter"
PORT=8888

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/configurationFile.txt"

die() { echo "ERROR: $*" >&2; exit 1; }

command -v docker >/dev/null 2>&1 || die "Docker is not installed or not in PATH."
docker info >/dev/null 2>&1 || die "Docker is not running. Start Docker Desktop and try again."

# --- Architecture autodetect -------------------------------------------------
# Ask the Docker engine itself: it is what actually runs the container.
# (uname -m can lie on a Mac if the terminal runs under Rosetta.)
ARCH="$(docker info --format '{{.Architecture}}' 2>/dev/null || true)"
[[ -n "$ARCH" ]] || ARCH="$(uname -m)"
case "$ARCH" in
    aarch64|arm64) PLATFORM="linux/arm64" ;;
    x86_64|amd64)  PLATFORM="linux/amd64" ;;
    *) die "Unsupported architecture: $ARCH" ;;
esac

# --- Shared folder -----------------------------------------------------------
if [[ -f "$CONFIG_FILE" ]]; then
    SHARED_DIR="$(head -n 1 "$CONFIG_FILE" | tr -d '\r')"
    [[ -n "$SHARED_DIR" ]] || die "configurationFile.txt is empty: write the folder to share on the first line."
    case "$SHARED_DIR" in
        /*) ;;
        *) SHARED_DIR="$SCRIPT_DIR/$SHARED_DIR" ;;
    esac
else
    SHARED_DIR="$SCRIPT_DIR"
    printf '%s\n' "$SHARED_DIR" > "$CONFIG_FILE"
fi
mkdir -p -- "$SHARED_DIR"
SHARED_DIR="$(cd -- "$SHARED_DIR" && pwd)"

# --- Clean up a previous run (stuck containers are the #1 problem) -----------
if docker ps -a --format '{{.Names}}' | grep -qx "$NAME"; then
    echo "Removing previous container $NAME..."
    docker rm -f "$NAME" >/dev/null
fi
if docker ps --format '{{.Ports}}' | grep -q ":$PORT->"; then
    die "Port $PORT is used by another container. Stop it with: docker ps   then   docker rm -f <ID>"
fi

# --- Pull the native image for this machine ----------------------------------
echo "Architecture: $ARCH -> $PLATFORM"
echo "Downloading/updating image (the first time it may take a few minutes)..."
docker pull --platform "$PLATFORM" "$IMAGE"

RUN_ARGS=(
    --rm -it
    --name "$NAME"
    --platform "$PLATFORM"
    -p "127.0.0.1:$PORT:8888"
    -v "$SHARED_DIR:/sharedFolder"
    --shm-size=2g
)
# On Linux run as the current user so files in the shared folder are yours.
if [[ "$(uname -s)" == Linux ]]; then
    RUN_ARGS+=( --user "$(id -u):$(id -g)" )
fi

echo
echo "Shared folder: $SHARED_DIR"
echo "Open http://localhost:$PORT in your browser."
echo "Press Ctrl+C here to stop."
echo
exec docker run "${RUN_ARGS[@]}" "$IMAGE"
