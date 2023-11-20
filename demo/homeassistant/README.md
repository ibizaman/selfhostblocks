# Home Assistant Demo

**This whole demo is highly insecure as all the private keys are available publicly. This is
only done for convenience as it is just a demo. Do not expose the VM to the internet.**

The [`flake.nix`](./flake.nix) file sets up Home Assistant server that uses a LDAP server to
setup users in only about [15 lines](./flake.nix#L29-L45) of related code.

This guide will show how to deploy this setup to a Virtual Machine, like showed
[here](https://nixos.wiki/wiki/NixOS_modules#Developing_modules), in 5 commands.

## Deploy to the VM

Build VM with:

```bash
nixos-rebuild build-vm-with-bootloader --fast -I nixos-config=./configuration.nix -I nixpkgs=.
```

Start VM with (this call is blocking):

```bash
QEMU_NET_OPTS="hostfwd=tcp::2222-:2222,hostfwd=tcp::8080-:80" ./result/bin/run-nixos-vm
```

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

Finally, deploy with:

```bash
SSH_CONFIG_FILE=ssh_config nix run nixpkgs#colmena --impure -- apply
```

This step will require you to accept the host's fingerprint. The deploy will take a few minutes the first time and subsequent deploys will take around 15 seconds.

## Access Home Assistant Through Your Browser

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
- password: the value of the field `lldap.user_password` in the `secrets.yaml` file which is `fccb94f0f64bddfe299c81410096499a`.

Create the group `homeassistant_user` and a user assigned to that group.

Go to [http://ha.example.com:8080](http://ha.example.com:8080) and login with the
user and password you just created above.

## In More Details

### Files

- [`flake.nix`](./flake.nix): nix entry point, defines one target host for
  [colmena](https://colmena.cli.rs) to deploy to as well as the selfhostblock's config for
  setting up the home assistant server paired with the LDAP server.
- [`configuration.nix`](./configuration.nix): defines all configuration required for colmena
  to deploy to the VM. The file has comments if you're interested.
- [`hardware-configuration.nix`](./hardware-configuration.nix): defines VM specific layout.
  This was generated with nixos-generate-config on the VM.
- Secrets related files:
  - [`keys.txt`](./keys.txt): your private key for sops-nix, allows you to edit the `secrets.yaml`
    file. This file should never be published but here I did it for convenience, to be able to
    deploy to the VM in less steps.
  - [`secrets.yaml`](./secrets.yaml): encrypted file containing required secrets for Home Assistant
    and the LDAP server. This file can be publicly accessible.
  - [`sops.yaml`](./sops.yaml): describes how to create the `secrets.yaml` file. Can be publicly
    accessible.
- SSH related files:
  - [`sshkey(.pub)`](./sshkey): your private and public ssh keys. Again, the private key should usually not
    be published as it is here but this makes it possible to deploy to the VM in less steps.
  - [`ssh_config`](./ssh_config): the ssh config allowing you to ssh into the VM by just using the
    hostname `example`. Usually you would store this info in your `~/.ssh/config` file but it's
    provided here to avoid making you do that.

### Virtual Machine

_More info about the VM._

We use `build-vm-with-bootloader` instead of just `build-vm` as that's the only way to deploy to the VM.

The VM's User and password are both `nixos`, as setup in the [`configuration.nix`](./configuration.nix) file under
`user.users.nixos.initialPassword`.

You can login with `ssh -F ssh_config example`. You just need to accept the fingerprint.

### Secrets

_More info about the secrets._

The private key in the `keys.txt` file is created with:

```bash
$ nix shell nixpkgs#age --command age-keygen -o keys.txt
Public key: age1algdv9xwjre3tm7969eyremfw2ftx4h8qehmmjzksrv7f2qve9dqg8pug7
```

We use the printed public key in the `admin` field in `sops.yaml` file.

The `secrets.yaml` file must follow the format:

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

You can generate random secrets with:

```bash
$ nix run nixpkgs#openssl -- rand -hex 64
```

#### Why do we need the VM's public key

The [`sops.yaml`](./sops.yaml) file describes what private keys can decrypt and encrypt the
[`secrets.yaml`](./secrets.yaml) file containing the application secrets. Usually, you will create and add
secrets to that file and when deploying, it will be decrypted and the secrets will be copied
in the `/run/secrets` folder on the VM. We thus need one private key for you to edit the
[`secrets.yaml`](./secrets.yaml) file and one in the VM for it to decrypt the secrets.

Your private key is already pre-generated in this repo, it's the [`sshkey`](./sshkey) file. But when
creating the VM in the step above, a new private key and its accompanying public key were
automatically generated under `/etc/ssh/ssh_host_ed25519_key` in the VM. We just need to get the
public key and add it to the `secrets.yaml` which we did in the Deploy section.

To open the `secrets.yaml` file and optionnally edit it, run:

```bash
SOPS_AGE_KEY_FILE=keys.txt nix run --impure nixpkgs#sops -- \
  --config sops.yaml \
  secrets.yaml
```

### SSH

The private and public ssh keys were created with:

```bash
ssh-keygen -t ed25519 -f sshkey
```

You don't need to copy over the ssh public key over to the VM as we set the `keyFiles` option which copies the public key when the VM gets created.
This allows us also to disable ssh password authentication.

For reference, here is what you would need to do if you didn't use the option:

```bash
$ nix shell nixpkgs#openssh --command ssh-copy-id -i sshkey -F ssh_config example
```

### Deploy

If you get a NAR hash mismatch error like herunder, you need to run `nix flake lock --update-input selfhostblocks`.

```
error: NAR hash mismatch in input ...
```
