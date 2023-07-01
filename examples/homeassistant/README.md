# Use a VM to run this example

Build VM with:

```bash
nixos-rebuild build-vm --fast -I nixos-config=./configuration.nix -I nixpkgs=.
```

Start VM with:

```bash
QEMU_NET_OPTS="hostfwd=tcp::2222-:22" ./result/bin/run-nixos-vm
```

User is `nixos`, password is `nixos`.

Ssh into VM with `ssh -p 2222 nixos@localhost`.

If you get into issues with ssh trying too many public keys and failing, try instead: `ssh -o PasswordAuthentication=yes -o PreferredAuthentications=keyboard-interactive,password -o PubkeyAuthentication=no  -p 2222 nixos@localhost`.

For more information about running this example in a vm, see [NixOS_modules#Developing_modules](https://nixos.wiki/wiki/NixOS_modules#Developing_modules).

For more information about writing tests, see [the manual](https://nixos.org/manual/nixos/stable/index.html#sec-nixos-tests).

Create your secret key which prints the public key used for `admin`:

```bash
nix-shell -p age --run 'age-keygen -o keys.txt'
```

Get target host age key which prints the public key used for `vm`:

```bash
nix-shell -p ssh-to-age --run 'ssh-keyscan -p 2222 -4 localhost | ssh-to-age'
```

Update `admin` and `vm` keys in sops.yaml.

Edit secret itself with:

```bash
nix-shell -p sops --run 'sops --config sops.yaml secrets.yaml'
```

Deploy with:

```bash
nix-shell -p colmena --run 'colmena apply'
```

Took 12 minutes for first deploy on my machine. Next deploys take about 12 seconds.
