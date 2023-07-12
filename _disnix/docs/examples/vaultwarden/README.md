# Vaultwarden setup

This folder contain an example configuration for setting up
Vaultwarden on Linode. But before deploying to linode, you can
actually test the deployment locally with VirtualBox.

First, [setup NixOS on a Linode instance](/docs/tutorials/linode.md).

When that's done, explore the files in this folder.

To try it out locally, follow [deploy to staging](/docs/tutorials/deploystaging.md).

```bash
nixops set-args  --network dev \
  --arg domain '"dev.mydomain.com"' \
  --arg sopsKeyFile '"$HOME/.config/sops/age/keys.txt"'
```

You can use the `info` subcommand to print the values of the arguments:
```bash
nixops info --network dev
```

The TL; DR version is, assuming you're where this file is located:

```bash
export NIXOPS_DEPLOYMENT=vaultwarden-staging
export DISNIXOS_USE_NIXOPS=1

nixops create ./network-virtualbox.nix -d vaultwarden-staging

nixops deploy --network dev
nixops reboot

disnixos-env -s services.nix -n dev/nixops.nix -d distribution.nix
```
