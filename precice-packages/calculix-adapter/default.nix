{ lib
, stdenv
, fetchFromGitHub
, fetchzip
, gcc
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

  # The preCICE CalculiX Adapter source
  src = fetchFromGitHub {
    owner = "precice";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-zyJ9VOpmjyBeettPWA3bFZIfyJuvs5D1nMxRcP5ySRY=";
  };

  # Tools / libs needed at build time
  nativeBuildInputs = [
    gcc
    pkg-config
    arpack
    lapack
    blas
    spooles
    libyamlcpp
    precice
    openmpi
  ];

  # 1) If the Makefile or code references `/usr/local/bin/gcc`, you can remove it:
  #    Substitute with "gcc" or the actual compiler from Nix if needed.
  #    If your Makefile does NOT reference /usr/local/bin/gcc, you can skip this.
  postPatch = ''
    substituteInPlace Makefile --replace "/usr/local/bin/gcc" "gcc" || true
    # If your Makefile references a hard-coded path to gfortran or mpifort, do similar replacements:
    # substituteInPlace Makefile --replace "/usr/local/bin/gfortran" "gfortran" || true
    # substituteInPlace Makefile --replace "/usr/local/bin/mpifort" "${openmpi}/bin/mpifort" || true
  '';

  # 2) Force the correct compilers / MPI wrappers so the Makefile doesn't try to guess
  #    a store path that might be a directory rather than a binary.
  buildPhase = ''
    echo "Build environment:"
    echo "  CC=$CC"
    echo "  FC=$FC"
    echo "  PATH=$PATH"

    # If you want to override the Makefile's default "CC", "FC", etc., you can export them:
    export CC="${gcc}/bin/gcc"                    # or stdenv.cc.cc
    export FC="${openmpi}/bin/mpifort"            # If the Fortran code is MPI-based
    # or export FC="${gcc}/bin/gfortran" if your code uses raw gfortran

    # Show which mpifort is being used
    mpifort --version || true

    # The actual build
    make -j $NIX_BUILD_CORES \
      CCX=${ccx}/ccx_2.20/src \
      SPOOLES_INCLUDE="-I${spooles}/include/spooles/" \
      ARPACK_INCLUDE="$(${pkg-config}/bin/pkg-config --cflags-only-I arpack lapack blas)" \
      ARPACK_LIBS="$(${pkg-config}/bin/pkg-config --libs arpack lapack blas)" \
      YAML_INCLUDE="$(${pkg-config}/bin/pkg-config --cflags-only-I yaml-cpp)" \
      YAML_LIBS="$(${pkg-config}/bin/pkg-config --libs yaml-cpp)" \
      ADDITIONAL_FFLAGS="-fallow-argument-mismatch"
  '';

  installPhase = ''
    mkdir -p "$out/bin" "$out/lib"
    cp bin/ccx_preCICE "$out/bin/"
    cp bin/ccx_2.20.a "$out/lib/"
  '';

  meta = {
    description = "preCICE-adapter for the CSM code CalculiX";
    homepage = "https://precice.org/adapter-calculix-overview.html";
    license = with lib.licenses; [ gpl3 ];
    maintainers = with lib.maintainers; [ conni2461 ];
    mainProgram = "ccx_preCICE";
    platforms = lib.platforms.unix;
  };
}
