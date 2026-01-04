#!/usr/bin/env bash

ping -c 1 www.google.com
if [ $? -eq 0 ]; then
    branch=master
    address='https://llvm.org/git'

    tools='llvm/tools'
    git clone -b $branch $address/clang $tools/clang

    ctools='llvm/tools/clang/tools'
    git clone -b $branch $address/clang-tools-extra $ctools/extra

    mkdir -p build/debug && cd build/debug
    cmake -G Ninja -DCMAKE_BUILD_TYPE=DEBUG  \
          -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
          -DLLVM_USE_SANITIZER="Address" \
         ../../llvm
    ninja
fi
