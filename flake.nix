{
  description = "A very basic flake";
  inputs.haskellNix.url = "haskellNix"; # This uses the registry. old way was  "github:input-output-hk/haskell.nix"
  inputs.nixpkgs.follows = "haskellNix/nixpkgs-2211";

  outputs = { self, nixpkgs, haskellNix }:
  let 
    system = "x86_64-linux";
    overlays =
      [
        haskellNix.overlay
        (final: prev: {
          hixProject = final.haskell-nix.cabalProject' {
            src = ./.;
            evalSystem = "x86_64-linux";

            compiler-nix-name = "ghc944";         # Also update in cabal.project
            shell = {
              tools = {
                cabal = {
                  version = "latest";
                };
              };

              buildInputs = [ pkgs.grpc ];
            };
          };
        })
      ];
    pkgs = import nixpkgs { inherit system overlays; };
    flake = pkgs.hixProject.flake {};
  in flake // {
    fux = flake;

    packages.x86_64-linux.default = flake.packages."grpc-haskell:lib:grpc-haskell";

  };
}
