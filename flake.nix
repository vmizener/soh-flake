{
  description = "Ship of Harkinian home-manager flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager }: let
    systems = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    forAllSystems = nixpkgs.lib.genAttrs systems;
    releaseInfo = import ./release-linux.nix;

    sohInstaller = pkgs: let
      zip = pkgs.fetchzip {
        name = releaseInfo.name;
        url = "https://github.com/HarbourMasters/Shipwright/releases/download/${releaseInfo.version}/${releaseInfo.name}-Linux.zip";
        hash = releaseInfo.hash;
        stripRoot = false;
      };
    in pkgs.runCommand "soh-appimage" {} ''
      appimage="$(find ${zip} \
        -type f \
        -iname '*.appimage' \
        -print -quit)"
      if [ -z "$appimage" ]; then
        echo "failed to find appimage in zip archive" >&2
        find ${zip} -type f -print >&2
        exit 1
      fi
      mkdir -p "$out"
      install -Dm755 "$appimage" "$out/soh.appimage"
    '';

    defaultDataDir = "\${XDG_DATA_HOME:-$HOME/.local/share}/shipofharkinian";
    sohLauncher = pkgs: datadir: pkgs.writeShellApplication {
      name = "ShipOfHarkinian";
      runtimeInputs = [ pkgs.coreutils ];
      text = ''
        data_dir="${datadir}"
        appimage="$data_dir/soh.appimage"
        if [ ! -x "$appimage" ]; then
          echo "soh.appimage missing in data dir; run home manager activation first" >&2
          exit 1
        fi
        cd "$data_dir"
        appimage-run "$appimage"
      '';
    };
  in {
    packages = forAllSystems (system: let
      pkgs = import nixpkgs { inherit system; };
    in rec {
      shipinstaller = sohInstaller pkgs;
      shipofharkinian = sohLauncher pkgs defaultDataDir;
      default = shipofharkinian;
    });

    checks = forAllSystems (system: let
      pkgs = import nixpkgs { inherit system; };
      package = sohLauncher pkgs defaultDataDir;
      tests = import ./tests.nix { inherit self pkgs home-manager; };
    in {
      package-builds = package;
    } // (nixpkgs.lib.optionalAttrs (system == "x86_64-linux") tests.checks));

    homeManagerModules.shipofharkinian = { config, lib, pkgs, ... }: let
      cfg = config.programs.shipofharkinian;
      shipinstaller = sohInstaller pkgs;
      shipofharkinian = sohLauncher pkgs cfg.datadir;
    in {
      options.programs.shipofharkinian = {
        enable = lib.mkEnableOption "Ship of Harkinian";
        datadir = lib.mkOption {
          type = lib.types.str;
          default = defaultDataDir;
          description = ''
            Directory where SoH data will be stored.
          '';
        };
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
          shipofharkinian
        ];
        home.activation.shipofharkinianImages = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          # Install app image
          data_dir="${cfg.datadir}"
          mkdir -p "$data_dir"
          install -Dm755 \
            "${shipinstaller}/soh.appimage" \
            "$data_dir/soh.appimage"

          # Install desktop file
          apps_dir="''${XDG_DATA_HOME:-$HOME/.local/share}/applications";
          mkdir -p "$data_dir"
          install -Dm644 \
            "${./soh.desktop}" \
            "$apps_dir/soh.desktop"

          # Install game images
          ${lib.concatMapStringsSep "\n" (path: ''
            source=${lib.escapeShellArg path}
            target="$data_dir/$(basename "$source")"
            if [ ! -f "$source" ]; then
              echo "Image path does not exist" >&2
              exit 1
            fi
            if [ ! -e "$target" ] || ! cmp -s "$source" "$target"; then
              install -Dm644 "$source" "$target"
            fi
          '') cfg.gamepaths}
        '';
      };
    };

    homeConfigurations.test = (import ./tests.nix {
      inherit self home-manager;
      pkgs = import nixpkgs { system = "x86_64-linux"; };
    }).homeConfiguration;
  };
}
