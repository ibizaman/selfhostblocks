{ pkgs, lib, ... }:
let
  pkgs' = pkgs;

  testLib = pkgs.callPackage ../common.nix {};
  shblib = pkgs.callPackage ../../lib {};

  base = testLib.base [
    ../../modules/blocks/restic.nix
  ];

  commonTestScript = ''
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

        # chown :backup -R /opt/files
        """)

        assert_files("/opt/files", {
            '/opt/files/B/fileA': 'repoB_fileA_1',
            '/opt/files/B/fileB': 'repoB_fileB_1',
            '/opt/files/A/fileA': 'repoA_fileA_1',
            '/opt/files/A/fileB': 'repoA_fileB_1',
        })

    with subtest("First backup in repo A"):
        machine.succeed("systemctl start restic-backups-testinstance_opt_repos_A")

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

    with subtest("Second backup in repo B"):
        machine.succeed("systemctl start restic-backups-testinstance_opt_repos_B")

    with subtest("Delete content"):
        machine.succeed("""
        rm -r /opt/files/A /opt/files/B
        """)

        assert_files("/opt/files", {})

    with subtest("Restore initial content from repo A"):
        machine.succeed("""
        restic-testinstance_opt_repos_A restore latest -t /
        """)

        assert_files("/opt/files", {
            '/opt/files/B/fileA': 'repoB_fileA_1',
            '/opt/files/B/fileB': 'repoB_fileB_1',
            '/opt/files/A/fileA': 'repoA_fileA_1',
            '/opt/files/A/fileB': 'repoA_fileB_1',
        })

    with subtest("Restore initial content from repo B"):
        machine.succeed("""
        restic-testinstance_opt_repos_B restore latest -t /
        """)

        assert_files("/opt/files", {
            '/opt/files/B/fileA': 'repoB_fileA_2',
            '/opt/files/B/fileB': 'repoB_fileB_2',
            '/opt/files/A/fileA': 'repoA_fileA_2',
            '/opt/files/A/fileB': 'repoA_fileB_2',
        })
    '';
in
{
  backupAndRestoreRoot = pkgs.testers.runNixOSTest {
    name = "restic_backupAndRestore";

    nodes.machine = {
      imports = ( testLib.baseImports pkgs' ) ++ [
        ../../modules/blocks/restic.nix
      ];

      shb.restic = {
        user = "root";
        group = "root";
      };
      shb.restic.instances."testinstance" = {
        enable = true;

        passphraseFile = pkgs.writeText "passphrase" "PassPhrase";

        sourceDirectories = [
          "/opt/files/A"
          "/opt/files/B"
        ];

        repositories = [
          {
            path = "/opt/repos/A";
            timerConfig = {
              OnCalendar = "00:00:00";
              RandomizedDelaySec = "5h";
            };
            # Those are not needed by the repository but are still included
            # so we can test them in the hooks section.
            secrets = {
              A.source = pkgs.writeText "A" "secretA";
              B.source = pkgs.writeText "B" "secretB";
            };
          }
          {
            path = "/opt/repos/B";
            timerConfig = {
              OnCalendar = "00:00:00";
              RandomizedDelaySec = "5h";
            };
          }
        ];

        hooks.before_backup = [''
        echo $RUNTIME_DIRECTORY
        if [ "$RUNTIME_DIRECTORY" = /run/restic-backups-testinstance_opt_repos_A ]; then
          if ! [ -f /run/secrets/restic/restic-backups-testinstance_opt_repos_A ]; then
            exit 10
          fi
          if [ -z "$A" ] || ! [ "$A" = "secretA" ]; then
            echo "A:$A"
            exit 11
          fi
          if [ -z "$B" ] || ! [ "$B" = "secretB" ]; then
            echo "A:$A"
            exit 12
          fi
        fi
        ''];
      };
    };

    extraPythonPackages = p: [ p.dictdiffer ];
    skipTypeCheck = true;

    testScript = commonTestScript;
  };

  backupAndRestoreUser = pkgs.testers.runNixOSTest {
    name = "restic_backupAndRestore";

    nodes.machine = {
      imports = ( testLib.baseImports pkgs' ) ++ [
        ../../modules/blocks/restic.nix
      ];

      shb.restic = {
        user = "backup";
        group = "backup";
      };
      shb.restic.instances."testinstance" = {
        enable = true;

        passphraseFile = pkgs.writeText "passphrase" "PassPhrase";

        sourceDirectories = [
          "/opt/files/A"
          "/opt/files/B"
        ];

        repositories = [
          {
            path = "/opt/repos/A";
            timerConfig = {
              OnCalendar = "00:00:00";
              RandomizedDelaySec = "5h";
            };
            # Those are not needed by the repository but are still included
            # so we can test them in the hooks section.
            secrets = {
              A.source = pkgs.writeText "A" "secretA";
              B.source = pkgs.writeText "B" "secretB";
            };
          }
          {
            path = "/opt/repos/B";
            timerConfig = {
              OnCalendar = "00:00:00";
              RandomizedDelaySec = "5h";
            };
          }
        ];

        hooks.before_backup = [''
        echo $RUNTIME_DIRECTORY
        if [ "$RUNTIME_DIRECTORY" = /run/restic-backups-testinstance_opt_repos_A ]; then
          if ! [ -f /run/secrets/restic/restic-backups-testinstance_opt_repos_A ]; then
            exit 10
          fi
          if [ -z "$A" ] || ! [ "$A" = "secretA" ]; then
            echo "A:$A"
            exit 11
          fi
          if [ -z "$B" ] || ! [ "$B" = "secretB" ]; then
            echo "A:$A"
            exit 12
          fi
        fi
        ''];
      };
    };

    extraPythonPackages = p: [ p.dictdiffer ];
    skipTypeCheck = true;

    testScript = commonTestScript;
  };
}
