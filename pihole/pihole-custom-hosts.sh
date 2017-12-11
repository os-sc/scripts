#!/usr/bin/env bash

main() {
    # Settings
    local nas_ip="10.0.1.3"
    local nas_share="/volume1/public"
    local mount_target="/tmp/pihole-custom-hosts"
    local nas_host_file="${mount_target}/etc/hosts.txt"
    local local_host_file="/etc/hosts"

    # Assert this script is run as root
    if [ "$EUID" -ne 0 ]; then
        echo "This script needs to run as root!"
        exit 1
    fi

    # Wake up NAS if it is in standby mode
    wake_up_nas "$nas_ip"

    # Mount NFS Directory
    mount_nfs "$nas_ip" "$nas_share" "$mount_target"

    # Add lines that don't already exists
    copy_new_lines "$nas_host_file" "$local_host_file"

    # Unmount NFS share
    umount "$mount_target"
}


# Make a request to the NAS' web interface
# To make sure it doesn't time out later
wake_up_nas() {
    local host="http://${1}"
    curl -LI "$host" --connect-timeout 30
}


# Mount the NFS Share
mount_nfs() {
    local host="$1"
    local remote="$2"
    local dir="$3"
    mkdir -p "$dir"
    mount -t 'nfs' "${host}:${remote}" "$dir"
}


# Copies only the lines to the destination that don't already exist
# Ignores lines starting with a `#`
copy_new_lines() {
    local src="$1"
    local dest="$2"
    while read -r line; do
        printf 'Checking "%s"\n' "$line"

        if [ -z "$line" ]; then
            printf '\t=> Skipping empty line\n'
            continue
        fi

        if echo "$line" | grep -E '^#' >/dev/null; then
            printf '\t=> Skipping comment\n'
            continue
        fi

        if grep -xF "$line" "$dest" >/dev/null; then
            printf '\t=> Skipping already present line\n'
            continue
        fi

        printf '\t=> Adding %s to file\n' "$line"
        echo "$line" >> "$dest"
    done <"$src"
}


main "$@"
