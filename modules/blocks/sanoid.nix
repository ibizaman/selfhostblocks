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
    pkgs.writers.makeScriptWriter
      {
        interpreter = lib.getExe pkgs.python3;
        check = pkgs.writeShellScript "check-sanoid-restore" ''
          set -e
          cp "$1" sanoid_restore.py
          cp ${../../test/blocks/sanoid_restore.py} test_restore.py
          ${lib.getExe pkgs.ruff} format --check sanoid_restore.py test_restore.py
          ${lib.getExe pkgs.ruff} check --select E,F,W --ignore E501 sanoid_restore.py test_restore.py
          ${lib.getExe pkgs.pyrefly} check --preset strict --python-interpreter-path ${lib.getExe pkgs.python3} sanoid_restore.py test_restore.py
          ${lib.getExe pkgs.python3} -m unittest --verbose test_restore
        '';
      }
      "/bin/${restoreScriptName name}"
      ''
        import argparse
        import subprocess
        import sys


        dataset = "${name}"


        class _ZFSError(Exception):
            pass


        def _run_command(cmd: list[str]) -> str:
            try:
                result = subprocess.run(
                    cmd,
                    check=True,
                    text=True,
                    capture_output=True,
                )
                return result.stdout.strip()
            except subprocess.CalledProcessError as e:
                raise _ZFSError(
                    f"Command failed: {' '.join(cmd)}\n"
                    f"Exit code: {e.returncode}\n"
                    f"stderr: {e.stderr.strip()}"
                ) from e


        def _list_snapshots() -> list[str]:
            """List all ZFS snapshots."""
            output = _run_command(["zfs", "list", "-H", "-t", "snapshot", dataset])
            if not output:
                return []
            return output.splitlines()


        def _restore_snapshot(snapshot: str, destroy_newer_snapshots: bool) -> None:
            """Rollback to a given snapshot."""
            snapshot_dataset, separator, snapshot_name = snapshot.partition("@")
            if (
                snapshot_dataset != dataset
                or separator != "@"
                or not snapshot_name
                or "@" in snapshot_name
            ):
                raise ValueError(f"Expected a snapshot of {dataset}: {dataset}@snapshot")

            print(f"Rolling back to snapshot: {snapshot}")
            command = ["zfs", "rollback"]
            if destroy_newer_snapshots:
                command.append("-r")
            command.append(snapshot)
            _run_command(command)
            print("Rollback completed successfully.")


        def _build_parser() -> argparse.ArgumentParser:
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
                "--destroy-newer-snapshots",
                action="store_true",
                help="Allow deletion of snapshots and bookmarks newer than the target",
            )
            restore_parser.add_argument(
                "snapshot",
                help="Snapshot name (e.g. pool/dataset@snapname)",
            )

            return parser


        def _main() -> None:
            parser = _build_parser()
            args = parser.parse_args()

            try:
                if args.command == "snapshots":
                    snapshots = _list_snapshots()
                    for s in snapshots:
                        print(s)
                elif args.command == "restore":
                    _restore_snapshot(args.snapshot, args.destroy_newer_snapshots)
                else:
                    parser.print_help()
                    sys.exit(1)

            except ValueError as e:
                parser.error(str(e))
            except _ZFSError as e:
                print(f"ERROR: {e}", file=sys.stderr)
                sys.exit(1)


        if __name__ == "__main__":
            _main()
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
