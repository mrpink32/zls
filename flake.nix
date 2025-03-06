{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgszig.url = "github:NixOS/nixpkgs/96c2125a8c56aad7a14b8d24e206fc0f61e2a520";
    #zig-overlay.url = "github:mitchellh/zig-overlay";
    #zig-overlay.inputs.nixpkgs.follows = "nixpkgs";

    gitignore.url = "github:hercules-ci/gitignore.nix";
    gitignore.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgszig,
    gitignore,
  }:
    builtins.foldl' nixpkgs.lib.recursiveUpdate {} (
      builtins.map
      (
        system: let
          pkgs = nixpkgs.legacyPackages.${system};
          zig = nixpkgszig.legacyPackages.${system}.zig_0_14;
          gitignoreSource = gitignore.lib.gitignoreSource;
          target = builtins.replaceStrings ["darwin"] ["macos"] system;
          revision = self;
        in {
          formatter.${system} = pkgs.alejandra;
          packages.${system} = rec {
            default = zls;
            zls = pkgs.stdenvNoCC.mkDerivation {
              name = "zls";
              version = "master";
              meta.mainProgram = "zls";
              src = gitignoreSource ./.;
              nativeBuildInputs = [zig];
              dontConfigure = true;
              dontInstall = true;
              doCheck = true;
              buildPhase = ''
                NO_COLOR=1 # prevent escape codes from messing up the `nix log`
                PACKAGE_DIR=${pkgs.callPackage ./deps.nix {zig = zig;}}
                zig build install --global-cache-dir $(pwd)/.cache --system $PACKAGE_DIR -Dtarget=${target} -Doptimize=ReleaseSafe --prefix $out
              '';
              checkPhase = ''
                zig build test --global-cache-dir $(pwd)/.cache --system $PACKAGE_DIR -Dtarget=${target}
              '';
            };
          };
        }
      )
      ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"]
    );
}
