pkg_name=libsimdpp
pkg_origin=core
pkg_version=2.1
pkg_description="Portable header-only zero-overhead C++ low level SIMD library"
pkg_upstream_url=https://github.com/p12tic/libsimdpp
pkg_license=('Boost-1.0')
pkg_maintainer="The Habitat Maintainers <humans@habitat.sh>"
pkg_source="https://github.com/p12tic/libsimdpp/archive/v${pkg_version}.tar.gz"
pkg_filename="v${pkg_version}.tar.gz"
pkg_shasum=b0e986b20bef77cd17004dd02db0c1ad9fab9c70d4e99594a9db1ee6a345be93
pkg_deps=(
  core/gcc-libs
  core/glibc
)
pkg_build_deps=(
  core/python
  core/binutils
  core/cmake
  core/make
  core/gcc
)
pkg_lib_dirs=(lib)
pkg_include_dirs=(include)

BUILDDIR="build"

do_prepare() {
  mkdir -p "$BUILDDIR"
}

do_build() {
  cd "$BUILDDIR" || exit
  cmake \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    ..
  make test_insn
  make test_dispatcher
  make test_expr
  make create_dir_for_compile_fail
}

do_check() {
  cd "$BUILDDIR" || exit
  make test
}

do_install() {
  cd "$BUILDDIR" || exit
  make install
}
