{ pkgs, home-manager, self }: let
  # Evaluation checks
  mkEvalTest = path: import path {
    inherit pkgs home-manager self;
  };

  # VM integration tests
  mkVmTest = path: (import path {
    inherit pkgs home-manager self;
  }).overrideTestDerivation (_: {
    requiredSystemFeatures = [];
  });
in {
  # --- Evaluation Checks ---
  evalBasic = mkEvalTest ./eval-basic.nix;

  # --- VM Integration Checks ---
  vmBasic = mkVmTest ./vm-basic.nix;
}
