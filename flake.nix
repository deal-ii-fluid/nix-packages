{
  description = "Flake for the preCICE-Nix research project with Darwin + Linux support";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-23.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # This allows us to use the garnix binary cache which the GitHub CI job
  # copies the binaries to, so we don't have to build anything locally
  nixConfig = {
    extra-substituters = [ "https://cache.garnix.io" ];
    extra-trusted-public-keys = [ "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g=" ];
  };

  outputs = { self, nixpkgs, home-manager, nixos-generators }:
    let
      # List all systems you want to support
      supportedSystems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];

      # Helper for iterating over systems in packages, devShells, apps, etc.
      forAllSystems = f: builtins.listToAttrs (builtins.map (system: {
        name = system; 
        value = f system;
      }) supportedSystems);

      # Function to import nixpkgs + your overlay for each system
      pkgsFor = system: import nixpkgs {
        inherit system;
        overlays = import ./precice-packages;
        config.allowUnfree = true;
        config.permittedInsecurePackages = [ "hdf5-1.10.9" ];
      };

      # Extract your overlay's package names
      precicePackageNames = builtins.attrNames (
        (builtins.elemAt (import ./precice-packages) 1) null { callPackage = { }; }
      );

      # Expand your overlay packages into an attrset { name = pkgs.name; } for each
      preciceOverlayPackages = pkgs:
        pkgs.lib.genAttrs precicePackageNames (name: pkgs.${name});

      ################################################################################
      # NixOS-only definitions (x86_64-linux)
      ################################################################################
      preciceSystemLight = {
        system = "x86_64-linux";
        modules = [
          home-manager.nixosModules.home-manager
          ./configuration-light.nix
        ];
      };

      preciceSystemVirtualboxLight = preciceSystemLight // {
        modules = preciceSystemLight.modules ++ [
          {
            virtualbox = {
              memorySize = 2048;
              vmName = "preCICE-VM";
              params = {
                cpus = 2;
                vram = 64;
                graphicscontroller = "vmsvga";
              };
            };
          }
        ];
      };

      preciceSystem = {
        system = "x86_64-linux";
        modules = [
          home-manager.nixosModules.home-manager
          ./configuration.nix
        ];
      };

      preciceSystemVm = {
        system = "x86_64-linux";
        modules = [
          home-manager.nixosModules.home-manager
          ./configuration.nix
          {
            virtualisation.memorySize = 4096;
            virtualisation.diskSize = 4096;
          }
        ];
      };

      preciceSystemVirtualbox = preciceSystem // {
        modules = preciceSystem.modules ++ [
          {
            virtualbox = {
              memorySize = 2048;
              vmName = "preCICE-VM";
              params = {
                cpus = 2;
                vram = 64;
                graphicscontroller = "vmsvga";
              };
            };
          }
        ];
      };
    in rec {
      ##############################################################################
      # 1) nixosConfigurations (x86_64-linux only)
      ##############################################################################
      nixosConfigurations.precice-vm =
        nixpkgs.lib.nixosSystem preciceSystem;

      ##############################################################################
      # 2) packages for all systems
      #    - On x86_64-linux: provide iso, vm, vagrant images
      #    - On Darwin: provide a basic set or placeholders
      ##############################################################################
      packages = forAllSystems (system:
        let
          pkgs = pkgsFor system;

          # Base packages we always provide
          basePackages =
            { inherit (pkgs) precice; }
            // preciceOverlayPackages pkgs;   # your overlayed packages
        in
        if system == "x86_64-linux" then
          basePackages // {
            iso = nixos-generators.nixosGenerate (preciceSystem // { format = "iso"; });
            iso-light = nixos-generators.nixosGenerate (preciceSystemLight // { format = "iso"; });
            vagrant-vbox-image = nixos-generators.nixosGenerate (
              preciceSystemVirtualbox // { format = "vagrant-virtualbox"; }
            );
            vagrant-vbox-image-light = nixos-generators.nixosGenerate (
              preciceSystemVirtualboxLight // { format = "vagrant-virtualbox"; }
            );
            vm = nixos-generators.nixosGenerate (preciceSystemVm // { format = "vm"; });
            vm-light = nixos-generators.nixosGenerate (preciceSystemLight // { format = "vm"; });
          }
        else
          # On Darwin, there's no NixOS, so no iso/vm to export.
          # Provide only the base packages (no images).
          basePackages
      );

      ##############################################################################
      # 3) apps for all systems
      #    - On x86_64-linux: runs the VM script
      #    - On Darwin: show a placeholder message
      ##############################################################################
      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = if system == "x86_64-linux" then
            "${self.packages.${system}.vm}/bin/run-precice-vm-vm"
          else
            ''
            echo "Not supported on ${system}."
            echo "You can still use `nix develop` or `nix shell` for packages."
            exit 1
            '';
        };
      });

      ##############################################################################
      # 4) devShells for all systems
      ##############################################################################
      devShells = forAllSystems (system:
        let
          pkgs = pkgsFor system;
          # Some environment logic from your config
          systemPackages = import ./configuration.nix {
            inherit pkgs;
            inherit (nixpkgs) lib;
            config = null;
          };
        in
          pkgs.mkShell {
            buildInputs = systemPackages.environment.systemPackages;
            shellHook = ''
              # If these packages exist on Darwin, they might or might not work.
              # If any break, consider conditionals: `if pkgs.stdenv.isDarwin then ...`
              source ${pkgs.openfoam}/bin/set-openfoam-vars || true
              source ${pkgs.precice-dune}/bin/set-dune-vars || true
              export LD_LIBRARY_PATH=${pkgs.precice-openfoam-adapter}/lib:$LD_LIBRARY_PATH
            '';
          }
      );
    };
}
