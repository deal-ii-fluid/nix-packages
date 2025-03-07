{
  lib,
  stdenv,
  fetchFromGitLab,
  bison,
  mpi,
  flex,
  zlib,
	gcc
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "scotch";
  version = "6.1.1";

  buildInputs = [
    bison
    mpi
    flex
    zlib
		gcc
  ];

  src = fetchFromGitLab {
    domain = "gitlab.inria.fr";
    owner = "scotch";
    repo = "scotch";
    rev = "v${finalAttrs.version}";
    hash = "sha256-GUV6s+P56OAJq9AMe+LZOMPICQO/RuIi+hJAecmO5Wc=";
  };

  preConfigure = ''
    cd src
    #ln -s Make.inc/Makefile.inc.x86-64_pc_linux2 Makefile.inc
    #cp Make.inc/Makefile.inc.x86-64_pc_linux2 Makefile.inc

    case "${stdenv.hostPlatform.system}" in
      x86_64-linux)
        cp Make.inc/Makefile.inc.x86-64_pc_linux2 Makefile.inc
        ;;
      aarch64-darwin)
        cp Make.inc/Makefile.inc.i686_mac_darwin10 Makefile.inc
        ;;
      *)
        echo "Unsupported platform: ${stdenv.hostPlatform.system}"
        exit 1
        ;;
    esac



    # 启用共享库的构建
    sed -i 's/^LIB.*=.*/LIB       = .so/' Makefile.inc
    sed -i 's/^CCS.*=.*/CCS       = $(CC) -fPIC/' Makefile.inc
    sed -i 's/^CCP.*=.*/CCP       = $(CC) -shared/' Makefile.inc
  '';

  buildFlags = [ "scotch ptscotch" ];

  installFlags = [ "prefix=\${out}" ];

  meta = {
    description = "Graph and mesh/hypergraph partitioning, graph clustering, and sparse matrix ordering";
    longDescription = ''
      Scotch is a software package for graph and mesh/hypergraph partitioning, graph clustering,
      and sparse matrix ordering.
    '';
    homepage = "http://www.labri.fr/perso/pelegrin/scotch";
    license = lib.licenses.cecill-c;
    maintainers = [ lib.maintainers.bzizou ];
    platforms = lib.platforms.unix;
  };
})
