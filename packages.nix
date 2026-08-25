{pkgs}: let
  releaseInfo = import ./release-linux.nix;

  sohAppImage = pkgs.stdenvNoCC.mkDerivation {
    pname = "shipofharkinian-appimage";
    version = "latest";
    src = pkgs.fetchzip {
      name = releaseInfo.name;
      url =
        "https://github.com/HarbourMasters/Shipwright/releases/download/"
        + releaseInfo.version
        + releaseInfo.name
        + "-Linux.zip";
      hash = releaseInfo.hash;
      stripRoot = false;
    };
    dontConfigure = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      appimage="$(find . -type f -iname '*.appimage' -print -quit)"
      if [ -z "$appimage" ]; then
        echo "AppImage missing from source archive" >&2
        exit 1
      fi
      install -Dm755 "$appimage" "$out/soh.appimage"
      runHook postInstall
    '';
  };
  sohLauncher = pkgs.writeShellScriptBin "ShipOfHarkinian" ''
    set -eu

    data_home="''${XDG_DATA_HOME:-$HOME/.local/share}"
    appimage="$data_home/shipofharkinian/soh.appimage"
    if [ ! -x "$appimage" ]; then
      echo "AppImage missing in data dir; run home manager activation first" >&2
      exit 1
    fi
    exec ${pkgs.appimage-run}/bin/appimage-run "$appimage" "$@"
  '';
in {
  inherit sohAppImage sohLauncher;
}
