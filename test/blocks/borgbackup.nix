{ pkgs, lib, ... }:
let
  testLib = pkgs.callPackage ../common.nix { };

  commonTest =
    user:
    lib.shb.runNixOSTest {
      name = "borgbackup_backupAndRestore_${user}";

      nodes.machine =
        { config, ... }:
        {
          imports = [
            testLib.baseImports

            ../../modules/blocks/hardcodedsecret.nix
            ../../modules/blocks/borgbackup.nix
          ];

          shb.hardcodedsecret.A = {
            request = {
              owner = "root";
              group = "keys";
              mode = "0440";
            };
            settings.content = "secretA";
          };
          shb.hardcodedsecret.B = {
            request = {
              owner = "root";
              group = "keys";
              mode = "0440";
            };
            settings.content = "secretB";
          };

          shb.hardcodedsecret.passphrase = {
            request = config.shb.borgbackup.instances."testinstance".settings.passphrase.request;
            settings.content = "passphrase";
          };

          shb.borgbackup.instances."testinstance" = {
            settings = {
              enable = true;

              passphrase.result = config.shb.hardcodedsecret.passphrase.result;

              repository = {
                path = "/opt/repos/A";
                timerConfig = {
                  OnCalendar = "00:00:00";
                  RandomizedDelaySec = "5h";
                };
                # Those are not needed by the repository but are still included
                # so we can test them in the hooks section.
                secrets = {
                  A.source = config.shb.hardcodedsecret.A.result.path;
                  B.source = config.shb.hardcodedsecret.B.result.path;
                };
              };
            };

            request = {
              inherit user;

              sourceDirectories = [
                "/opt/files/A"
                "/opt/files/B"
              ];

              hooks.beforeBackup = [
                ''
                  echo $RUNTIME_DIRECTORY
                  if [ "$RUNTIME_DIRECTORY" = /run/borgbackup-backups-testinstance_opt_repos_A ]; then
                    if ! [ -f /run/secrets_borgbackup/borgbackup-backups-testinstance_opt_repos_A ]; then
                      exit 10
                    fi
                    if [ -z "$A" ] || ! [ "$A" = "secretA" ]; then
                      echo "A:$A"
                      exit 11
                    fi
                    if [ -z "$B" ] || ! [ "$B" = "secretB" ]; then
                      echo "B:$B"
                      exit 12
                    fi
                  fi
                ''
              ];
            };
          };
        };

      extraPythonPackages = p: [ p.dictdiffer ];
      skipTypeCheck = true;

      testScript =
        { nodes, ... }:
        let
          provider = nodes.machine.shb.borgbackup.instances."testinstance";
          backupService = provider.result.backupService;
          restoreScript = provider.result.restoreScript;
        in
        ''
          from dictdiffer import diff

          def list_files(dir):
              files_and_content = {}

              files = machine.succeed(f"""
              find {dir} -type f
              """).split("\n")[:-1]

              for f in files:
                  content = machine.succeed(f"""
                  cat {f}
                  """).strip()
                  files_and_content[f] = content

              return files_and_content

          def assert_files(dir, files):
              result = list(diff(list_files(dir), files))
              if len(result) > 0:
                  raise Exception("Unexpected files:", result)

          with subtest("Create initial content"):
              machine.succeed("""
              mkdir -p /opt/files/A
              mkdir -p /opt/files/B

              echo repoA_fileA_1 > /opt/files/A/fileA
              echo repoA_fileB_1 > /opt/files/A/fileB
              echo repoB_fileA_1 > /opt/files/B/fileA
              echo repoB_fileB_1 > /opt/files/B/fileB

              chown ${user}: -R /opt/files
              chmod go-rwx -R /opt/files
              """)

              assert_files("/opt/files", {
                  '/opt/files/B/fileA': 'repoB_fileA_1',
                  '/opt/files/B/fileB': 'repoB_fileB_1',
                  '/opt/files/A/fileA': 'repoA_fileA_1',
                  '/opt/files/A/fileB': 'repoA_fileB_1',
              })

          with subtest("First backup in repo A"):
              machine.succeed("systemctl start ${backupService}")

          with subtest("New content"):
              machine.succeed("""
              echo repoA_fileA_2 > /opt/files/A/fileA
              echo repoA_fileB_2 > /opt/files/A/fileB
              echo repoB_fileA_2 > /opt/files/B/fileA
              echo repoB_fileB_2 > /opt/files/B/fileB
              """)

              assert_files("/opt/files", {
                  '/opt/files/B/fileA': 'repoB_fileA_2',
                  '/opt/files/B/fileB': 'repoB_fileB_2',
                  '/opt/files/A/fileA': 'repoA_fileA_2',
                  '/opt/files/A/fileB': 'repoA_fileB_2',
              })

          with subtest("Delete content"):
              machine.succeed("""
              rm -r /opt/files/A /opt/files/B
              """)

              assert_files("/opt/files", {})

          with subtest("Restore initial content from repo A"):
              machine.succeed("""
              ${restoreScript} restore latest
              """)

              assert_files("/opt/files", {
                  '/opt/files/B/fileA': 'repoB_fileA_1',
                  '/opt/files/B/fileB': 'repoB_fileB_1',
                  '/opt/files/A/fileA': 'repoA_fileA_1',
                  '/opt/files/A/fileB': 'repoA_fileB_1',
              })
        '';

    };
in
{
  backupAndRestoreRoot = commonTest "root";
  backupAndRestoreUser = commonTest "nobody";
}
