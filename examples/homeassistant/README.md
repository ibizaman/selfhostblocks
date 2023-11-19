# Home Assistant Example

This `flake.nix` file sets up Home Assistant server that uses a LDAP server to
setup users with only about [15 lines](./flake.nix#L39-L55) of related code.

This guide will show how to deploy this setup to a Virtual Machine, like showed
[here](https://nixos.wiki/wiki/NixOS_modules#Developing_modules), in 5 commands.

## Launch VM

Build VM with:

```bash
nixos-rebuild build-vm-with-bootloader --fast -I nixos-config=./configuration.nix -I nixpkgs=.
```

Start VM with (this call is blocking):

```bash
QEMU_NET_OPTS="hostfwd=tcp::2222-:2222,hostfwd=tcp::8080-:80" ./result/bin/run-nixos-vm
```

User and password are both `nixos`, as setup in the [`configuration.nix`](./configuration.nix) file under
`user.users.nixos.initialPassword`.

You can login with `ssh -F ssh_config example`. You just need to accept the fingerprint.

## Make VM able to decrypt the secrets.yaml file

The [`sops.yaml`](./sops.yaml) file describes what private keys can decrypt and encrypt the
[`secrets.yaml`](./secrets.yaml) file containing the application secrets. Usually, you will add
secrets to that secrets file and when deploying, it will be decrypted and the secrets will be copied
in the `/run/secrets` folder on the VM. We thus need one private key for you to edit the
[`secrets.yaml`](./secrets.yaml) file and one in the VM for it to decrypt the secrets.

Your private key is already pre-generated in this repo, it's the [`sshkey`](./sshkey) file. But when
creating the VM in the step above, a new private key and its accompanying public key were
automatically generated under `/etc/ssh/ssh_host_ed25519_key` in the VM. We just need to get the
public key.

With the VM started, print the VM's public age key with the following command. The value you need is
the one staring with `age`.

```bash
$ nix shell nixpkgs#ssh-to-age --command sh -c 'ssh-keyscan -p 2222 -4 localhost | ssh-to-age'
# localshost:2222 SSH-2.0-OpenSSH_9.1
# localhost:2222 SSH-2.0-OpenSSH_9.1
# localhost:2222 SSH-2.0-OpenSSH_9.1
# localhost:2222 SSH-2.0-OpenSSH_9.1
# localhost:2222 SSH-2.0-OpenSSH_9.1
skipped key: got ssh-rsa key type, but only ed25519 keys are supported
age1l9dyy02qhlfcn5u9s4y2vhsvjtxj2c9avrpat6nvjd6rjar3tflq66jtz0
```

Now, make the `secrets.yaml` file decryptable in the VM.

```bash
SOPS_AGE_KEY_FILE=keys.txt nix run --impure nixpkgs#sops -- \
  --config sops.yaml -r -i \
  --add-age age1l9dyy02qhlfcn5u9s4y2vhsvjtxj2c9avrpat6nvjd6rjar3tflq66jtz0 \
  secrets.yaml
```

Later on, when the server is deployed, you will need to login to the LDAP server with the admin account.
You can find the secret `lldap.user_password` field in the [`secrets.yaml`](./secrets.yaml) file. To open it, run:

```bash
SOPS_AGE_KEY_FILE=keys.txt nix run --impure nixpkgs#sops -- \
  --config sops.yaml \
  secrets.yaml
```

## Deploy

Now, deploy with:

```bash
SSH_CONFIG_FILE=ssh_config nix run nixpkgs#colmena --impure -- apply
```

Took a few minutes for first deploy on my machine. Next deploys take about 12 seconds.

## Access apps through your browser

Add the following entry to your `/etc/hosts` file:

```nix
networking.hosts = {
  "127.0.0.1" = [ "ha.example.com" "ldap.example.com" ];
};
```

Which produces:

```bash
$ cat /etc/hosts
127.0.0.1 ha.example.com ldap.example.com
```

Go to [http://ldap.example.com:8080](http://ldap.example.com:8080) and login with:
- username: `admin`
- password: the value of the field `lldap.user_password` in the `secrets.yaml` file.

Create the group `homeassistant_user` and a user assigned to that group.

Go to [ttp://ha.example.com:8080](http://ha.example.com:8080) and login with the user and password you just created above.

## Prepare the VM

This section documents how the various files were created to provide the nearly out of the box
experience described in the previous section. I need to clean this up a bit.

### Private and Public Key

Create the private key in the `keys.txt` file and print the public key used for `admin`:

```bash
$ nix shell nixpkgs#age --command age-keygen -o keys.txt
Public key: age1algdv9xwjre3tm7969eyremfw2ftx4h8qehmmjzksrv7f2qve9dqg8pug7
```

Update `admin` and `vm` keys in `sops.yaml`.

Then, you can create the secrets.yaml with:

That file must follow the format:

```yaml
home-assistant: |
    name: "My Instance"
    country: "US"
    latitude_home: "0.100"
    longitude_home: "-0.100"
    time_zone: "America/Los_Angeles"
    unit_system: "metric"
lldap:
    user_password: XXX...
    jwt_secret: YYY...
```

You can generate secrets with:

```bash
$ nix run nixpkgs#openssl -- rand -hex 64
```

TODO: add instructions to create ssh private and public key:

```bash
```

You don't need to copy over the ssh public key with the following command as we set the `keyFiles` option. I still leave it here for reference.

```bash
$ nix shell nixpkgs#openssh --command ssh-copy-id -i sshkey -F ssh_config example
```

### Deploy

If you get a NAR hash mismatch error like so, you need to run `nix flake lock --update-input selfhostblocks`:

```
error: NAR hash mismatch in input ...
```
