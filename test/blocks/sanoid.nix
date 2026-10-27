{ shb, lib, ... }:
{
  # Reuse the ZFS pool/dataset fixture, replacing activation coverage with restores.
  restore = (import ./zfs.nix { inherit shb; }).default.extend {
    modules = [
      {
        name = lib.mkForce "sanoid-restore";
        nodes.machine = { options, ... }: {
          imports = [ ../../modules/blocks/sanoid.nix ];
          specialisation = lib.mkForce { };
          systemd.services.zfs-zpool-create.serviceConfig.Type = "oneshot";
          shb.sanoid.backup."root/one" = {
            # Keep this safety test usable with the separate dataset-contract migration.
            # Current provider: https://github.com/ibizaman/selfhostblocks/blob/e90f26a641a5d4d1a4cac256a69aa2bf4ddf76df/modules/blocks/sanoid.nix#L130
            request = lib.optionalAttrs (
              ((options.shb.sanoid.backup.type.getSubOptions [ ]).request.type.getSubOptions [ ]) ? dataset
            ) { dataset = "root/one"; };
            settings = {
              autosnap = false;
              autoprune = false;
            };
          };
        };
        testScript = lib.mkForce (
          { nodes, ... }:
          ''
            restore = ${
              builtins.toJSON (lib.escapeShellArg nodes.machine.shb.sanoid.backup."root/one".result.restoreScript)
            }
            machine.start()
            machine.wait_for_unit("multi-user.target")

            machine.succeed("echo older > /var/root/one/test-only; zfs snapshot root/one@older")
            machine.succeed("echo newer > /var/root/one/test-only; zfs snapshot root/one@newer")
            machine.succeed("zfs bookmark root/one@newer root/one#newer")
            machine.succeed("echo current > /var/root/one/test-only")
            machine.succeed("echo foreign > /var/data/two/test-only; zfs snapshot data/two@foreign")

            with subtest("foreign snapshots are rejected even with deletion authorized"):
                machine.fail(f"{restore} restore --destroy-newer-snapshots data/two@foreign")
                assert machine.succeed("cat /var/root/one/test-only").strip() == "current"
                assert machine.succeed("cat /var/data/two/test-only").strip() == "foreign"

            with subtest("older restores preserve newer snapshots by default"):
                machine.fail(f"{restore} restore root/one@older")
                machine.succeed("zfs list -t snapshot root/one@newer")
                machine.succeed("zfs list -t bookmark root/one#newer")
                assert machine.succeed("cat /var/root/one/test-only").strip() == "current"

            with subtest("latest snapshot restores without deleting snapshots"):
                machine.succeed(f"{restore} restore root/one@newer")
                assert machine.succeed("cat /var/root/one/test-only").strip() == "newer"
                assert len(machine.succeed(f"{restore} snapshots").splitlines()) == 2

            with subtest("explicit deletion allows restoring an older snapshot"):
                machine.succeed(f"{restore} restore --destroy-newer-snapshots root/one@older")
                assert machine.succeed("cat /var/root/one/test-only").strip() == "older"
                machine.fail("zfs list -t snapshot root/one@newer")
                machine.fail("zfs list -t bookmark root/one#newer")
                machine.succeed("zfs list -t snapshot root/one@older data/two@foreign")
                assert len(machine.succeed(f"{restore} snapshots").splitlines()) == 1
          ''
        );
      }
    ];
  };
}
