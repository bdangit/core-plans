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

# 133/134] Running the Clang regression tests
# llvm-lit: /hab/pkgs/bdangit/llvm/7.0.0/20181009045548/src/utils/lit/lit/llvm/config.py:331: note: using clang: /hab/cache/src/clang-7.0.0/_build/bin/clang
# Testing Time: 1141.55s
#   Expected Passes    : 12867
#   Expected Failures  : 19
#   Unsupported Tests  : 89
