#!/bin/bash

set -xe

# set arch to uname if its not set
uname=$(uname -m)
ARCH="${ARCH:-$uname}"

# https://github.com/systemd/mkosi/blob/c29462cfefe9b9b366a007d9f06edc4d5c65e315/mkosi/resources/man/mkosi.1.md?plain=1#L449
mkosi_arch=""
docker_arch=""
main_emu_arch=""
case $ARCH in
    x86_64)
        docker_arch="amd64"
        mkosi_arch="x86-64"
        main_emu_arch="aarch64"
        ;;
    aarch64)
        docker_arch="arm64"
        mkosi_arch="arm64"
        main_emu_arch="x86_64"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        ;;
esac


# Sync repo
git submodule update --remote --merge

# Build
pushd ./binfmt
rm -rf bin
docker run --privileged --rm tonistiigi/binfmt --install all
docker buildx bake desktop \
  --set "*.output=type=local,dest=./bin,platform-split=true" \
  --set "*.cache-from=" \
  # --set "*.platform=linux/amd64,linux/arm64"
  --set "*.platform=linux/$docker_arch"

popd

rm -rf ./binfmt/bin/linux_amd64/lib/binfmt.d/
mkdir -p ./binfmt/bin/linux_amd64/lib/binfmt.d/

rm -rf ./qemu-binfmt-conf.sh

curl "https://gitlab.com/api/v4/projects/qemu-project%2Fqemu/repository/files/scripts%2Fqemu-binfmt-conf.sh/raw?ref=master" \
  -o qemu-binfmt-conf.sh

chmod +x qemu-binfmt-conf.sh

mkdir -p "./binfmt/bin/linux_${docker_arch}/lib/binfmt.d/"

export HOST_ARCH="${ARCH}"
./qemu-binfmt-conf.sh --systemd ALL \
  --credential yes \
  --persistent yes \
  --preserve-argv0 yes \
  -Q /usr/bin \
  --exportdir "./binfmt/bin/linux_${docker_arch}/lib/binfmt.d/"

MKOSI_USR_PATH="./mkosi.extra/usr"
MKOSI_BINFMT_PATH="${MKOSI_USR_PATH}/lib/binfmt.d"
MKOSI_USR_BIN_PATH="${MKOSI_USR_PATH}/bin"

# Cleanup
rm -rf "${MKOSI_USR_BIN_PATH}/"
rm -rf "${MKOSI_BINFMT_PATH}/"

# Move files to mkosi.extra dir so they are coppied into the image
mkdir -p "${MKOSI_USR_BIN_PATH}/"

cp "./binfmt/bin/linux_${docker_arch}/usr/bin/qemu-${main_emu_arch}" "${MKOSI_USR_BIN_PATH}/qemu-${main_emu_arch}-static"
cp "./binfmt/bin/linux_${docker_arch}/usr/bin/qemu-i386" "${MKOSI_USR_BIN_PATH}/qemu-i386-static"
cp "./binfmt/bin/linux_${docker_arch}/usr/bin/qemu-arm" "${MKOSI_USR_BIN_PATH}/qemu-arm-static"

# /lib/ is a symlink to /usr/lib/ in Fedora
mkdir -p "${MKOSI_BINFMT_PATH}"
# based on the ${ARCH}, some of these files won't be generated so just re-use qemu-${main_emu_arch} every time
cp "./binfmt/bin/linux_${docker_arch}/lib/binfmt.d/qemu-${main_emu_arch}.conf" "${MKOSI_BINFMT_PATH}/qemu-${main_emu_arch}-static.conf"
cp "./binfmt/bin/linux_${docker_arch}/lib/binfmt.d/qemu-${main_emu_arch}.conf" "${MKOSI_BINFMT_PATH}/qemu-i386-static.conf"
cp "./binfmt/bin/linux_${docker_arch}/lib/binfmt.d/qemu-${main_emu_arch}.conf" "${MKOSI_BINFMT_PATH}/qemu-arm-static.conf"

sed -i "s|/usr/bin/qemu-${main_emu_arch}|/usr/bin/qemu-${main_emu_arch}-static|g" "${MKOSI_BINFMT_PATH}/qemu-${main_emu_arch}-static.conf"
sed -i "s|/usr/bin/qemu-${main_emu_arch}|/usr/bin/qemu-i386-static|g" "${MKOSI_BINFMT_PATH}qemu-i386-static.conf"
sed -i "s|/usr/bin/qemu-${main_emu_arch}|/usr/bin/qemu-arm-static|g" "${MKOSI_BINFMT_PATH}qemu-arm-static.conf"

# Cleanup
rm qemu-binfmt-conf.sh

cosign_version="2.2.4-1"
# This should match cosign_version ideally, but sometimes it doesn't
# see: https://github.com/sigstore/cosign/releases/tag/v2.2.3 release for example
cosign_release="2.2.4"
# see: https://github.com/docker/docker-credential-helpers/releases/tag/v0.8.2 release
docker_credential_helpers_release="0.8.2"

PKGDIR="./mkosi.extra/opt"
rm -rf "${PKGDIR}"
mkdir -p "${PKGDIR}"

curl -L \
  https://github.com/sigstore/cosign/releases/download/v"${cosign_release}"/cosign-"${cosign_version}"."${ARCH}".rpm \
  -o "${PKGDIR}/cosign.rpm"

PASS_CREDENTIAL_MGR_PATH="${MKOSI_USR_BIN_PATH}/docker-credential-pass"
rm -rf "${PASS_CREDENTIAL_MGR_PATH}"

curl -L https://github.com/docker/docker-credential-helpers/releases/download/v"${docker_credential_helpers_release}"/docker-credential-pass-v"${docker_credential_helpers_release}".linux-"${docker_arch}" \
     -o "${PASS_CREDENTIAL_MGR_PATH}"
chmod +x "${PASS_CREDENTIAL_MGR_PATH}"
sudo chown root:root "${PASS_CREDENTIAL_MGR_PATH}"

pushd ./al2023-build
rm -rf ./_output
rm -rf ./artifacts
# buildplatforms=("aarch64", "amd64")
# for buildplatform in "${buildplatforms[@]}"; do
# docker build --platform=linux/aarch64,linux/amd64 -t "al2023-build" .
docker build --platform="linux/$ARCH" -t "al2023-build" .
docker save al2023-build > al2023-build.tar
mkdir ./_output
tar -xvf al2023-build.tar -C ./_output

mkdir artifacts

blob_prefix="./_output/blobs/sha256/"
index_manifest=$(jq -r '.manifests[0].digest' ./_output/index.json | sed -e 's/^sha256://')
jq -r '.manifests[] |
  select(.platform.architecture == "amd64" or
         .platform.architecture == "arm64")
| .digest' "${blob_prefix}${index_manifest}" | while read image_manifest; do
  image_manifest_file="${blob_prefix}$(echo $image_manifest | sed -e 's/^sha256://')"
  layer_file="${blob_prefix}$(jq -r '.layers[0].digest' ${image_manifest_file} | sed -e 's/^sha256://' )"
  tar -xvf "${layer_file}" -C artifacts
done

find . -iregex "\./artifacts/fuse-sshfs-[0-9].*" -exec cp {} ../mkosi.extra/opt/ \;
find . -iregex "\./artifacts/cloud-init-[0-9].*" -exec cp {} ../mkosi.extra/opt/ \;
find . -iregex "\./artifacts/fuse-sshfs-[0-9].*${ARCH}.*" -exec cp {} ../mkosi.extra/opt/ \;

popd

./mkosi.sh --format disk --arch $mkosi_arch