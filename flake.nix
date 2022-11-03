{
  inputs.flake-compat = {
    url = "github:edolstra/flake-compat";
    flake = false;
  };

  outputs = { self, nixpkgs, flake-utils, ...}@inputs:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system}.appendOverlays [ ];

        hPkgs = pkgs.haskell.packages."ghc924";

        hls =
          if system == "aarch64-darwin" then
            let #https://github.com/NixOS/nixpkgs/issues/194367
              hslWithoutPlugins = hPkgs.haskell-language-server.override  {
                hls-fourmolu-plugin = null;
                hls-ormolu-plugin = null;
              };
              disableCabalFlag = pkgs.haskell.lib.disableCabalFlag;
              hls = disableCabalFlag (disableCabalFlag hslWithoutPlugins "fourmolu") "ormolu";
            in hls
          else hPkgs.haskell-language-server;

        ghc = hPkgs.ghcWithPackages (ps: with ps; [ dhall dhall-json ]);
        hsDevTools = [
          ghc
          hls
          hPkgs.cabal-install
        ];
      in {
        #packages.default = hPkgs.callPackage greetingBuild {};
        devShells.default = pkgs.mkShell {

          buildInputs = hsDevTools;

          # Make external Nix c libraries like zlib known to GHC, like
          # pkgs.haskell.lib.buildStackProject does
          # https://github.com/NixOS/nixpkgs/blob/d64780ea0e22b5f61cd6012a456869c702a72f20/pkgs/development/haskell-modules/generic-stack-builder.nix#L38
          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [];

          # Configure the Nix path to our own `pkgs`, to ensure Stack-with-Nix uses the correct one rather than the global <nixpkgs> when looking for the right `ghc` argument to pass in `nix/stack-integration.nix`
          # See https://nixos.org/nixos/nix-pills/nix-search-paths.html for more information
          NIX_PATH = "nixpkgs=" + pkgs.path;
        };
      });
}
