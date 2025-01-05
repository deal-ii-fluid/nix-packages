{ lib
, stdenv
, fetchFromGitHub
, fetchzip
, gcc
, gfortran  # explicitly bring in the Fortran compiler if needed
, pkg-config
, arpack
, lapack
, blas
, spooles
, libyamlcpp
, precice
, openmpi
}:
let
  ccx_version = "2.20";
  ccx = fetchzip {
    urls = [
      "https://www.dhondt.de/ccx_2.20.src.tar.bz2"
      "https://web.archive.org/web/20240302101853if_/https://www.dhondt.de/ccx_2.20.src.tar.bz2"
    ];
    hash = "sha256-bCmG+rcQDJrcwDci/WOAgjfbhy1vxdD+wnwRlt/ovKo=";
  };
in
stdenv.mkDerivation rec {
  pname = "calculix-adapter";
  version = "${ccx_version}.0";

  # Pull the preCICE CalculiX adapter from GitHub
  src = fetchFromGitHub {
    owner = "precice";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-zyJ9VOpmjyBeettPWA3bFZIfyJuvs5D1nMxRcP5ySRY=";
  };

  # Both stdenv.cc and gfortran are used, plus openmpi for mpifort
  nativeBuildInputs = [
    stdenv.cc
    gfortran
    pkg-config
    arpack
    lapack
    blas
    spooles
    libyamlcpp
    precice
    openmpi
  ];

  # Patch or override CC in the Makefile. This approach assumes the Makefile
  # respects the 'CC' variable. If it’s truly hard-coded, use substituteInPlace.

  # If the Makefile actually respects CC/FC environment variables, you can do:
   makeFlags = [
     "CC=${stdenv.cc.cc}"
     "FC=${gfortran}/bin/gfortran"
   ];

  buildPhase = ''
    echo "Using CC=${CC:-unset}, FC=${FC:-unset}"
    mpifort --version
    # Now run make. If the Makefile uses CC, it will have been patched.
    make -j \
      CCX=${ccx}/ccx_2.20/src \
      SPOOLES_INCLUDE="-I${spooles}/include/spooles/" \
      ARPACK_INCLUDE="$(${pkg-config}/bin/pkg-config --cflags-only-I arpack lapack blas)" \
      ARPACK_LIBS="$(${pkg-config}/bin/pkg-config --libs arpack lapack blas)" \
      YAML_INCLUDE="$(${pkg-config}/bin/pkg-config --cflags-only-I yaml-cpp)" \
      YAML_LIBS="$(${pkg-config}/bin/pkg-config --libs yaml-cpp)" \
      ADDITIONAL_FFLAGS="-fallow-argument-mismatch"
  '';

  installPhase = ''
    mkdir -p $out/{bin,lib}
    cp bin/ccx_preCICE $out/bin
    cp bin/ccx_2.20.a $out/lib
  '';

  meta = {
    description = "preCICE-adapter for the CSM code CalculiX";
    homepage = "https://precice.org/adapter-calculix-overview.html";
    license = with lib.licenses; [ gpl3 ];
    maintainers = with lib.maintainers; [ conni2461 ];
    mainProgram = "ccx_preCICE";
    # CalculiX is mostly for UNIX-like systems. If you want it on Darwin, you can
    # keep 'lib.platforms.all'. But typically it’s for Linux + maybe macOS/other unixes.
    platforms = lib.platforms.unix;
  };
}
