### Deploy to prod

Please read the [deploy to staging](/deploystaging.md) first as all
commands are very similar. I only show a summary of the commands with
staging variables replaced by prod ones.

```bash
export NIXOPS_DEPLOYMENT=prod
export DISNIXOS_USE_NIXOPS=1

nixops create ./network-prod.nix -d prod

nixops deploy --option extra-builtins-file $(pwd)/pkgs/extra-builtins.nix
nixops reboot

disnixos-env -s services.nix -n network-prod.nix -d distribution.nix
```
