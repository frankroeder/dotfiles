#!/usr/bin/env bash

cd llvm-top/

branch=master

git -C llvm pull
git -C llvm checkout $branch

git -C llvm/tools/clang pull
git -C llvm/tools/clang checkout $branch

git -C llvm/tools/clang/tools/extra pull 
git -C llvm/tools/clang/tools/extra checkout $branch 
