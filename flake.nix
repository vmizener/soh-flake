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
    release-info = import ./release-linux.nix;

    shipwright = pkgs : pkgs.appimageTools.wrapType2 rec {
      pname = release-info.name;
      version = release-info.version;
      src = pkgs.fetchurl {
        inherit pname version;
        hash = release-info.hash;
        url = release-info.asset;
      };
      extraInstallCommands = ''
        install -Dm644 ${./soh.desktop} $out/share/applications/soh.desktop
      '';
    };
  in {
    packages = forAllSystems (system: let
      pkgs = import nixpkgs { inherit system; };
    in rec {
      shipofharkinian = shipwright pkgs;
      default = shipofharkinian;
    });
    homeManagerModules.shipofharkinian = { config, lib, pkgs, ... }: let
      cfg = config.programs.shipofharkinian;
      package = shipwright pkgs;
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
        home.packages = [ package ];
      };
    };
  };
}
