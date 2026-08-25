{
  description = "Ship of Harkinian home-manager flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {self, nixpkgs, home-manager}: let
    systems = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    forAllSystems = nixpkgs.lib.genAttrs systems;

    mkPackages = system: import ./packages.nix {
      pkgs = import nixpkgs { inherit system; };
    };
  in {
    packages = forAllSystems (system: let
      syspkgs = mkPackages system;
    in rec {
      default = shipofharkinian-appimage;
      shipofharkinian-appimage = syspkgs.sohAppImage;
      shipofharkinian-launcher = syspkgs.sohLauncher;
    });

    checks = forAllSystems (system: {
      package-builds = (mkPackages system).sohLauncher;
    } // (import ./tests {
      inherit home-manager self;
      pkgs = import nixpkgs { inherit system; };
    }));

    homeManagerModules.default = {config, lib, pkgs, ...}: let
      cfg = config.programs.shipofharkinian;
      syspkgs = mkPackages pkgs.stdenv.hostPlatform.system;
    in {
      options.programs.shipofharkinian = {
        enable = lib.mkEnableOption "Ship of Harkinian";
        gamepaths = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = ''
            Absolute paths to legal image dumps to include with SoH.
            Images are copied into the SoH data directory.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        home.packages = [
          pkgs.appimage-run
          syspkgs.sohLauncher
        ];

        home.activation.shipofharkinian = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          datadir="${config.xdg.dataHome}/shipofharkinian"
          mkdir -p "$datadir"
          install -Dm755 "${syspkgs.sohAppImage}/soh.appimage" "$datadir/soh.appimage"

          ${lib.concatMapStringsSep "\n" (path: ''
            source=${lib.escapeShellArg path}
            target=$datadir/$(basename "$source")
            if [ ! -f "$source" ]; then
              echo "Image path does not exist: $source" >&2
              exit 1
            fi
            ln -sfn "$source" "$target"
          '') cfg.gamepaths}
        '';
        xdg.dataFile = {
          "applications/shipofharkinian.desktop".source = ./soh.desktop;
          "icons/hicolor/512x512/apps/shipofharkinian.png".source = ./soh.png;
        };
      };
    };
  };
}
