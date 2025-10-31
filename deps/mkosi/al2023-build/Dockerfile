from public.ecr.aws/amazonlinux/amazonlinux:2023 as builder

workdir /work

arg FEDORA_VERSION
env FEDORA_VERSION=${FEDORA_VERSION:-43}
env FEDORA_KEY_NAME="/etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-$FEDORA_VERSION"

copy "RPM-GPG-KEY-fedora-$FEDORA_VERSION" $FEDORA_KEY_NAME

run dnf install -y 'dnf-command(download)' && \
    dnf install -y --allowerasing rpmdevtools rpm-build gnupg2 && \
    rpmdev-setuptree

run <<EOF cat >> "/etc/yum.repos.d/fedora$FEDORA_VERSION.repo"
[fedora]
name=Fedora $FEDORA_VERSION
metalink=https://mirrors.fedoraproject.org/metalink?repo=fedora-$FEDORA_VERSION&arch=\$basearch
enabled=1
countme=1
metadata_expire=7d
repo_gpgcheck=0
type=rpm
gpgcheck=1
gpgkey=file://$FEDORA_KEY_NAME
skip_if_unavailable=False

[fedora-source]
name=Fedora $FEDORA_VERSION - Source
metalink=https://mirrors.fedoraproject.org/metalink?repo=fedora-source-$FEDORA_VERSION&arch=\$basearch
enabled=1
metadata_expire=7d
repo_gpgcheck=0
type=rpm
gpgcheck=1
gpgkey=file://$FEDORA_KEY_NAME
skip_if_unavailable=False

EOF

run <<EOF cat >> "/etc/yum.repos.d/fedora-updates$FEDORA_VERSION.repo"
[fedora-updates]
name=Fedora $FEDORA_VERSION updates
metalink=https://mirrors.fedoraproject.org/metalink?repo=updates-released-f$FEDORA_VERSION&arch=\$basearch
enabled=1
countme=1
metadata_expire=7d
repo_gpgcheck=0
type=rpm
gpgcheck=1
gpgkey=file://$FEDORA_KEY_NAME
skip_if_unavailable=False

[fedora-updates-source]
name=Fedora $FEDORA_VERSION - Updates Source
metalink=https://mirrors.fedoraproject.org/metalink?repo=updates-released-source-f$FEDORA_VERSION&arch=\$basearch
enabled=1
repo_gpgcheck=0
type=rpm
gpgcheck=1
metadata_expire=6h
gpgkey=file://$FEDORA_KEY_NAME
skip_if_unavailable=False
EOF

# download the latest SRPM from Fedora repos
run dnf download \
    --repo fedora \
    --repo fedora-source \
    --repo fedora-updates \
    --repo fedora-updates-source \
    --source fuse-sshfs && \
    # disable all Fedora repos as to not use any fedora packages while building RPM
    dnf config-manager --set-disabled fedora* && \
    dnf download --source cloud-init

copy patches /work/patches

# build fuse-sshfs
run rpm -ivh fuse-sshfs*.src.rpm && \
    dnf builddep -y /root/rpmbuild/SPECS/fuse-sshfs*.spec && \
    rpmbuild --rebuild fuse-sshfs*.src.rpm

# # build cloud-init
run rpm -ivh cloud-init*.src.rpm && \
    patch -p1 /root/rpmbuild/SPECS/cloud-init.spec patches/cloud-init/0001-disable-mounts-module-patch.patch && \
    dnf builddep -y /root/rpmbuild/SPECS/cloud-init.spec && \
    rpmbuild -ba /root/rpmbuild/SPECS/cloud-init.spec
# /root/rpmbuild/RPMS/aarch64/fuse-sshfs-3.7.3-11.amzn2023.aarch64.rpm

from scratch

copy --from=builder /root/rpmbuild/RPMS/*/* /
