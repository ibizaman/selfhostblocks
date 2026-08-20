# Jellyfin Demo {#demo-jellyfin}

**This whole demo is highly insecure as all the private keys are available publicly. This is
only done for convenience as it is just a demo. Do not expose the VM to the internet.**

The [`flake.nix`](./flake.nix) file sets up a Jellyfin server with Self Host Blocks. There are actually 3 demos:

- The `basic` demo sets up a lone Jellyfin server accessible through https.
- The `ldap` demo builds on top of the `basic` demo integrating Jellyfin with a LDAP provider.
- The `sso` demo builds on top of the `ldap` demo integrating Jellyfin with an SSO provider, backed by the LDAP provider.

This guide will show how to deploy these demos to a Virtual Machine, like showed
[here](https://nixos.wiki/wiki/NixOS_modules#Developing_modules).

## Deploy to the VM {#demo-jellyfin-deploy}

The demos are setup to either deploy to a VM through `nixos-rebuild` or through
[Colmena](https://colmena.cli.rs).

Using `nixos-rebuild` is very fast and requires less steps because it reuses your nix store.

Using `colmena` is more authentic because you are deploying to a stock VM, like you would with a
real machine but it needs to copy over all required store derivations so it takes a few minutes the
first time.

### Deploy with nixos-rebuild {#demo-jellyfin-deploy-nixosrebuild}

Assuming your current working directory is the one where this Readme file is located, the one-liner
command which builds and starts the VM is:

```nix
rm nixos.qcow2; \
  nixos-rebuild build-vm --flake .#basic \
  && QEMU_NET_OPTS="hostfwd=tcp::2222-:2222,hostfwd=tcp::8080-:80" \
     ./result/bin/run-nixos-vm
```

This will deploy the `basic` demo. If you want to deploy the `ldap` or `sso` demo,
use respectively the `.#ldap` and `.#sso` flake uris.

You can even test the demos from any directory without cloning this repository by using the GitHub
uri like `github:ibizaman/selfhostblocks?path=demo/jellyfin#basic`

It is very important to remove leftover `nixos.qcow2` files, if any, as done in the snippet above.

### Deploy with Colmena {#demo-jellyfin-deploy-colmena}

If you deploy with Colmena, you must first build the VM and start it:

```bash
rm nixos.qcow2; \
  nixos-rebuild build-vm-with-bootloader --fast -I nixos-config=./configuration.nix -I nixpkgs=. ; \
  QEMU_NET_OPTS="hostfwd=tcp::2222-:2222,hostfwd=tcp::8080-:80" ./result/bin/run-nixos-vm
```

It is very important to remove leftover `nixos.qcow2` files, if any.

This last call is blocking, so I advice adding a `&` at the end of the command otherwise you will
need to run the rest of the commands in another terminal.

With the VM started, make the secrets in `secrets.yaml` decryptable in the VM. This change will
appear in `git status` but you don't need to commit this.

```bash
SOPS_AGE_KEY_FILE=keys.txt \
  nix run --impure nixpkgs#sops -- --config sops.yaml -r -i \
  --add-age $(nix shell nixpkgs#ssh-to-age --command sh -c 'ssh-keyscan -p 2222 -t ed25519 -4 localhost 2>/dev/null | ssh-to-age') \
  secrets.yaml
```

The nested command, the one in between the parenthesis `$(...)`, is used to print the VM's public
age key, which is then added to the `secrets.yaml` file in order to make the secrets decryptable by
the VM.

If you forget this step, the deploy will seem to go fine but the secrets won't be populated and
neither LLDAP nor Jellyfin will start.

## Jellyfin Demos {#demo-jellyfin-access}

Before being able to access the VM from your browser, we need to create a SOCKS proxy.

First, you will need to change the permission of the ssh key like so:

```bash
chmod 600 sshkey
```

This is only needed because git mangles with the permissions. You will not even see this change in
`git status`.

Now, the SOCKS proxy can be started on port 1080 like so:

```bash
ssh -F ssh_config -D 1080 example
```

Point your browser to the SOCKS proxy with URL `localhost:1080`.

### Basic demo {#demo-jellyfin-basic}

Assuming you deployed the `basic` demo,
go to [https://j.example.com](https://j.example.com) and you will be greeted with the 
Jellyfin login screen.

You can login with the declaratively provisioned admin user:

- Username: `admin`
- Password: `jellyfinadmin`

::: {.info}
If you're too fast, you might get some nginx bad gateway errors or even the Jellyfin
web UI showing up telling you you need to pick the server. This is because Jellyfin takes a good
minute to start and until then, you won't see the login screen. Either wait a bit or in the
terminal where you run the SOCKS proxy, tail the logs with `journaltcl -f -u jellyfin` and wait
for the message `Main: Startup complete`.
:::

And that's the end of the demo.

### LDAP demo {#demo-jellyfin-ldap}

After Jellyfin has started (see previous section's note),
go to [https://j.example.com](https://j.example.com) and you will be greeted with the 
Jellyfin login screen.

You can login with the declaratively provisioned LDAP `alice` user:

- Username: `alice`
- Password: `alicepassword`

Or with the declaratively provisioned `admin` user:

- Username: `admin`
- Password: `jellyfinadmin`

The LDAP service is accessible at [https://ldap.example.com:8080](http://ldap.example.com:8080).
You can login with the `alice` user (same password as above) or as the LDAP `admin` user with:

- username: `admin`
- password: the value of the field `lldap.user_password` in the `secrets.yaml` file which is `fccb94f0f64bddfe299c81410096499a`.

### SSO demo {#demo-jellyfin-sso}

After Jellyfin has started (wait up to 2 minutes, see previous section's note),
go to [https://j.example.com](https://j.example.com) and you will be greeted with the 
Jellyfin login screen.

First, login through the normal login form with the declaratively provisioned LDAP `alice` user:

- Username: `alice`
- Password: `alicepassword`

Now, you can logout and login again but this time through the SSO "Sign in with Authelia" button, using the same password.

::: {.note}
It is best to login first through the normal form as their are caveats to the LDAP and SSO integrations.
See [the manual](https://shb.skarabox.com/services-jellyfin.html#services-jellyfin-sso) for more information.
:::

You could also still login with the declaratively provisioned `admin` user using the normal login form:

- Username: `admin`
- Password: `jellyfinadmin`

The LDAP service is accessible at [https://ldap.example.com:8080](http://ldap.example.com:8080).
You can login with the `alice` user (same password as above) or as the LDAP `admin` user with:

- username: `admin`
- password: the value of the field `lldap.user_password` in the `secrets.yaml` file which is `fccb94f0f64bddfe299c81410096499a`.

## In More Details {#demo-jellyfin-in-more-details}

### Files {#demo-jellyfin-files}

- [`flake.nix`](./flake.nix): nix entry point, defines one target host for
  [colmena](https://colmena.cli.rs) to deploy to as well as the selfhostblocks' config for
  setting up the jellyfin server paired with the LDAP and SSO server.
- [`configuration.nix`](./configuration.nix): defines all configuration required for colmena
  to deploy to the VM. The file has comments if you're interested.
- [`hardware-configuration.nix`](./hardware-configuration.nix): defines VM specific layout.
  This was generated with nixos-generate-config on the VM.
- Secrets related files:
  - [`keys.txt`](./keys.txt): your private key for sops-nix, allows you to edit the `secrets.yaml`
    file. This file should never be published but here I did it for convenience, to be able to
    deploy to the VM in less steps.
  - [`secrets.yaml`](./secrets.yaml): encrypted file containing required secrets for Jellyfin
    and the LDAP and SSO servers. This file can be publicly accessible.
    Edit secrets with `SOPS_AGE_KEY_FILE=keys.txt sops secrets.yaml`.
  - [`sops.yaml`](./sops.yaml): describes how to create the `secrets.yaml` file. Can be publicly
    accessible.
- SSH related files:
  - [`sshkey(.pub)`](./sshkey): your private and public ssh keys. Again, the private key should usually not
    be published as it is here but this makes it possible to deploy to the VM in less steps.
  - [`ssh_config`](./ssh_config): the ssh config allowing you to ssh into the VM by just using the
    hostname `example`. Usually you would store this info in your `~/.ssh/config` file but it's
    provided here to avoid making you do that.

### Virtual Machine {#demo-jellyfin-virtual-machine}

_More info about the VM._

We use `build-vm-with-bootloader` instead of just `build-vm` as that's the only way to deploy to the VM.

The VM's User and password are both `nixos`, as setup in the [`configuration.nix`](./configuration.nix) file under
`user.users.nixos.initialPassword`.

You can login with `ssh -F ssh_config example`. You just need to accept the fingerprint.

The VM's hard drive is a file name `nixos.qcow2` in this directory. It is created when you first create the VM and re-used since. You can just remove it when you're done.

That being said, the VM uses `tmpfs` to create the writable nix store so if you stumble in a disk
space issue, you must increase the
`virtualisation.vmVariantWithBootLoader.virtualisation.memorySize` setting.

### Secrets {#demo-jellyfin-secrets}

_More info about the secrets can be found in the [Usage](https://shb.skarabox.com/usage.html) manual_

To open the `secrets.yaml` file and optionnally edit it, run:

```bash
SOPS_AGE_KEY_FILE=keys.txt nix run --impure nixpkgs#sops -- \
  --config sops.yaml \
  secrets.yaml
```

You can generate random secrets with:

```bash
$ nix run nixpkgs#openssl -- rand -hex 64
```

If you choose a password too small, some services could refuse to start.

#### Why do we need the VM's public key {#demo-jellyfin-tips-public-key-necessity}

The [`sops.yaml`](./sops.yaml) file describes what private keys can decrypt and encrypt the
[`secrets.yaml`](./secrets.yaml) file containing the application secrets. Usually, you will create and add
secrets to that file and when deploying, it will be decrypted and the secrets will be copied
in the `/run/secrets` folder on the VM. We thus need one private key for you to edit the
[`secrets.yaml`](./secrets.yaml) file and one in the VM for it to decrypt the secrets.

Your private key is already pre-generated in this repo, it's the [`sshkey`](./sshkey) file. But when
creating the VM for Colmena, a new private key and its accompanying public key were automatically
generated under `/etc/ssh/ssh_host_ed25519_key` in the VM. We just need to get the public key and
add it to the `secrets.yaml` which we did in the Deploy section.

### SSH {#demo-jellyfin-tips-ssh}

The private and public ssh keys were created with:

```bash
ssh-keygen -t ed25519 -f sshkey
```

You don't need to copy over the ssh public key over to the VM as we set the `keyFiles` option which copies the public key when the VM gets created.
This allows us also to disable ssh password authentication.

For reference, if instead you didn't copy the key over on VM creating and enabled ssh
authentication, here is what you would need to do to copy over the key:

```bash
nix shell nixpkgs#openssh --command ssh-copy-id -i sshkey -F ssh_config example
```

### Deploy {#demo-jellyfin-tips-deploy}

If you get a NAR hash mismatch error like hereunder, you need to run `nix flake lock --update-input
selfhostblocks`.

```
error: NAR hash mismatch in input ...
```

### Update Demo {#demo-jellyfin-tips-update-demo}

If you update the Self Host Blocks configuration in `flake.nix` file, you can just re-deploy.

If you update the `configuration.nix` file, you will need to rebuild the VM from scratch.

If you update a module in the Self Host Blocks repository, you will need to update the lock file with:

```bash
nix flake lock --override-input selfhostblocks ../.. --update-input selfhostblocks
```
