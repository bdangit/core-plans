#!/bin/sh

TESTDIR="$(dirname "${0}")"
PLANDIR="$(dirname "${TESTDIR}")"
SKIPBUILD=${SKIPBUILD:-0}

hab pkg install --binlink core/bats

source "${PLANDIR}/plan.sh"

if [ "${SKIPBUILD}" -eq 0 ]; then
  set -e
  pushd "${PLANDIR}" > /dev/null
  build
  source results/last_build.env
  hab pkg install --binlink --force "results/${pkg_artifact}"
  popd > /dev/null
  set +e
fi

bats "${TESTDIR}/test.bats"

#    llvm: Running post-compile tests
# /hab/cache/src/llvm-7.0.0/_build /hab/cache/src/llvm-7.0.0 /hab/cache/src /src/llvm
# [1/2] Running all regression tests
# llvm-lit: /hab/cache/src/llvm-7.0.0/_build/utils/lit/tests/lit.cfg:62: warning: Could not importpsutil. Some tests will be skipped and the --timeout command line argument will not work.
# Testing Time: 1908.63s
#   Expected Passes    : 25649
#   Expected Failures  : 142
#   Unsupported Tests  : 1227

# 1 warning(s) in tests.

#   llvm: Build time: 86m33s