# Nextcloud Demo {#demo-nextcloud}

**This whole demo is highly insecure as all the private keys are available publicly. This is
only done for convenience as it is just a demo. Do not expose the VM to the internet.**

The [`flake.nix`](./flake.nix) file sets up a Nextcloud server with Self Host Blocks. There are
actually 3 demos:

- The `basic` demo sets up a lone Nextcloud server accessible through http with the Preview
  Generator app enabled.
- The `ldap` demo builds on top of the `basic` demo integrating Nextcloud with a LDAP provider.
- The `sso` demo builds on top of the `lsap` demo integrating Nextcloud with a SSO provider.

They were set up by following the [manual](https://shb.skarabox.com/services-nextcloud.html). This
guide will show how to deploy these demos to a Virtual Machine, like showed
[here](https://nixos.wiki/wiki/NixOS_modules#Developing_modules).

## Deploy to the VM {#demo-nextcloud-deploy}

The demos are setup to either deploy to a VM through `nixos-rebuild` or through
[Colmena](https://colmena.cli.rs).

Using `nixos-rebuild` is very fast and requires less steps because it reuses your nix store.

Using `colmena` is more authentic because you are deploying to a stock VM, like you would with a
real machine but it needs to copy over all required store derivations so it takes a few minutes the
first time.

### Deploy with nixos-rebuild {#demo-nextcloud-deploy-nixosrebuild}

Assuming your current working directory is the one where this Readme file is located, the one-liner
command which builds and starts the VM configured to run Self Host Blocks' Nextcloud is:

```nix
rm nixos.qcow2; \
  nixos-rebuild build-vm --flake .#basic \
  && QEMU_NET_OPTS="hostfwd=tcp::2222-:2222,hostfwd=tcp::8080-:80" \
     ./result/bin/run-nixos-vm
```

This will deploy the `basic` demo. If you want to deploy the `ldap` or `sso` demos, use respectively
the `.#ldap` or `.#sso` flake uris.

You can even test the demos from any directory without cloning this repository by using the GitHub
uri like `github:ibizaman/selfhostblocks?path=demo/nextcloud`

It is very important to remove leftover `nixos.qcow2` files, if any.

You can ssh into the VM like this, but this is not required for the demo:

```bash
ssh -F ssh_config example
```

But before that works, you will need to change the permission of the ssh key like so:

```bash
chmod 600 sshkey
```

This is only needed because git mangles with the permissions. You will not even see this change in
`git status`.

### Deploy with Colmena {#demo-nextcloud-deploy-colmena}

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
Nextcloud will not start.

Make the ssh key private:

```bash
chmod 600 sshkey
```

This is only needed because git mangles with the permissions. You will not even see this change in
`git status`.

You can ssh into the VM like this, but this is not required for the demo:

```bash
ssh -F ssh_config example
```

### Nextcloud through HTTP {#demo-nextcloud-deploy-basic}

:::: {.note}
This section corresponds to the `basic` section of the [Nextcloud
manual](services-nextcloud.html#services-nextcloud-server-usage-basic).
::::

Assuming you already deployed the `basic` demo, now you must add the following entry to the
`/etc/hosts` file on the host machine (not the VM):

```nix
networking.hosts = {
  "127.0.0.1" = [ "n.example.com" ];
};
```

Which produces:

```bash
$ cat /etc/hosts
127.0.0.1 n.example.com
```

Go to [http://n.example.com:8080](http://n.example.com:8080) and login with:

- username: `root`
- password: the value of the field `nextcloud.adminpass` in the `secrets.yaml` file which is
  `43bb4b8f82fc645ce3260b5db803c5a8`.

This is the admin user of Nextcloud and that's the end of the `basic` demo.

### Nextcloud with LDAP through HTTP {#demo-nextcloud-deploy-ldap}

:::: {.note}
This section corresponds to the `ldap` section of the [Nextcloud
manual](services-nextcloud.html#services-nextcloud-server-usage-ldap).
::::

Assuming you already deployed the `ldap` demo, now you must add the following entry to the
`/etc/hosts` file on the host machine (not the VM):

```nix
networking.hosts = {
  "127.0.0.1" = [ "n.example.com" "ldap.example.com" ];
};
```

Which produces:

```bash
$ cat /etc/hosts
127.0.0.1 n.example.com ldap.example.com
```

Go first to [http://ldap.example.com:8080](http://ldap.example.com:8080) and login with:

- username: `admin`
- password: the value of the field `lldap.user_password` in the `secrets.yaml` file which is
  `c2e32e54ea3e0053eb30841f818a3d9a`.

Create the group `nextcloud_user` and a create a user and assign them to that group.

Finally, go to [http://n.example.com:8080](http://n.example.com:8080) and login with the user and
password you just created above.

Nextcloud doesn't like being run without SSL protection, which this demo does not setup, so you
might see errors loading scripts. See the `sso` demo for SSL.

This is the end of the `ldap` demo.

### Nextcloud with LDAP and SSO through self-signed HTTPS {#demo-nextcloud-deploy-sso}

:::: {.note}
This section corresponds to the `sso` section of the [Nextcloud
manual](services-nextcloud.html#services-nextcloud-server-usage-oidc).
::::

At this point, it is assumed you already deployed the `sso` demo. There is no host to add to
`/etc/hosts` here. Instead, there is a `dnsmasq` server running in the VM and you must create a
SOCKS proxy to connect to it like so:

```bash
ssh -F ssh_config -D 1080 -N example
```

This is a blocking call but it is not necessary to fork this process in the background by appending
`&` because we will not need to use the terminal for the rest of the demo.

Now, configure your browser to use that SOCKS proxy. When that's done go to
[https://ldap.example.com](https://ldap.example.com) and login with:

- username: `admin`
- password: the value of the field `lldap.user_password` in the `secrets.yaml` file which is
  `c2e32e54ea3e0053eb30841f818a3d9a`.

Create the group `nextcloud_user` and a create a user and assign them to that group.

Visit [https://auth.example.com](https://auth.example.com) and make your browserauthorize the certificate.

Finally, go to [https://n.example.com](https://n.example.com) and login with the user and
password you just created above. You will see that the login page is actually the one from the SSO provider.

This is the end of the `sso` demo.

## In More Details {#demo-nextcloud-tips}

### Files {#demo-nextcloud-tips-files}

- [`flake.nix`](./flake.nix): nix entry point, defines the target hosts for
  [colmena](https://colmena.cli.rs) to deploy to as well as the selfhostblock's config for setting
  up Nextcloud and the auxiliary services.
- [`configuration.nix`](./configuration.nix): defines all configuration required for colmena
  to deploy to the VM. The file has comments if you're interested.
- [`hardware-configuration.nix`](./hardware-configuration.nix): defines VM specific layout.
  This was generated with nixos-generate-config on the VM.
- Secrets related files:
  - [`keys.txt`](./keys.txt): your private key for sops-nix, allows you to edit the `secrets.yaml`
    file. This file should never be published but here I did it for convenience, to be able to
    deploy to the VM in less steps.
  - [`secrets.yaml`](./secrets.yaml): encrypted file containing required secrets for Nextcloud. This file can be publicly accessible.
  - [`sops.yaml`](./sops.yaml): describes how to create the `secrets.yaml` file. Can be publicly
    accessible.
- SSH related files:
  - [`sshkey(.pub)`](./sshkey): your private and public ssh keys. Again, the private key should usually not
    be published as it is here but this makes it possible to deploy to the VM in less steps.
  - [`ssh_config`](./ssh_config): the ssh config allowing you to ssh into the VM by just using the
    hostname `example`. Usually you would store this info in your `~/.ssh/config` file but it's
    provided here to avoid making you do that.

### Virtual Machine {#demo-nextcloud-tips-virtual-machine}

_More info about the VM._

We use `build-vm-with-bootloader` instead of just `build-vm` as that's the only way to deploy to the VM.

The VM's User and password are both `nixos`, as setup in the [`configuration.nix`](./configuration.nix) file under
`user.users.nixos.initialPassword`.

You can login with `ssh -F ssh_config example`. You just need to accept the fingerprint.

The VM's hard drive is a file name `nixos.qcow2` in this directory. It is created when you first create the VM and re-used since. You can just remove it when you're done.

That being said, the VM uses `tmpfs` to create the writable nix store so if you stumble in a disk
space issue, you must increase the
`virtualisation.vmVariantWithBootLoader.virtualisation.memorySize` setting.

### Secrets {#demo-nextcloud-tips-secrets}

_More info about the secrets can be found in the [Usage](https://shb.skarabox.com/usage.html) manual_

To open the `secrets.yaml` file and optionnally edit it, run:

```bash
SOPS_AGE_KEY_FILE=keys.txt nix run --impure nixpkgs#sops -- \
  --config sops.yaml \
  secrets.yaml
```

You can generate random secrets with:

```bash
nix run nixpkgs#openssl -- rand -hex 64
```

If you choose secrets too small, some services could refuse to start.

#### Why do we need the VM's public key {#demo-nextcloud-tips-public-key-necessity}

The [`sops.yaml`](./sops.yaml) file describes what private keys can decrypt and encrypt the
[`secrets.yaml`](./secrets.yaml) file containing the application secrets. Usually, you will create and add
secrets to that file and when deploying, it will be decrypted and the secrets will be copied
in the `/run/secrets` folder on the VM. We thus need one private key for you to edit the
[`secrets.yaml`](./secrets.yaml) file and one in the VM for it to decrypt the secrets.

Your private key is already pre-generated in this repo, it's the [`sshkey`](./sshkey) file. But when
creating the VM for Colmena, a new private key and its accompanying public key were automatically
generated under `/etc/ssh/ssh_host_ed25519_key` in the VM. We just need to get the public key and
add it to the `secrets.yaml` which we did in the Deploy section.

### SSH {#demo-nextcloud-tips-ssh}

The private and public ssh keys were created with:

```bash
ssh-keygen -t ed25519 -f sshkey
```

You don't need to copy over the ssh public key over to the VM as we set the `keyFiles` option which copies the public key when the VM gets created.
This allows us also to disable ssh password authentication.

For reference, if instead you didn't copy the key over on VM creating and enabled ssh
authentication, here is what you would need to do to copy over the key:

```bash
$ nix shell nixpkgs#openssh --command ssh-copy-id -i sshkey -F ssh_config example
```

### Deploy {#demo-nextcloud-tips-deploy}

If you get a NAR hash mismatch error like hereunder, you need to run `nix flake lock --update-input
selfhostblocks`.

```
error: NAR hash mismatch in input ...
```

### Update Demo {#demo-nextcloud-tips-update-demo}

If you update the Self Host Blocks configuration in `flake.nix` file, you can just re-deploy.

If you update the `configuration.nix` file, you will need to rebuild the VM from scratch.

If you update a module in the Self Host Blocks repository, you will need to update the lock file with:

```bash
nix flake lock --override-input selfhostblocks ../.. --update-input selfhostblocks
```
