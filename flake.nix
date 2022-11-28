{
  description = "Nix tools for building Liqwid projects";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?rev=334ec8b503c3981e37a04b817a70e8d026ea9e84";
    nixpkgs-latest.url = "github:NixOS/nixpkgs";
    nixpkgs-2205.url = "github:NixOS/nixpkgs/nixos-22.05";

    # temporary fix for nix versions that have the transitive follows bug
    # see https://github.com/NixOS/nix/issues/6013
    nixpkgs-2111.url = "github:NixOS/nixpkgs/nixpkgs-21.11-darwin";

    flake-parts.url = "github:hercules-ci/flake-parts";

    # On-chain deps
    haskell-nix-extra-hackage.url = "github:mlabs-haskell/haskell-nix-extra-hackage";
    haskell-nix-extra-hackage.inputs.haskell-nix.follows = "haskell-nix";
    haskell-nix-extra-hackage.inputs.nixpkgs.follows = "nixpkgs";
    haskell-nix.url = "github:input-output-hk/haskell.nix?rev=5eccdb523ce665f713f3c270aa8f45c23cc659c2";
    iohk-nix.url = "github:input-output-hk/iohk-nix/4848df60660e21fbb3fe157d996a8bac0a9cf2d6";
    iohk-nix.flake = false;

    ghc-next-packages.url = "github:input-output-hk/ghc-next-packages?ref=repo";
    ghc-next-packages.flake = false;

    haskell-language-server.url = "github:haskell/haskell-language-server";
    haskell-language-server.flake = false;
    # Plutarch and its friends
    plutarch.url = "github:Plutonomicon/plutarch-plutus?ref=emiflake/export-script-constructor";
  };

  outputs = { self, nixpkgs-2205, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit self; } {
      imports = [ ./nix/templates.nix ./nix/all-modules.nix ];
      systems = [ "x86_64-linux" "aarch64-darwin" "x86_64-darwin" "aarch64-linux" ];
      perSystem = { config, self', inputs', pkgs, lib, system, ... }:
        let
          pkgs2205 = import nixpkgs-2205 { inherit system; };
          utils = import ./nix/utils.nix { inherit pkgs lib; };
        in
        {
          devShells.default = pkgs.mkShell {
            name = "liqwid-nix dev shell";
            buildInputs = [
              pkgs2205.nixpkgs-fmt
            ];
          };
          formatter = pkgs2205.nixpkgs-fmt;

          # This check is for `liqwid-nix` itself.
          checks.nixFormat =
            utils.shellCheck "nixFormat" ./. { nativeBuildInputs = [ pkgs2205.nixpkgs-fmt ]; } ''
              find -name '*.nix' -not -path './dist*/*' -not -path './haddock/*' | xargs nixpkgs-fmt
            '';
        };
      flake = {
        config.hydraJobs = {
          packages = self.packages.x86_64-linux;
          checks = self.checks.x86_64-linux;
          devShells = self.devShells.x86_64-linux;
        };
      };
    };
}
