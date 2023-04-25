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
  in (pkgs.hixProject.flake {}) // {

    packages.x86_64-linux.default = self.packages.x86_64-linux.hello;

  };
}
