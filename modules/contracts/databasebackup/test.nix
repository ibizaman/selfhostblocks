{
  pkgs,
  lib,
  shb,
}:
let
  inherit (lib)
    getAttrFromPath
    mkIf
    optionalAttrs
    setAttrByPath
    ;
in
{
  name,
  requesterRoot,
  providerRoot,
  extraConfig ? null, # { config, database } -> attrset
  modules ? [ ],
  database ? "me",
  settings, # { repository, config } -> attrset
}:
shb.test.runNixOSTest {
  inherit name;

  nodes.machine =
    { config, ... }:
    {
      imports = [ shb.test.baseImports ] ++ modules;
      config = lib.mkMerge [
        (setAttrByPath providerRoot {
          request = (getAttrFromPath requesterRoot config).request;
          settings = settings {
            inherit config;
            repository = "/opt/repos/database";
          };
        })
        (mkIf (database != "root") {
          users.users.${database} = {
            isSystemUser = true;
            extraGroups = [ "sudoers" ];
            group = "root";
          };
        })
        (optionalAttrs (extraConfig != null) (extraConfig {
          inherit config database;
        }))
      ];
    };

  testScript =
    { nodes, ... }:
    let
      provider = (getAttrFromPath providerRoot nodes.machine).result;
    in
    ''
      import csv
      import re

      start_all()
      machine.wait_for_unit("postgresql.service")
      machine.wait_for_unit("postgresql-setup.service")
      machine.wait_for_open_port(5432)

      def peer_cmd(cmd, db="${database}"):
          return "sudo -u ${database} psql -U ${database} {db} --csv --command \"{cmd}\"".format(cmd=cmd, db=db)

      def query(query):
          res = machine.succeed(peer_cmd(query))
          return list(dict(l) for l in csv.DictReader(res.splitlines()))

      def cmp_tables(a, b):
          for i in range(max(len(a), len(b))):
              diff = set(a[i]) ^ set(b[i])
              if len(diff) > 0:
                  raise Exception(i, diff)

      with subtest("create fixture"):
          machine.succeed(peer_cmd("CREATE TABLE test (name text, count int)"))
          machine.succeed(peer_cmd("INSERT INTO test VALUES ('car', 1)"))

          res = query("SELECT * FROM test")
          table = [{'name': 'car', 'count': '1'}]
          cmp_tables(res, table)

      with subtest("Initial snapshots"):
          out = machine.succeed("${provider.restoreScript} snapshots").splitlines()
          print(f"Found snapshots:\n{out}")
          if len(out) != 0:
              raise Exception(f"Unexpected snapshots:\n{out}")

      with subtest("backup"):
          machine.succeed("systemctl start --wait ${provider.backupService}")

      with subtest("One snapshot"):
          out = machine.succeed("${provider.restoreScript} snapshots").splitlines()
          print(f"Found snapshots:\n{out}")
          if len(out) != 1:
              raise Exception(f"Unexpected snapshots:\n{out}")

      with subtest("New content"):
          machine.succeed(peer_cmd("INSERT INTO test VALUES ('lollipop', 2)"))

          res = query("SELECT * FROM test")
          table = [{'name': 'car', 'count': '1'}, {'name': 'lollipop', 'count': '2'}]
          cmp_tables(res, table)

      with subtest("backup"):
          machine.succeed("systemctl start --wait ${provider.backupService}")

      with subtest("Two snapshots"):
          out = machine.succeed("${provider.restoreScript} snapshots").splitlines()
          print(f"Found snapshots:\n{out}")
          if len(out) != 2:
              raise Exception(f"Unexpected snapshots:\n{out}")

      firstSnapshot = re.split("[ \t+]", out[0], maxsplit=1)[0]
      secondSnapshot = re.split("[ \t+]", out[1], maxsplit=1)[0]
      print(f"First snapshot {firstSnapshot}")
      print(f"Second snapshot {secondSnapshot}")

      with subtest("drop database"):
          machine.succeed(peer_cmd("DROP DATABASE ${database}", db="postgres"))
          machine.fail(peer_cmd("SELECT * FROM test"))

      with subtest("restore second snapshot"):
          print(machine.succeed("readlink -f $(type ${provider.restoreScript})"))
          machine.succeed(f"${provider.restoreScript} restore {secondSnapshot}")

          res = query("SELECT * FROM test")
          table = [{'name': 'car', 'count': '1'}, {'name': 'lollipop', 'count': '2'}]
          cmp_tables(res, table)

      with subtest("restore first snapshot"):
          print(machine.succeed("readlink -f $(type ${provider.restoreScript})"))
          machine.succeed(f"${provider.restoreScript} restore {firstSnapshot}")

          res = query("SELECT * FROM test")
          table = [{'name': 'car', 'count': '1'}]
          cmp_tables(res, table)
    '';
}
