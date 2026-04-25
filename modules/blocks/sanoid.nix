{
  config,
  lib,
  pkgs,
  shb,
  utils,
  ...
}:
let
  cfg = config.shb.sanoid;

  restoreScriptName = name: "sanoid-${utils.escapeSystemdPath name}-restore";
  backupScriptBase = "sanoid";

  restoreScript =
    name:
    pkgs.writers.writePython3Bin (restoreScriptName name)
      {
        flakeIgnore = [ "E501" ];
      }
      ''
        import argparse
        import subprocess
        import sys


        dataset = "${name}"


        class ZFSError(Exception):
            pass


        def run_command(cmd: list[str]) -> str:
            try:
                result = subprocess.run(
                    cmd,
                    check=True,
                    text=True,
                    capture_output=True,
                )
                return result.stdout.strip()
            except subprocess.CalledProcessError as e:
                raise ZFSError(
                    f"Command failed: {' '.join(cmd)}\n"
                    f"Exit code: {e.returncode}\n"
                    f"stderr: {e.stderr.strip()}"
                ) from e


        def list_snapshots() -> None:
            """List all ZFS snapshots."""
            output = run_command(["zfs", "list", "-H", "-t", "snapshot", dataset])
            if not output:
                return []
            return output.splitlines()


        def restore_snapshot(snapshot: str) -> None:
            """Rollback to a given snapshot."""
            if not snapshot:
                raise ValueError("Snapshot name must not be empty")

            print(f"Rolling back to snapshot: {snapshot}")
            run_command(["zfs", "rollback", "-r", snapshot])
            print("Rollback completed successfully.")


        def build_parser() -> argparse.ArgumentParser:
            parser = argparse.ArgumentParser(description=f"Restore script for {dataset}")

            subparsers = parser.add_subparsers(dest="command", required=True)

            subparsers.add_parser(
                "snapshots",
                help="List all ZFS snapshots",
            )

            restore_parser = subparsers.add_parser(
                "restore",
                help="Rollback to a specific snapshot",
            )
            restore_parser.add_argument(
                "snapshot",
                help="Snapshot name (e.g. pool/dataset@snapname)",
            )

            return parser


        def main():
            parser = build_parser()
            args = parser.parse_args()

            try:
                if args.command == "snapshots":
                    snapshots = list_snapshots()
                    for s in snapshots:
                        print(s)
                elif args.command == "restore":
                    restore_snapshot(args.snapshot)
                else:
                    parser.print_help()
                    sys.exit(1)

            except ZFSError as e:
                print(f"ERROR: {e}", file=sys.stderr)
                sys.exit(1)
            except Exception as e:
                print(f"Unexpected error: {e}", file=sys.stderr)
                sys.exit(1)


        if __name__ == "__main__":
            main()
      '';
in
{
  imports = [
    ../../lib/module.nix
  ];

  options.shb.sanoid.backup = lib.mkOption {
    description = "Sanoid prodiver for file backup contract";
    default = { };
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, ... }:
        {
          options = shb.contracts.backup.mkProvider {
            resultCfg = {
              restoreScript = restoreScriptName name;
              restoreScriptText = restoreScriptName "<name>";

              backupService = "${backupScriptBase}.service";
              backupServiceText = "${backupScriptBase}.service";
            };

            settings = lib.mkOption {
              description = "Options passed to the `services.sanoid.datasets.<name>` option.";
              default = { };
              type = lib.types.attrsOf lib.types.anything;
            };
          };
        }
      )
    );
  };

  config = lib.mkIf (cfg.backup != { }) {
    services.sanoid.enable = true;

    services.sanoid.datasets =
      let
        mkDataset = name: cfg': {
          inherit name;
          value = cfg'.settings;
        };
      in
      lib.mapAttrs' mkDataset cfg.backup;

    environment.systemPackages = map restoreScript (lib.attrNames cfg.backup);
  };
}
