{ pkgs, lib }:
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
lib.shb.runNixOSTest {
  inherit name;

  nodes.machine =
    { config, ... }:
    {
      imports = [ lib.shb.baseImports ] ++ modules;
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
      provider = getAttrFromPath providerRoot nodes.machine;
    in
    ''
      import csv

      start_all()
      machine.wait_for_unit("postgresql.service")
      machine.wait_for_open_port(5432)

      def peer_cmd(cmd, db="me"):
          return "sudo -u ${database} psql -U ${database} {db} --csv --command \"{cmd}\"".format(cmd=cmd, db=db)

      def query(query):
          res = machine.succeed(peer_cmd(query))
          return list(dict(l) for l in csv.DictReader(res.splitlines()))

      def cmp_tables(a, b):
          for i in range(max(len(a), len(b))):
              diff = set(a[i]) ^ set(b[i])
              if len(diff) > 0:
                  raise Exception(i, diff)

      table = [{'name': 'car', 'count': '1'}, {'name': 'lollipop', 'count': '2'}]

      with subtest("create fixture"):
          machine.succeed(peer_cmd("CREATE TABLE test (name text, count int)"))
          machine.succeed(peer_cmd("INSERT INTO test VALUES ('car', 1), ('lollipop', 2)"))

          res = query("SELECT * FROM test")
          cmp_tables(res, table)

      with subtest("backup"):
          print(machine.succeed("systemctl cat ${provider.result.backupService}"))
          print(machine.succeed("ls -l /run/hardcodedsecrets/hardcodedsecret_passphrase"))
          machine.succeed("systemctl start ${provider.result.backupService}")

      with subtest("drop database"):
          machine.succeed(peer_cmd("DROP DATABASE ${database}", db="postgres"))
          machine.fail(peer_cmd("SELECT * FROM test"))

      with subtest("restore"):
          print(machine.succeed("readlink -f $(type ${provider.result.restoreScript})"))
          machine.succeed("${provider.result.restoreScript} restore latest ")

      with subtest("check restoration"):
          res = query("SELECT * FROM test")
          cmp_tables(res, table)
    '';
}
