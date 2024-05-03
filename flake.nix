{
  description = "yaaaaaaaaaaaaaaaaaaaaa";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    zls = {
      url = "github:zigtools/zls/0.12.0";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs = inputs:
    inputs.flake-utils.lib.eachDefaultSystem (system: let
      flakePackage = flake: package: flake.packages."${system}"."${package}";
      flakeDefaultPackage = flake: flakePackage flake "default";

      pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [
          (final: prev: {
            unstable = import inputs.nixpkgs-unstable {
              inherit system;
            };
          })
        ];
      };

      zathura-images = pkgs.stdenv.mkDerivation {
        name = "zathura-images";

        src = pkgs.lib.cleanSource ./.;

        nativeBuildInputs = with pkgs; [
          pkg-config
          unstable.zig_0_12.hook
          unstable.zathura

          pango
          cairo
          girara
          # za

          # opencv
          imagemagick
        ];
      };

      fhs = pkgs.buildFHSEnv {
        name = "fhs-shell";
        targetPkgs = p: (env-packages p) ++ (custom-commands p);
        runScript = "${pkgs.zsh}/bin/zsh";
        profile = ''
          export FHS=1
          # source ./.venv/bin/activate
          # source .env
        '';
      };
      custom-commands = pkgs: [
      ];

      env-packages = pkgs:
        with pkgs;
          [
            # unstable.zls
            (flakeDefaultPackage inputs.zls)
          ]
          ++ (custom-commands pkgs);

      stdenv = pkgs.clangStdenv;
      # stdenv = pkgs.gccStdenv;
    in {
      packages = {
        default = zathura-images;
        inherit zathura-images;
      };

      devShells.default =
        pkgs.mkShell.override {
          inherit stdenv;
        } {
          nativeBuildInputs = (env-packages pkgs) ++ [fhs];
          inputsFrom = [
            zathura-images
          ];
          shellHook = ''
            export PROJECT_ROOT="$(pwd)"
            export LIBCLANG_PATH="${pkgs.unstable.llvmPackages.libclang.lib}/lib";
            export CLANGD_FLAGS="--compile-commands-dir=$PROJECT_ROOT/plugin --query-driver=$(which $CXX)"
          '';
        };
    });
}
