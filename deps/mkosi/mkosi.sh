#!/bin/bash

set -x

PROGRAM_NAME="$(basename "$0")"

usage() {
    cat <<EOF
${PROGRAM_NAME} -- a simple wrapper to build multiple types of Finch images.

Usage: ${PROGRAM_NAME}
       ${PROGRAM_NAME} --arch=[x86_64|aarch64] --format=[oci|disk]
       ${PROGRAM_NAME} -h|--help

Options:

  --arch: Specify the target arch for the image.

  --format: Specify the target format: disk or oci.

  -h,--help: Print this usage message.
EOF
}

error() {
    printf "%s\n" "$*" >/dev/stderr
    exit 1
}

mkosi_args=()

while [ -n "${1-}" ]; do
    case "${1}" in
    -a | --arch)
        arch="${2}"
        shift
        shift
        ;;

    --arch=*)
        arch="${i#*=}"
        shift
        ;;

    -f | --format)
        format="${2}"
        shift
        shift
        ;;

    --format=*)
        format="${i#*=}"
        shift
        ;;

    -h | --help)
        usage
        exit 0
        ;;

    --)
        shift
        mkosi_args=("$@")
        break
        ;;

    -*)
        error "Unknown option: '$1'."
        ;;
    esac
done

[[ -z "$arch" ]] && { echo "Error: arch not set"; exit 1; }
[[ -z "$format" ]] && { echo "Error: format not set"; exit 1; }

MKOSI_OUT_DIR="./out/${arch}/${format}"
mkdir -p "${MKOSI_OUT_DIR}"

mkosi_arch=""
case $arch in
    x86_64)
        mkosi_arch="x86-64"
        ;;
    aarch64)
        mkosi_arch="arm64"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        ;;
esac

# /home/fedora/mkosivenv/bin/mkosi -f --architecture="${mkosi_arch}" --output-directory="${MKOSI_OUT_DIR}" "${mkosi_args[@]}"
MKOSI_DNF=/usr/bin/dnf4 /home/fedora/mkosivenv-al/bin/mkosi --debug -f --architecture="${mkosi_arch}" --output-directory="${MKOSI_OUT_DIR}" "${mkosi_args[@]}"
