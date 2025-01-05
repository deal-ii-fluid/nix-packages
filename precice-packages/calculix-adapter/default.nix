{ lib
, stdenv
, fetchFromGitHub
, fetchzip
, gcc
, gfortran
, pkg-config
, arpack
, lapack
, blas
, spooles
, libyamlcpp
, precice
, openmpi
, substituteAll
}:

let
  ccx_version = "2.20";
  ccx = fetchzip {
    urls = [
      "https://www.dhondt.de/ccx_2.20.src.tar.bz2"
      # Mirror fallback
      "https://web.archive.org/web/20240302101853if_/https://www.dhondt.de/ccx_2.20.src.tar.bz2"
    ];
    sha256 = "sha256-bCmG+rcQDJrcwDci/WOAgjfbhy1vxdD+wnwRlt/ovKo=";
  };
in
stdenv.mkDerivation rec {
  pname = "calculix-adapter";
  version = "${ccx_version}.0";

  src = fetchFromGitHub {
    owner = "precice";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-zyJ9VOpmjyBeettPWA3bFZIfyJuvs5D1nMxRcP5ySRY=";
  };

  # Tools needed at build-time only
  nativeBuildInputs = [
    # The C/C++ compiler from stdenv
    stdenv.cc
    # The Fortran compiler
    gfortran
    # HPC libraries needed for linking
    pkg-config
    arpack
    lapack
    blas
    spooles
    libyamlcpp
    precice
    openmpi
  ];

  # If you needed these at runtime, you'd put them in buildInputs or
  # propagatedBuildInputs, but typically the final binary is self-contained.
  buildInputs = [];

  # This is similar to patchShebangs or other approach from openmpi
  postPatch = ''
    # If the Makefile references /usr/local/bin/gcc or something else:
    substituteInPlace Makefile --replace "/usr/local/bin/gcc" "${stdenv.cc.cc}"
    # If it references /usr/local/bin/gfortran or something else:
    substituteInPlace Makefile --replace "/usr/local/bin/gfortran" "${gfortran}/bin/gfortran"

    # If you need to fix absolute references to mpifort in the Makefile:
    substituteInPlace Makefile --replace "mpifort" "${openmpi}/bin/mpifort"
  '';

  # We can echo which compilers are actually being used, for debugging
  buildPhase = ''
    echo "==== Debug: Using CC=${CC:-unset}, FC=${FC:-unset}, PATH=$PATH"
    mpifort --version || true
    # Now run "make -j" with the relevant flags
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
    cp bin/ccx_preCICE $out/bin/
    cp bin/ccx_2.20.a $out/lib/
  '';

  meta = with lib; {
    description = "preCICE-adapter for the CSM code CalculiX";
    homepage = "https://precice.org/adapter-calculix-overview.html";
    license = licenses.gpl3;
    maintainers = [ maintainers.conni2461 ];
    platforms = platforms.unix;
  };
}
