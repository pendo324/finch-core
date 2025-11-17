#!/bin/bash

set -eux

git clone https://github.com/systemd/mkosi
pushd mkosi
git checkout 489c5e9ecc9f1185ef64636c5c29d8d0e59746e0
git apply ./../deps/mkosi/0001-Add-support-for-Amazon-Linux-2023.patch
popd
mkdir -p "$HOME/.local/bin"
ln -s $PWD/mkosi/bin/mkosi ~/.local/bin/mkosi
echo "export PATH=$HOME/.local/bin:$PATH" >> ~/.bashrc
export PATH="$HOME/.local/bin:$PATH"

mkosi --version
