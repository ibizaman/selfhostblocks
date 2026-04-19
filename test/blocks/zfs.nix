{
  shb,
  ...
}:
{
  default = shb.test.runNixOSTest {
    name = "zfs-default";

    nodes.machine =
      { config, pkgs, ... }:
      {
        imports = [
          ../../modules/blocks/zfs.nix
        ];

        # Inspiration from https://github.com/NixOS/nixpkgs/blob/master/nixos/tests/zfs.nix
        networking.hostId = "deadbeef";
        boot.supportedFilesystems = [ "zfs" ];

        users.users.syncthing = {
          isSystemUser = true;
          group = "syncthing";
        };
        users.groups.syncthing = { };
        virtualisation = {
          emptyDiskImages = [
            512
            512
          ];
        };

        systemd.services."zfs-zpool-create" = {
          unitConfig.DefaultDependencies = false;
          after = [ "systemd-modules-load.service" ];
          requiredBy = [
            "zfs-import-root.service"
            "zfs-import-data.service"
            "zfs-mount.service"
          ];
          before = [
            "zfs-import-root.service"
            "zfs-import-data.service"
            "zfs-mount.service"
          ];
          script = ''
            if [ ! -f /var/done ]; then
              ${pkgs.zfs}/bin/zpool create -m none -O acltype=posixacl root /dev/vdb
              ${pkgs.zfs}/bin/zpool create -m none -O acltype=posixacl data /dev/vdc
              sync
            fi
            touch /var/done
          '';
        };

        shb.zfs.pools.root.datasets.one.path = "/var/root/one";
        shb.zfs.pools.root.datasets.two.path = "/var/root/two";
        shb.zfs.pools.root.datasets.none.path = "none";
        shb.zfs.pools.data.datasets.two = {
          path = "/var/data/two";

          mode = "ug=rwx,g+s,o=";
          owner = "syncthing";
          group = "syncthing";
          defaultACLs = "g:syncthing:rwX";
        };
      };

    testScript =
      { nodes, ... }:
      ''
        import difflib

        def assert_facl():
            out = machine.succeed("getfacl /var/data/two").splitlines()
            expect = """\
        # file: var/data/two
        # owner: syncthing
        # group: syncthing
        # flags: -s-
        user::rwx
        group::rwx
        other::---
        default:user::rwx
        default:group::rwx
        default:group:syncthing:rwx
        default:mask::rwx
        default:other::---

        """.splitlines()
            if out != expect:
                diff = difflib.context_diff(expect, out)
                raise Exception(f"Unexpected getfacl:\n{"\n".join(diff)}")

        def assert_mounts():
            out = sorted([l.split()[0] for l in machine.succeed("mount | grep /var/").splitlines()])
            expect = ["data/two", "root/one", "root/two"]
            if out != expect:
                diff = difflib.context_diff(expect, out)
                raise Exception(f"Unexpected mounts:\n{"\n".join(diff)}")

        machine.start(allow_reboot=True)
        machine.wait_for_unit("multi-user.target")

        assert_facl()
        assert_mounts()

        # TODO: make this work. zpool import does not work after reboot.
        # machine.crash()
        # machine.wait_for_unit("multi-user.target")

        # assert_facl()
        # assert_mounts()
      '';
  };
}
