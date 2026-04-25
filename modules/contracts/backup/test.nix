{
  pkgs,
  lib,
  shb,
}:
let
  inherit (lib)
    concatMapStringsSep
    getAttrFromPath
    mkIf
    optionalAttrs
    setAttrByPath
    ;
in
{
  name,
  providerRoot,
  modules ? [ ],
  username ? "me",
  sourceDirectories ? [
    "/opt/files/A"
    "/opt/files/B"
  ],
  settings ? { ... }: { }, # { filesRoot, config } -> attrset
  extraConfig ? null, # { filesRoot, username, config } -> attrset
}:
shb.test.runNixOSTest {
  inherit name;

  nodes.machine =
    { config, ... }:
    {
      imports = [ shb.test.baseImports ] ++ modules;

      config = lib.mkMerge [
        (setAttrByPath providerRoot {
          request = {
            inherit sourceDirectories;
            user = username;
          };
          settings = settings {
            inherit config;
            filesRoot = "/opt/files";
          };
        })
        (mkIf (username != "root") {
          users.users.${username} = {
            isSystemUser = true;
            extraGroups = [ "sudoers" ];
            group = "root";
          };
        })
        (optionalAttrs (extraConfig != null) (extraConfig {
          inherit username config;
          filesRoot = "/opt/files";
        }))
      ];
    };

  extraPythonPackages = p: [ p.dictdiffer ];
  skipTypeCheck = true;

  testScript =
    { nodes, ... }:
    let
      provider = (getAttrFromPath providerRoot nodes.machine).result;
    in
    ''
      from datetime import datetime, timedelta
      from dictdiffer import diff
      import re

      username = "${username}"
      sourceDirectories = [ ${concatMapStringsSep ", " (x: ''"${x}"'') sourceDirectories} ]

      def list_files(dir):
          files_and_content = {}

          files = machine.succeed(f"""find {dir} -type f""").split("\n")[:-1]

          for f in files:
              content = machine.succeed(f"""cat {f}""").strip()
              files_and_content[f] = content

          return files_and_content

      def assert_files(dir, files):
          result = list(diff(list_files(dir), files))
          if len(result) > 0:
              raise Exception("Unexpected files:", result)

      with subtest("Create initial content"):
          for path in sourceDirectories:
              machine.succeed(f"""
                  mkdir -p {path}
                  echo repo_fileA_1 > {path}/fileA
                  echo repo_fileB_1 > {path}/fileB

                  chown {username}: -R {path}
                  chmod go-rwx -R {path}
              """)

          for path in sourceDirectories:
              assert_files(path, {
                  f'{path}/fileA': 'repo_fileA_1',
                  f'{path}/fileB': 'repo_fileB_1',
              })

      with subtest("Initial snapshot"):
          out = machine.succeed("${provider.restoreScript} snapshots").splitlines()
          if len(out) != 0:
            raise Exception(f"Unexpected snapshots:\n{out}")

      with subtest("First backup in repo"):
          print(machine.succeed("systemctl cat ${provider.backupService}"))
          machine.succeed("systemctl start --wait ${provider.backupService}")

      with subtest("One snapshot"):
          out = machine.succeed("${provider.restoreScript} snapshots").splitlines()
          print(f"Found snapshots:\n{out}")
          if len(out) != 1:
            raise Exception(f"Unexpected snapshots:\n{out}")

      # To accomodate for snapshot orchestrators which keep only a given amount
      # of snapshots per unit of time, we set the time to now + 2h.
      new_date = (datetime.now() + timedelta(hours=2)).strftime("%Y-%m-%d %H:%M:%S")
      machine.succeed(f"timedatectl set-time '{new_date}'")

      with subtest("New content"):
          for path in sourceDirectories:
              machine.succeed(f"""
                echo repo_fileA_2 > {path}/fileA
                echo repo_fileB_2 > {path}/fileB
                """)

              assert_files(path, {
                  f'{path}/fileA': 'repo_fileA_2',
                  f'{path}/fileB': 'repo_fileB_2',
              })

      with subtest("Second backup in repo"):
          machine.succeed("systemctl start --wait ${provider.backupService}")

      with subtest("two snapshots"):
          out = machine.succeed("${provider.restoreScript} snapshots").splitlines()
          print(f"Found snapshots:\n{out}")
          if len(out) != 2:
              raise Exception(f"Unexpected snapshots:\n{out}")

      firstSnapshot = re.split("[ \t+]", out[0], maxsplit=1)[0]
      secondSnapshot = re.split("[ \t+]", out[1], maxsplit=1)[0]
      print(f"First snapshot {firstSnapshot}")
      print(f"Second snapshot {secondSnapshot}")

      with subtest("Delete content"):
          for path in sourceDirectories:
              machine.succeed(f"""rm -r {path}/*""")

              assert_files(path, {})

      with subtest("Restore second backup"):
          machine.succeed(f"${provider.restoreScript} restore {secondSnapshot}")

          for path in sourceDirectories:
              assert_files(path, {
                  f'{path}/fileA': 'repo_fileA_2',
                  f'{path}/fileB': 'repo_fileB_2',
              })

      with subtest("Restore first backup"):
          machine.succeed(f"${provider.restoreScript} restore {firstSnapshot}")

          for path in sourceDirectories:
              assert_files(path, {
                  f'{path}/fileA': 'repo_fileA_1',
                  f'{path}/fileB': 'repo_fileB_1',
              })
    '';
}
