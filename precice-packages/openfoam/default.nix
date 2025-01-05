{
  lib,
  stdenv,
  fetchgit,
  gnumake,
  openmpi,
  m4,
  zlib,
  flex,
  makeWrapper,
  writeScript,
  version,
  hash,
  scotch,
}: let
  # TODO: Can we make the last export to /run/current-system better somehow?
  set-vars-script = writeScript "set-openfoam-vars" ''
    export FOAM_API=${version}
    export WM_PROJECT=OpenFOAM
    export WM_PROJECT_VERSION=v${version}
    export FOAM_MPI=sys-openmpi
    export WM_MPLIB=SYSTEMOPENMPI
    export WM_LINK_LANGUAGE=c++
    export FOAM_EXT_LIBBIN=xx

    export BUILD_PLATFORM=linux
    export WM_COMPILER=Gcc
    export WM_COMPILER_LIB_ARCH=64
    export WM_COMPILER_TYPE=system
    export WM_COMPILE_OPTION=Opt
    export WM_LABEL_OPTION=Int32
    export WM_LABEL_SIZE=32
    export WM_PRECISION_OPTION=DP



    export WM_ARCH_OPTION=64
    export WM_OSTYPE=POSIX
    export FOAM_SIGFPE=


    export WM_ARCH=$BUILD_PLATFORM$WM_COMPILER_LIB_ARCH
    export WM_OPTIONS=$WM_ARCH$WM_COMPILER$WM_PRECISION_OPTION$WM_LABEL_OPTION$WM_COMPILE_OPTION

    export OPENFOAM_SRC_PATH=/build/OpenFOAM-9-d87800e

    export WM_PROJECT_DIR=$OPENFOAM_SRC_PATH

    export FOAM_APP=$OPENFOAM_SRC_PATH/applications
    export FOAM_ETC=$OPENFOAM_SRC_PATH/etc
    export FOAM_SRC=$OPENFOAM_SRC_PATH/src

    export FOAM_SOLVERS=$FOAM_APP/solvers
    export FOAM_UTILITIES=$FOAM_APP/utilities

    export FOAM_APPBIN=$OPENFOAM_SRC_PATH/platforms/$WM_OPTIONS/bin
    export FOAM_LIBBIN=$OPENFOAM_SRC_PATH/platforms/$WM_OPTIONS/lib

    export FOAM_USER_LIBBIN=/tmp/OpenFOAM/lib
    export FOAM_USER_APPBIN=/tmp/OpenFOAM/bin

    export WM_THIRD_PARTY_DIR=$OPENFOAM_SRC_PATH/ThirdParty
    export FOAM_TUTORIALS=$OPENFOAM_SRC_PATH/tutorials

    export WM_DIR=$OPENFOAM_SRC_PATH/wmake

    export PATH=$WM_DIR:$PATH
    export PATH=$FOAM_APPBIN:$PATH

    export WM_NCOMPPROCS=$NIX_BUILD_CORES
  
    export LD_LIBRARY_PATH=$FOAM_LIBBIN/dummy:$LD_LIBRARY_PATH
    export SCOTCH_VERSION=scotch_${scotch.version}
    export SCOTCH_ARCH_PATH=${scotch}
    export LD_LIBRARY_PATH=$SCOTCH_ARCH_PATH/lib:$LD_LIBRARY_PATH
    export LD_LIBRARY_PATH=$OPENFOAM_SRC_PATH/src/OpenFOAM/lnInclude:$LD_LIBRARY_PATH
    export LD_LIBRARY_PATH=/run/current-system/sw/lib/:$LD_LIBRARY_PATH
    export LD_LIBRARY_PATH=$FOAM_LIBBIN:$LD_LIBRARY_PATH
    export LD_LIBRARY_PATH=$FOAM_LIBBIN/$FOAM_MPI:$LD_LIBRARY_PATH
  '';

  # Fetch solids4foam source from GitHub (v2.1 branch).
  # Adjust the revision and hash to match the commit you want.
  solids4foamSrc = fetchgit {
    url    = "https://github.com/solids4foam/solids4foam.git";
    rev    = "e825b9a2d79441462c7efe946bff495cb8adef95";
    sha256 = "sha256-kty+ZxBHpp/QrQzy4uVQ5ecHHRw4OVIh8V2Owi7fvu0=";
  };



in
  stdenv.mkDerivation rec {
    pname = "openfoam";
    inherit version;

    src = fetchgit {
      url = "https://github.com/OpenFOAM/OpenFOAM-9.git";
      rev = "d87800e1bde07696061acb231ec68df126a937cc";
      inherit hash;
    };

    nativeBuildInputs = [
      gnumake
      m4
      makeWrapper
    ];
    buildInputs = [
      openmpi
      zlib
      flex
      scotch
    ];

    postPatch = ''
      patchShebangs --build wmake/scripts/wrap-lemon
      patchShebangs --build wmake/wmake
      patchShebangs --build wmake/wclean
      patchShebangs --build wmake/wmakeCollect
      patchShebangs --build wmake/wmakeLnIncludeAll
    '';

    buildPhase = ''
    # Step 1: Write the custom config for SCOTCH
    cat <<EOF > etc/config.sh/scotch
    export SCOTCH_VERSION=scotch_${scotch.version}
    export SCOTCH_ARCH_PATH=${scotch}
    EOF

    # Step 2: Install set-openfoam-vars script
    cp ${set-vars-script} bin/set-openfoam-vars

    # Step 3: Source the environment and build OpenFOAM
    source bin/set-openfoam-vars
    ./Allwmake -j -q

    # Step 4: Build solids4foam (with the same environment)
    echo "Building solids4foam..."
    # Copy solids4foam into build directory
    mkdir -p solids4foam
    cp -r ${solids4foamSrc}/* solids4foam


  # Fix permission and shebang inside solids4foam
    patchShebangs solids4foam
    chmod +x solids4foam/Allwmake

    # Build
    cd solids4foam
    source ../bin/set-openfoam-vars
    ./Allwmake -j
    '';

    installPhase = ''
      mkdir -p $out

      cp -r ./applications $out/
      cp -r ./bin $out/
      cp -r ./etc $out/
      cp -r ./platforms $out/
      cp -r ./src $out/
      cp -r ./tutorials $out/
      cp -r ./wmake $out/

      sed -i "s^/build/OpenFOAM-9-d87800e^$out^" $out/bin/set-openfoam-vars

    mkdir -p $out/solids4foam
    cp -r solids4foam $out/solids4foam/




    '';

    doInstallCheck = true;
    installCheckPhase = ''
      source $out/bin/set-openfoam-vars
    '';

    meta = {
      description = "OpenFOAM free, open source CFD software";
      homepage = "https://www.openfoam.com/";
      license = with lib.licenses; [gpl3];
      maintainers = with lib.maintainers; [cheriimoya];
      platforms = lib.platforms.unix;
    };
  }
