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
  datasets = map (job: job.request.dataset) (lib.attrValues cfg.backup);

  restoreScriptName = name: "sanoid-${utils.escapeSystemdPath name}-restore";
  backupScriptBase = "sanoid";

  restoreScript =
    name: dataset:
    pkgs.writers.writePython3Bin (restoreScriptName name)
      {
        flakeIgnore = [ "E501" ];
      }
      ''
        import argparse
        import subprocess
        import sys


        dataset = ${builtins.toJSON dataset}


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
    description = "Sanoid provider for the dataset backup contract";
    default = { };
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, ... }:
        {
          options = shb.contracts.datasetbackup.mkProvider {
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
    assertions =
      (lib.mapAttrsToList (name: job: {
        assertion = job.request.dataset != "";
        message = "shb.sanoid.backup.${name}.request.dataset must name the dataset, including its pool.";
      }) cfg.backup)
      ++ [
        {
          assertion = lib.length datasets == lib.length (lib.unique datasets);
          message = "Each shb.sanoid.backup job must request a different dataset; combine settings for duplicate targets in one job.";
        }
      ];

    services.sanoid.enable = true;

    services.sanoid.datasets =
      let
        mkDataset = _: cfg': {
          name = cfg'.request.dataset;
          value = cfg'.settings;
        };
      in
      lib.mapAttrs' mkDataset cfg.backup;

    environment.systemPackages = lib.mapAttrsToList (
      name: job: restoreScript name job.request.dataset
    ) cfg.backup;
  };
}
