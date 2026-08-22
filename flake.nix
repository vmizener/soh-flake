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

    soh = pkgs : pkgs.appimageTools.wrapType2 rec {
      pname = releaseInfo.name;
      version = releaseInfo.version;
      src = let
        zip = pkgs.fetchzip {
          name = pname;
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
        gamepath = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = ''
            Path to legal OOT dump.
          '';
        };
      };
      config = lib.mkIf cfg.enable {
        home.packages = [ (soh pkgs) ];
      };
    };
  };
}
