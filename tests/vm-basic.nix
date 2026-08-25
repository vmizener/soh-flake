{ pkgs, home-manager, self }: pkgs.testers.runNixOSTest {
  name = "shipofharkinian-hm-test";
  nodes.machine = { ... }: {
    imports = [ home-manager.nixosModules.home-manager ];
    virtualisation.qemu.options = [ "-machine" "accel=tcg" ];  # Run without hardware KVM
    users.users.test = {
      isNormalUser = true;
      home = "/home/test";
      uid = 1000;
    };
    # Pre-populate the dummy ROM so Home Manager activation succeeds on boot
    systemd.tmpfiles.rules = [
      "d /home/test 0700 test users - -"
      "f /home/test/test-image.z64 0644 test users - MOCK_ROM"
    ];

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      users.test = {
        imports = [ self.homeManagerModules.default ];
        home.stateVersion = "25.05";
        programs.shipofharkinian = {
          enable = true;
          gamepaths = [ "/home/test/test-image.z64" ];
        };
      };
    };
  };

  testScript = ''
    start_all()

    with subtest("Wait for Home Manager activation to finish"):
        machine.wait_for_unit("home-manager-test.service")

    with subtest("Verify file locations and links"):
        datadir = "/home/test/.local/share"
        machine.succeed(f"test -x {datadir}/shipofharkinian/soh.appimage")
        machine.succeed(f"test -L {datadir}/shipofharkinian/test-image.z64")
        machine.succeed(f"cmp -s /home/test/test-image.z64 {datadir}/shipofharkinian/test-image.z64")

    with subtest("Verify launcher script in PATH"):
        machine.succeed("su - test -c 'which ShipOfHarkinian'")
        machine.succeed(f"test -f {datadir}/applications/shipofharkinian.desktop")
  '';
}
