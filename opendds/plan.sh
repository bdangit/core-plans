pkg_name=opendds
pkg_origin=core
pkg_version='3.12.1'
pkg_description="OpenDDS is an open source C++ implementation of the Object Management Group (OMG) Data Distribution Service (DDS). OpenDDS also supports Java bindings through JNI."
pkg_maintainer='The Habitat Maintainers <humans@habitat.sh>'
pkg_license=('opendds')
pkg_upstream_url="http://www.opendds.org"
pkg_source="https://github.com/objectcomputing/OpenDDS/archive/DDS-$pkg_version.tar.gz"
pkg_shasum=26a89188289c51493a654a55267aa7c0ee16d6e8358a006c27302a87d4448cc6
pkg_filename="DDS-$pkg_version.tar.gz"
pkg_deps=(
  core/gcc-libs
  core/glibc
  core/perl
)

pkg_build_deps=(
  core/gcc
  core/glib
  core/make
  core/perl
  core/coreutils
)

pkg_lib_dirs=(lib)
pkg_bin_dirs=(bin)
pkg_include_dirs=(include)

do_unpack() {
  do_default_unpack

  mv "$HAB_CACHE_SRC_PATH/OpenDDS-DDS-$pkg_version" "$HAB_CACHE_SRC_PATH/$pkg_dirname"
}

do_prepare() {
  fix_interpreter configure core/perl bin/perl
  fix_interpreter "bin/*.pl" core/perl bin/perl
  export JAVA_HOME="$(pkg_path_for core/jdk9)"
  export BOOST_ROOT="$(pkg_path_for core/boost)"
}

do_check() {
  source setenv.sh
  perl bin/auto_run_tests.pl
}

do_install() {
  fix_interpreter "ACE_wrappers/MPC/*.pl" core/perl bin/perl

  do_default_install
}
