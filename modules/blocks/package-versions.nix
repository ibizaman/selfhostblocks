{ config, lib, ... }:
{
  options.package-versions = {
    enable = lib.mkEnableOption "displaying the package versions that have changed when rebuilding the system";
  };
  config = {
    system = {
      activationScripts = {
        diff-package-versions = lib.mkIf config.package-versions.enable {
          supportsDryActivation = true;
          text = ''
            if [ -e /run/current-system ] && [ -e $systemConfig ]; then
              echo
              echo "updated package versions:"
              echo
              ${lib.getExe config.nix.package} --extra-experimental-features nix-command store diff-closures /run/current-system $systemConfig || true
              echo
            fi
          '';
        };
      };
    };
  };
}
