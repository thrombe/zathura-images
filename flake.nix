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

      za = with pkgs.unstable; stdenv.mkDerivation (finalAttrs: {
          pname = "zathura";
          version = "0.5.5";

          src = fetchFromGitLab {
            domain = "git.pwmt.org";
            owner = "pwmt";
            repo = "zathura";
            rev = finalAttrs.version;
            hash = "sha256-mHEYqgBB55p8nykFtvYtP5bWexp/IqFbeLs7gZmXCeE=";
          };

          outputs = ["bin" "man" "dev" "out" "lib"];

          # Flag list:
          # https://github.com/pwmt/zathura/blob/master/meson_options.txt
          mesonFlags = [
            "-Dmanpages=enabled"
            "-Dconvert-icon=enabled"
            "-Dsynctex=enabled"
            "-Dtests=disabled"
            # Make sure tests are enabled for doCheck
            # (lib.mesonEnable "tests" finalAttrs.finalPackage.doCheck)
            (lib.mesonEnable "seccomp" stdenv.hostPlatform.isLinux)
          ];

          nativeBuildInputs = [
            meson
            ninja
            pkg-config
            desktop-file-utils
            python3.pythonOnBuildForHost.pkgs.sphinx
            gettext
            wrapGAppsHook
            libxml2
            appstream-glib
          ];

          buildInputs =
            [
              gtk4
              girara
              libintl
              sqlite
              glib
              file
              librsvg
              check
              json-glib
              texlive.bin.core
            ]
            ++ lib.optional stdenv.isLinux libseccomp
            ++ lib.optional stdenv.isDarwin gtk-mac-integration;

          doCheck = !stdenv.isDarwin;
        });

      zathura-images = pkgs.stdenv.mkDerivation {
        name = "zathura-images";

        nativeBuildInputs = with pkgs; [
          pkg-config
          unstable.zig_0_12
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
