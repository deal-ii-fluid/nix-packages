# preCICE VM, solvers and adapters, built with Nix/NixOS

This repository is the result of a research project about reproducibility in scientific software with a case study on preCICE using the [Nix package manager](https://nixos.org/).
The value of this repo are the Nix package definitions of precice-adapters, several solvers and the preCICE distribution VM.
Those outputs can be built reproducibly using Nix.

<!-- The paper can be found here TODO add link to paper once it's published -->

## Structure of the repo

```
.
├── clean.sh                             # Script to undo execution of ./setup.sh
├── configuration-light.nix              #
├── configuration.nix                    # The definition of the preCICE VM
├── flake.lock                           # All dependencies pinned for Nix
├── flake.nix                            # Definitions of all inputs and outputs
├── precice-packages                     # Package definitions
│   ├── dune                             # Each package has its own directory
│   │   ├── 0001-no-upgrade.patch        # Some packages contain patch files so the package builds with Nix
│   │   ├── 0002-no-dune-configure.patch #
│   │   └── default.nix                  # default.nix is the file that contains the package definition
│   ├── ...                              # This goes on for each solver/adapter
│   └── default.nix                      # The precice-packages/default.nix represents a Nix overlay
├── precice-vm.qcow2                     # [not in git] This file us used to store all state of the VM and is created the first time the VM runs
├── README.md                            # This file
├── result                               # [not in git] Autogenerated symlink that points to the latest Nix build
├── setup.sh                             # File to setup and install Nix in a user context (no root required)
├── timings.md                           #
├── vagrant.pub                          # Vagrant public key
└── vscode.nix                           # Visual Studio Code for the VM
```

## Getting Started

To build the preCICE VM, the Nix binary is required.
We provide a [setup script](./setup.sh) to get the Nix package manager if it is not already available.
After that, you can use Nix to build the preCICE VM image, either as a bootable iso file, a qemu start script or a Vagrant VirtualBox VM image.

The first time you issue a Nix command inside the projects directory you are asked if you want to use the garnix cache.
To avoid building everything from scratch for yourself, you should definitely answer the prompt with yes here.
When enabled, Nix uses the garnix cache which contains all packages and images the flake contains as outputs.
Those outputs are built inside a CI job, so on every commit.

Using garnix only works if you use the `./setup.sh` script or the preCICE VM we provide, you shouldn't have to configure anything.
If you use a vanilla solution, please refer to [the section below](#notes-regarding-vanilla-nixnixos), but if there are any "out of the box" problems with the setup script or the VM, please open an issue.

```
# 0. If nix is not already available, we first need to download it
# The easiest way is to use the ./setup.sh script provided by the repo, otherwise please see https://nixos.org/download
bash ./setup.sh
# After the script succeeded the `nix-static` command should be available
# If installed via the official installer, the command `nix` should be available
# 1. inside this repository you can now run the following command to build a qemu VM image
nix build '.#vm'
# You can replace `vm` with
# - vm-light                 -- to build a lightweight qemu VM imsage
# - vagrant-vbox-image       -- to build a vagrant virtual box image
# - vagrant-vbox-image-light -- to build a vagrant virtual box image of the lightweight configuration
# - iso                      -- to build a bootable iso
# - iso-light                -- to build a bootable iso of the lightweight configuration
```

### Notes regarding vanilla Nix/NixOS

#### experimental-features

If you use vanilla Nix/NixOS, you need to enable experimental features, which can be enabled like so:

```plaintext
mkdir -p ~/.config/nix && echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf
```

For NixOS, you can also [set this option declaratively](https://github.com/precice/nix-packages/commit/4bc81bb0cd6f889ef4a08328bc79bddde98777fe#diff-7fb0d30826718de8f216d0f0a15452c87445e0bbb745754bf77e1320079f46f9R11).

#### Trusting the garnix cache

When you install NixOS or if you install Nix in multi-user mode, you additionally need to configure support for the garnix cache.
A single user installation (i.e. you run the `nix` binary directly without talking to the Nix daemon) should not be affected by this.

For security reasons, only https://cache.nixos.org is allowed as a binary cache by default and only the root user can use other binary caches.
There are several ways to solve this problem, you should choose only one (they are ordered by highest preference first).

For Nix in multi-user mode:
1. Add `substituters = https://cache.garnix.io` and `trusted-public-keys = cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g=` to your `nix.conf` file and restart the daemon
2. Add `trusted-users = @wheel` to your `nix.conf` file and restart the daemon
3. Run the command, `nix shell` for instance, as the root user using `sudo nix shell`

For NixOS:
1. Add [these two lines](https://github.com/precice/nix-packages/commit/4bc81bb0cd6f889ef4a08328bc79bddde98777fe#diff-7fb0d30826718de8f216d0f0a15452c87445e0bbb745754bf77e1320079f46f9R12-R13) to your `/etc/nixos/configuration.nix` and run `sudo nixos-rebuild switch`
2. Add your user or the wheel group to the [`trusted-users` setting](https://search.nixos.org/options?channel=23.05&show=nix.settings.trusted-users&from=0&size=50&sort=relevance&type=packages&query=nix.settings.trusted-users) by adding `nix.settings.trusted-users = [ "@wheel" ];` to your `/etc/nixos/configuration.nix` and running `sudo nixos-rebuild switch`
3. Run the command, `nix shell` for instance, as the root user using `sudo nix shell`

## Running the perpendicular-flap

Having Nix installed, you don't need to build the whole VM locally.
To run the perpendicular-flap tutorial, clone [the tutorials repository](https://github.com/precice/tutorials/), open two terminals and `cd` into the respective directories `perpendicular-flap/fluid-openfoam` and `perpendicular-flap/solid-calculix`.
In each of the shells run `nix shell github:precice/nix-packages#precice-calculix-adapter github:precice/nix-packages#precice-openfoam-adapter`.
The first time you run this, Nix will ask you, if you want to use the garnix cache, to which you should reply with `y` (otherwise OpenFOAM and CalculiX will be built locally).
Inside the solid-calculix directory, you can run `./run.sh` directly while in the fluid-openfoam directory, you have to issue the command `source "$(nix eval --raw 'github:precice/nix-packages#precice-openfoam-adapter.out')/bin/set-openfoam-adapter-vars"` before running the `./run.sh` script.

The simulation should run with both participants now.

## VirtualBox Vagrant image

To build and use the Vagrant image:
1. `nix build '.#vagrant-vbox-image'`, this will build the .box file and create a symlink `result` in the current directory
2. `vagrant box add ./result --name preCICE` to add the box
3. As usual, run `vagrant up`

To apply changes in the configuration.nix to the VM, you can run `sudo nixos-rebuild --flake /vagrant# switch` from within the VM.

## HPC Environment

This section is only relevant for the Simtech HPC of the University of Stuttgart.
It assumes a Linux installation.

In order to use the cluster, you have to apply, connect to the VPN, connect to a node via ssh and setup Nix.

1. Apply for the cluster

This won't be documented here.

2. Connect to the VPN:

Install `openconnect` and issue `sudo openconnect --user=st123456@stud.uni-stuttgart.de vpn.tik.uni-stuttgart.de`.
If `gopass` or another password store is installed, you can also let openconnect read the password from stdin: `gopass uni/st | sudo openconnect --user=st175425@stud.uni-stuttgart.de vpn.tik.uni-stuttgart.de --passwd-on-stdin`

3. Login via ssh

To make it easy to login, add the following to your `~/.ssh/config` file:

```sshconfig
# ~/.ssh/config
Host simtech-hpc
    Hostname ehlers-login.informatik.uni-stuttgart.de
    User st123456
```

4. Install Nix

Have a look at the `setup.sh` script in this repo and after understanding it, you can execute it on the simtech-hpc by running `bash setup.sh`.
This might take a few minutes.
Afterwards, you can use Nix by running `nix-static` (this might require you to open a new shell).
This also means, that in every command you want to use Nix, you'd have to substitute `nix` by `nix-static`.

5. Build the iso of the preCICE VM

Remember to use `nix-static` if you are running this on the simtech-hpc after installing nix via the `setup.sh` script.

`nix build '.#nixosConfigurations."precice-vm".config.system.build.iso'`

6. (Optional) Uninstall nix

Read, understand and run the `clean.sh` script in this repo.

Tip: You can disable the banner when logging in by executing a `touch ~/.hushlogin`.
