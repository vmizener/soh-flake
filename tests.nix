{ self, pkgs, home-manager, ... }:

let
  testModule = {
    home.username = "test";
    home.homeDirectory = "/tmp/soh-test";
    home.stateVersion = "25.05";
    xdg.dataHome = "/tmp/soh-test/datadir";
    programs.shipofharkinian = {
      enable = true;
      gamepaths = [
        "/tmp/soh-test/image1"
        "/tmp/soh-test/image2"
      ];
    };
  };

  testHomeConfig = home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      self.homeManagerModules.default
      testModule
    ];
  };

  activationTest = pkgs.runCommand "test-shipofharkinian-activation" {
    nativeBuildInputs = [ pkgs.coreutils ];
  } ''
    export HOME="/tmp/soh-test"
    mkdir -p "$HOME"

    # Create dummy images
    echo "mario" > "$HOME/image1"
    echo "luigi" > "$HOME/image2"

    # Run the activation script
    ${testHomeConfig.config.home.activation.shipofharkinian.data}

    data_dir="${testHomeConfig.config.xdg.dataHome}"

    # 1. Assert soh.appimage was installed and is executable
    if [ ! -x "$data_dir/soh.appimage" ]; then
      echo "Error: soh.appimage missing or not executable in $data_dir" >&2
      exit 1
    fi

    # 2. Assert game image files were copied and match content
    for img in image1 image2; do
      if [ ! -f "$data_dir/$img" ] || ! cmp -s "$HOME/$img" "$data_dir/$img"; then
        echo "Error: $img missing or content mismatch in $data_dir" >&2
        exit 1
      fi
    done

    # 3. Indicate success with a result output
    touch "$out"
  '';
in {
  module = testModule;
  homeConfiguration = testHomeConfig;
  checks = {
    home-configuration = testHomeConfig.activationPackage;
    activation-test = activationTest;
  };
}
