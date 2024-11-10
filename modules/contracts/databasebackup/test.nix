{ pkgs, lib, ... }:
let
  pkgs' = pkgs;

  testLib = pkgs.callPackage ../../../test/common.nix {};

  inherit (lib) getAttrFromPath mkIf optionalAttrs setAttrByPath;
in
{ name,
  requesterRoot,
  providerRoot,
  providerExtraConfig ? null, # { username, database } -> attrset
  modules ? [],
  username ? "me",
  database ? "me",
  settings, # repository -> attrset
}: pkgs.testers.runNixOSTest {
  inherit name;

  nodes.machine = { config, ... }: {
    imports = ( testLib.baseImports pkgs' ) ++ modules;
    config = lib.mkMerge [
      (setAttrByPath providerRoot {
        request = (getAttrFromPath requesterRoot config).backup;
        settings = settings "/opt/repos/database";
      })
      (mkIf (username != "root") {
        users.users.${username} = {
          isSystemUser = true;
          extraGroups = [ "sudoers" ];
          group = "root";
        };
      })
      (optionalAttrs (providerExtraConfig != null) (providerExtraConfig { inherit username database; }))
    ];
  };

  testScript = { nodes, ... }: let
    provider = (getAttrFromPath providerRoot nodes.machine).result;
  in ''
    import csv

    start_all()
    machine.wait_for_unit("postgresql.service")
    machine.wait_for_open_port(5432)

    def peer_cmd(cmd, db="me"):
        return "sudo -u me psql -U me {db} --csv --command \"{cmd}\"".format(cmd=cmd, db=db)

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
        print(machine.succeed("systemctl cat ${provider.backupService}"))
        machine.succeed("systemctl start ${provider.backupService}")

    with subtest("drop database"):
        machine.succeed(peer_cmd("DROP DATABASE me", db="postgres"))

    with subtest("restore"):
        print(machine.succeed("readlink -f $(type ${provider.restoreScript})"))
        machine.succeed("${provider.restoreScript} restore latest ")

    with subtest("check restoration"):
        res = query("SELECT * FROM test")
        cmp_tables(res, table)
  '';
}
