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
  settings, # { repository, config } -> attrset
  extraConfig ? null, # { username, config } -> attrset
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
            repository = "/opt/repos/${name}";
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
      from dictdiffer import diff

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

      with subtest("First backup in repo"):
          print(machine.succeed("systemctl cat ${provider.backupService}"))
          machine.succeed("systemctl start ${provider.backupService}")

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

      with subtest("Delete content"):
          for path in sourceDirectories:
              machine.succeed(f"""rm -r {path}/*""")

              assert_files(path, {})

      with subtest("Restore initial content from repo"):
          machine.succeed("""${provider.restoreScript} restore latest""")

          for path in sourceDirectories:
              assert_files(path, {
                  f'{path}/fileA': 'repo_fileA_1',
                  f'{path}/fileB': 'repo_fileB_1',
              })
    '';
}
