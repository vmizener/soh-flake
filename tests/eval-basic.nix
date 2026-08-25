{ pkgs, home-manager, self }: let
  testHomeConfig = home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      self.homeManagerModules.default
      {
        home.username = "test";
        home.homeDirectory = "/home/test";
        home.stateVersion = "25.05";
        programs.shipofharkinian = {
          enable = true;
          gamepaths = [
            "/home/test/image1.z64"
            "/home/test/image2.z64"
          ];
        };
      }
    ];
  };
in
  testHomeConfig.activationPackage
