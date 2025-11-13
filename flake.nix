{
  # Based on https://github.com/kristofvandam/flake-cinc-workstation
  description = "CINC Workstation Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    cinc-workstation.url = "https://downloads.cinc.sh/files/stable/cinc-workstation/25.9.1094/debian/13/cinc-workstation_25.9.1094-1_amd64.deb";
    cinc-workstation.flake = false;
  };

  outputs =
    { flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      debug = true;
      systems = [ "x86_64-linux" ];
      perSystem =
        {
          self',
          pkgs,
          lib,
          ...
        }:
        {
          packages = rec {
            cinc-workstation-sources = pkgs.stdenv.mkDerivation {
              name = "cinc-workstation";
              src = inputs.cinc-workstation;
              dpkg = pkgs.dpkg;
              rpath = lib.makeLibraryPath [ pkgs.libxcrypt-legacy ];
              builder = ./builder.sh;
            };
            cinc-workstation-run = pkgs.buildFHSEnv {
              name = "cinc-workstation-run";
              targetPkgs =
                pkgs: with pkgs; [
                  coreutils
                  glibc
                  cinc-workstation-sources
                ];
              extraBuildCommands = ''
                mkdir -p $out/opt
                ln -s ${cinc-workstation-sources}/cinc-workstation $out/opt/cinc-workstation
              '';
              runScript = "/opt/cinc-workstation/bin/cw-wrapper";
            };
            cinc-workstation = pkgs.stdenv.mkDerivation {
              name = "cinc";
              src = cinc-workstation-sources;
              buildInputs = [ cinc-workstation-run ];
              installPhase = ''
                mkdir -p $out/bin;
                for bin in $src/cinc-workstation/bin/*; do
                  echo -e "#!/usr/bin/env bash\n${cinc-workstation-run}/bin/cinc-workstation-run $(basename $bin) \"\$@\"" > $out/bin/$(basename $bin);
                  chmod +x $out/bin/$(basename $bin);

                  # also add a version where cinc- is replaced with chef- for compatibility
                  chef_bin=$(echo $(basename $bin) | sed 's/^cinc-/chef-/');
                  echo -e "#!/usr/bin/env bash\n${cinc-workstation-run}/bin/cinc-workstation-run $chef_bin \"\$@\"" > $out/bin/$chef_bin
                  chmod +x $out/bin/$chef_bin
                done
              '';
            };
          };

          devShells.default = pkgs.mkShell {
            buildInputs = [
              self'.packages.cinc-workstation
            ];

            shellHook = ''
              export PATH=${self'.packages.cinc-workstation}/bin:$PATH
            '';
          };
        };
    };
}
