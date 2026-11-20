#!/bin/bash
# Container entrypoint: runs as root, adapts the "student" user to the host
# UID/GID (Linux only, passed by run.sh), then starts JupyterLab as student.
set -e
NB_USER=student

if [ "$(id -u)" = 0 ]; then
    if [ -n "${HOST_GID:-}" ] && [ "$HOST_GID" != "$(id -g "$NB_USER")" ]; then
        groupmod -o -g "$HOST_GID" "$NB_USER"
    fi
    if [ -n "${HOST_UID:-}" ] && [ "$HOST_UID" != "$(id -u "$NB_USER")" ]; then
        usermod -o -u "$HOST_UID" "$NB_USER"
    fi
    # student must own its home and the Python environment (pip install)
    if [ "$(stat -c %u:%g /opt/venv)" != "$(id -u "$NB_USER"):$(id -g "$NB_USER")" ]; then
        chown -R "$NB_USER:$NB_USER" /opt/venv "/home/$NB_USER"
    fi
    # /sharedFolder not mounted from the host: make it writable for student
    mountpoint -q /sharedFolder || chown "$NB_USER:$NB_USER" /sharedFolder
    exec setpriv --reuid="$NB_USER" --regid="$NB_USER" --init-groups \
        env HOME="/home/$NB_USER" USER="$NB_USER" LOGNAME="$NB_USER" "$@"
fi
exec "$@"
