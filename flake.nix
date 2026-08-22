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

    soh = pkgs : pkgs.appimageTools.wrapType2 {
      pname = "ShipOfHarkinian";
      version = releaseInfo.version;
      src = let
        zip = pkgs.fetchzip {
          name = releaseInfo.name;
          url = "https://github.com/HarbourMasters/Shipwright/releases/download/${releaseInfo.version}/${releaseInfo.name}-Linux.zip";
          hash = releaseInfo.hash;
          stripRoot = false;
        };
      in "${zip}/soh.appimage";
      extraInstallCommands = ''
        install -Dm644 ${./soh.desktop} $out/share/applications/soh.desktop
      '';
    };
  in {
    packages = forAllSystems (system: let
      pkgs = import nixpkgs { inherit system; };
    in rec {
      shipofharkinian = soh pkgs;
      default = shipofharkinian;
    });

    checks = forAllSystems (system: let
      pkgs = import nixpkgs { inherit system; };
      package = soh pkgs;
    in {
      package-builds = package;
    });

    homeManagerModules.shipofharkinian = { config, lib, pkgs, ... }: let
      cfg = config.programs.shipofharkinian;
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
        home.packages = [ (soh pkgs) ];
        home.activation.shipofharkinianImages = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          data_dir="''${XDG_DATA_HOME:-$HOME/.local/share}/shipofharkinian"
          mkdir -p $data_dir
          ${lib.concatMapStringSep "\n" (path: ''
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
  };
}
