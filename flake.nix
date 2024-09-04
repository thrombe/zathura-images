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

      packages_without_hook = with pkgs; [
          pkg-config
          # - [river.nix nixpkgs](https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/applications/window-managers/river/default.nix#L41)
          unstable.zig_0_12
          unstable.zathura

          pango
          cairo
          girara

          # opencv
          unstable.imagemagick
      ];
      zathura-images = pkgs.stdenv.mkDerivation rec {
        name = "zathura-images";

        src = pkgs.lib.cleanSource ./.;

        installPhase = ''
          mkdir -p $out/lib/zathura
          mv ./zig-out/lib/lib${name}.so $out/lib/zathura/.

          mkdir -p $out/share/applications
          cp ./meta/*.desktop $out/share/applications/.
          mkdir -p $out/share/metainfo
          cp ./meta/*.metainfo.xml $out/share/metainfo/.
        '';

        nativeBuildInputs = [
          pkgs.unstable.zig_0_12.hook
        ] ++ packages_without_hook;
      };
      # - [Overriding | nixpkgs](https://ryantm.github.io/nixpkgs/using/overrides/)
      zathura-images-overlay = self: super: {
        zathura = super.zathura.override (prev: {
          plugins = (prev.plugins or []) ++ [zathura-images];
        });
        # zathura = super.zathura.overrideAttrs (finalAttrs: previousAttrs: {
        #   paths = previousAttrs.paths ++ [zathura-images];
        # });
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
      overlays = {
        default = zathura-images-overlay;
        zathura-images-overlay = zathura-images-overlay;
      };

      devShells.default =
        pkgs.mkShell.override {
          inherit stdenv;
        } {
          nativeBuildInputs = (env-packages pkgs) ++ [fhs] ++ packages_without_hook;
          inputsFrom = [
            # zathura-images
          ];
          shellHook = ''
            export PROJECT_ROOT="$(pwd)"
            export LIBCLANG_PATH="${pkgs.unstable.llvmPackages.libclang.lib}/lib";
            export CLANGD_FLAGS="--compile-commands-dir=$PROJECT_ROOT/plugin --query-driver=$(which $CXX)"
          '';
        };
    });
}
