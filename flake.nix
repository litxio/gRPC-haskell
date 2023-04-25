{
  description = "A very basic flake";
  inputs.haskellNix.url = "haskellNix"; # This uses the registry. old way was  "github:input-output-hk/haskell.nix"
  inputs.nixpkgs.follows = "haskellNix/nixpkgs-2211";

  outputs = { self, nixpkgs, haskellNix }:
  let 
    system = "x86_64-linux";
    tools =
      {
        cabal = {
          version = "latest";
        };
        hlint = {
          version = "latest";
        };
        haskell-language-server = {
          version = "1.9.1.0";
        };
      };
    overlays =
      [
        haskellNix.overlay
        (final: prev: {
          hixProject = final.haskell-nix.cabalProject' {
            src = ./.;
            evalSystem = "x86_64-linux";

            compiler-nix-name = "ghc944";         # Also update in cabal.project
            shell.tools = tools;
            #shell.withHoogle = true;
          };
        })
      ];
    pkgs = import nixpkgs { inherit system overlays; inherit (haskellNix) config; };
    flake = pkgs.hixProject.flake {};
  in {
    flx = flake;
    legacyPackages.x86_64-linux = pkgs;

    packages.x86_64-linux.default = flake.packages."grpc-haskell:lib:grpc-haskell";
    defaultPackage = self.packages.x86_64-linux.default;
    devShells.x86_64-linux.default  = flake.devShell;
    devShells.x86_64-linux.testing  = pkgs.haskell-nix.haskellPackages.ghcWithPackages(ps: with ps;
      [grpc-haskell proto3-wire proto3-suite ]);
    compile-proto-file = flake.packages."proto3-suite:exe:compile-proto-file";

    apps."${system}".compile-proto-file = {
      type = "app";
      program = "${self.compile-proto-file}/bin/compile-proto-file";
    };
  };
}
