{
  coreutils,
  jq,
  lib,
  systemd,
  util-linux,
  writeShellApplication,
  registrationDir,
  identityDir,
  legacyDir,
  user,
}:
let
  # Follow nixpkgs' migration recipe, linked at extraction below. SHB adds input
  # validation and atomic publication, with all writes limited to the Forgejo user.
  importIdentity = writeShellApplication {
    name = "import-forgejo-runner-identity";
    runtimeInputs = [
      coreutils
      jq
    ];
    text = ''
      # Read the legacy .runner JSON from stdin, opened by root before switching to
      # the Forgejo user so this importer needs no privileged filesystem access.
      registration=$(cat)
      # Extract the existing identity as prescribed by the native module.
      # https://github.com/NixOS/nixpkgs/blob/5e867b1db0f219e0e906574cca1175f421a87834/nixos/modules/services/continuous-integration/forgejo-runner.nix#L102-L123
      # Validate the UUID format and nonempty token before creating any state.
      printf '%s' "$registration" | jq --exit-status '
        (.uuid | type == "string" and test("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"))
        and (.token | type == "string" and length > 0)
      ' > /dev/null

      # Restrict new files to the Forgejo user and create the private parent directory.
      umask 077
      install --directory --mode=0700 ${lib.escapeShellArg registrationDir}

      # Stage both credentials beside their destination so publication can be atomic.
      # Remove the staging directory on exit, including if extraction or publication fails.
      staging=$(mktemp --directory ${lib.escapeShellArg "${registrationDir}/migration.XXXXXX"})
      trap 'rm --recursive --force -- "$staging"' EXIT
      # Write each credential as raw text without a trailing newline for the native runner.
      for field in token uuid; do
        printf '%s' "$registration" | jq --join-output --arg field "$field" '.[$field]' > "$staging/$field"
      done
      # Publish both credentials and the completion record in one atomic rename.
      mv --no-target-directory "$staging" ${lib.escapeShellArg identityDir}
    '';
  };
in
writeShellApplication {
  name = "shb-forgejo-runner-migrate";
  runtimeInputs = [ systemd ];
  text = ''
    if (( EUID != 0 )); then
      echo "Run this one-time migration as root." >&2
      exit 1
    fi
    if [ -e ${lib.escapeShellArg identityDir} ]; then
      echo "Runner initialization is complete; migration will not run again. Restore missing credentials from backup." >&2
      exit 1
    fi
    if systemctl is-active --quiet gitea-runner-local.service forgejo-runner-local.service; then
      echo "Stop the runner services before migrating their identity." >&2
      exit 1
    fi
    legacy=${lib.escapeShellArg "${legacyDir}/.runner"}
    if [ -L ${lib.escapeShellArg legacyDir} ] || [ -L "$legacy" ]; then
      echo "Refusing to import a symlinked Forgejo runner registration." >&2
      exit 1
    fi
    # Only opening legacy state needs root. All writes beneath the Forgejo-owned
    # custom directory run as Forgejo, avoiding privileged writes through its paths.
    exec ${lib.getExe' util-linux "runuser"} --user ${lib.escapeShellArg user} -- ${lib.getExe importIdentity} < "$legacy"
  '';
}
