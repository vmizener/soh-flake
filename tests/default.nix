{
  pkgs,
  home-manager,
  self,
}:
let
  # Evaluation checks
  mkEvalTest =
    path:
    import path {
      inherit pkgs home-manager self;
    };

  # VM integration tests
  mkVmTest =
    path:
    (import path {
      inherit pkgs home-manager self;
    }).overrideTestDerivation
      (_: {
        requiredSystemFeatures = [ ]; # Omit kvm requirement
      });
in
rec {
  fast = {
    evalBasic = mkEvalTest ./eval-basic.nix;
    evalCustomDatadir = mkEvalTest ./eval-custom-datadir.nix;
  };

  vm = {
    vmBasic = mkVmTest ./vm-basic.nix;
  };

  all = fast // vm;
}
