{ }:

let
  # 这里我们通过 builtins.getFlake 拿到当前目录（./.）的 flake
  # 然后复用 flake.inputs.nixpkgs，这样就能保证使用和 flake.lock 对应版本的 nixpkgs
  flake = builtins.getFlake (toString ./.);

  # 如果你是 x86_64-linux，直接写死 "x86_64-linux"；
  # 若要对 aarch64-darwin 也兼容，可做更多判断或写个简单的 system 变量。
  pkgs = flake.inputs.nixpkgs.legacyPackages.x86_64-linux;
in
pkgs.mkShell {
  # 在这个 shell 里，预先安装 openmpi 和 gfortran
  buildInputs = [
    pkgs.openmpi
    pkgs.gfortran
		pkgs.gcc
  ];

  shellHook = ''
    echo "Entering shell with pinned nixpkgs (same as your flake.lock)."
    echo "Installed: openmpi + gfortran + gcc."
  '';
}
