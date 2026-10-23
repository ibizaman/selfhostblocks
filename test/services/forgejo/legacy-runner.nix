{
  config,
  lib,
  pkgs,
  ...
}:
let
  enabled = !config.shb.forgejo.localActionRunner;
in
{
  # Test-only snapshot of the legacy registration protocol. Keeping the CLI
  # invocation here lets this upgrade test run after nixpkgs changes its module.
  # https://github.com/NixOS/nixpkgs/blob/5e867b1db0f219e0e906574cca1175f421a87834/nixos/modules/services/continuous-integration/gitea-actions-runner.nix#L227-L278
  shb.forgejo.localActionRunner = lib.mkDefault false;

  systemd.services.forgejo.postStart = lib.mkIf enabled ''
    # Wait for the UNIX socket (-U) to accept connections without sending data (-z).
    while ! ${lib.getExe' pkgs.netcat-openbsd "nc"} -z -U ${config.services.forgejo.settings.server.HTTP_ADDR}; do
      sleep 1
    done
    sleep 2
    ${lib.getExe config.services.forgejo.package} actions generate-runner-token > /run/forgejo/legacy-runner-token
  '';

  systemd.services.gitea-runner-local = {
    enable = enabled;
    wantedBy = [ "multi-user.target" ];
    requires = [
      "forgejo.service"
      "nginx.service"
    ];
    after = [
      "forgejo.service"
      "nginx.service"
    ];
    path = config.shb.forgejo.hostPackages;
    preStart = ''
      mkdir -p "$STATE_DIRECTORY/local"
      cd "$STATE_DIRECTORY/local"
      if [ ! -e .runner ]; then
        ${lib.getExe pkgs.forgejo-runner} register --no-interactive \
          --instance http://${config.shb.forgejo.subdomain}.${config.shb.forgejo.domain} \
          --token "$(cat "$CREDENTIALS_DIRECTORY/token")" \
          --name local --labels native:host
      fi
    '';
    serviceConfig = {
      DynamicUser = true;
      User = "gitea-runner";
      StateDirectory = "gitea-runner";
      WorkingDirectory = "-/var/lib/gitea-runner/local";
      LoadCredential = "token:/run/forgejo/legacy-runner-token";
      ExecStart = "${lib.getExe pkgs.forgejo-runner} daemon";
      Restart = "on-failure";
    };
  };
}
