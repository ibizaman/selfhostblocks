<!-- Read these docs at https://shb.skarabox.com -->

# Usage {#usage}

## Flake {#usage-flake}

Self Host Blocks (SHB) is available as a flake. It also uses its own `pkgs.lib` and
`nixpkgs` and it is required to use the provided ones as input for your
deployments, otherwise you might end up blocked when SHB patches a
module, function or package. The following snippet is thus required to use Self
Host Blocks:

```nix
{
  inputs.selfhostblocks.url = "github:ibizaman/selfhostblocks";

  outputs = { selfhostblocks, ... }: let
    system = "x86_64-linux";
    nixpkgs' = selfhostblocks.lib.${system}.patchedNixpkgs;
  in
    nixosConfigurations = {
      myserver = nixpkgs'.nixosSystem {
        inherit system;
        modules = [
          selfhostblocks.nixosModules.default
          ./configuration.nix
        ];
      };
    };
}
```

::: {.info}
In case somehow this documentation became stale,
look at the examples in [`./demo/minimal/flake.nix`](@REPO@/demo/minimal/flake.nix)
which provides examples tested in CI - so assured to always be up to date -
on how to use SHB.
:::

### Modules {#usage-flake-modules}

The `default` module imports all modules except the SOPS module.
That module is only needed if you want to use [sops-nix](#usage-secrets) to manage secrets.

You can also import each module individually.
You might want to do this to only import SHB overlays if you actually intend to use them.
Importing the `nextcloud` module for example will anyway transitively import needed support modules
so you can't go wrong:

```diff
         modules = [
-          selfhostblocks.nixosModules.default
+          selfhostblocks.nixosModules.nextcloud
           ./configuration.nix
         ];
```

To list all modules, run:

```bash
$ nix flake show github:ibizaman/selfhostblocks --allow-import-from-derivation

...

├───nixosModules
│   ├───arr: NixOS module
│   ├───audiobookshelf: NixOS module
│   ├───authelia: NixOS module
│   ├───borgbackup: NixOS module
│   ├───davfs: NixOS module
│   ├───default: NixOS module
│   ├───deluge: NixOS module
│   ├───forgejo: NixOS module
│   ├───grocy: NixOS module
│   ├───hardcodedsecret: NixOS module
│   ├───hledger: NixOS module
│   ├───home-assistant: NixOS module
│   ├───immich: NixOS module
│   ├───jellyfin: NixOS module
│   ├───karakeep: NixOS module
│   ├───lib: NixOS module
│   ├───lldap: NixOS module
│   ├───mitmdump: NixOS module
│   ├───monitoring: NixOS module
│   ├───nextcloud-server: NixOS module
│   ├───nginx: NixOS module
│   ├───open-webui: NixOS module
│   ├───paperless: NixOS module
│   ├───pinchflat: NixOS module
│   ├───postgresql: NixOS module
│   ├───restic: NixOS module
│   ├───sops: NixOS module
│   ├───ssl: NixOS module
│   ├───tinyproxy: NixOS module
│   ├───vaultwarden: NixOS module
│   ├───vpn: NixOS module
│   └───zfs: NixOS module

...
```

### Patches {#usage-flake-patches}

To add your own patches on top of the patches provided by SHB,
you can remove the `patchedNixpkgs` line and instead apply the patches yourself:

```diff
-    nixpkgs' = selfhostblocks.lib.${system}.patchedNixpkgs;
+    pkgs = import selfhostblocks.inputs.nixpkgs {
+      inherit system;
+    };
+    nixpkgs' = pkgs.applyPatches {
+      name = "nixpkgs-patched";
+      src = selfhostblocks.inputs.nixpkgs;
+      patches = selfhostblocks.lib.${system}.patches;
+    };
+    nixosSystem' = import "${nixpkgs'}/nixos/lib/eval-config.nix";
   in
     nixosConfigurations = {
-      myserver = nixpkgs'.nixosSystem {
+      myserver = nixosSystem' {
```

### Overlays {#usage-flake-overlays}

SHB applies its own overlays using `nixpkgs.overlays`.
Each module provided by SHB set that option if needed.

If you don't want to have those overlays applied for modules you don't intend to use SHB for,
you will want to avoid importing the `default` module
and instead import only the module for the services or blocks you intend to use,
like shows in the [Modules](#usage-flake-modules) section.

### Substituter {#usage-flake-substituter}

You can also use the public cache as a substituter with:

```nix
nix.settings.trusted-public-keys = [
  "selfhostblocks.cachix.org-1:H5h6Uj188DObUJDbEbSAwc377uvcjSFOfpxyCFP7cVs="
];

nix.settings.substituters = [
  "https://selfhostblocks.cachix.org"
];
```

### Unfree {#usage-flake-unfree}

SHB does not necessarily attempt to provide only free packages.
Currently, the only module using unfree modules is the [Open WebUI](@REPO@/modules/services/open-webui.nix) one.

To be able to use that module, you can follow the [nixpkgs manual](https://nixos.org/manual/nixpkgs/stable/#sec-allow-unfree)
and set either:

```nix
{
  nixpkgs.config.allowUnfree = true;
}
```

or the option `nixpkgs.config.allowUnfreePredicate`.

### Tag Updates {#usage-flake-tag}

To pin SHB to a release/tag, you can either use an implicit or explicit way.

#### Implicit {#usage-flake-tag-implicit}

Here, use the usual `inputs` form:

```nix
{
  inputs.selfhostblocks.url = "github:ibizaman/selfhostblocks";
}
```

then use the `flake update --override-input` command:

```bash
nix flake update selfhostblocks \
  --override-input selfhostblocks github:ibizaman/selfhostblocks/@VERSION@
```

Note that running `nix flake update` will update the version of SHB to the latest from the main branch,
canceling the override you just did above.
So beware when running that command.

#### Explicit {#usage-flake-tag-explicit}

Here, set the version in the input directly:

```nix
{
  inputs.selfhostblocks.url = "github:ibizaman/selfhostblocks?ref=@VERSION@";
}
```

Note that running `nix flake update` in this case will not update SHB,
you must update the tag explicitly then run `nix flake update`.

### Auto Updates {#usage-flake-autoupdate}

To avoid burden on the maintainers to keep `nixpkgs` input updated with
upstream, the [GitHub repository][repo] for SHB updates the
`nixpkgs` input every couple days, and verifies all tests pass before
automatically merging the new `nixpkgs` version. The setup is explained in
[this blog post][automerge].

[repo]: https://github.com/ibizaman/selfhostblocks
[automerge]: https://blog.tiserbox.com/posts/2023-12-25-automated-flake-lock-update-pull-requests-and-merging.html

### Lib {#usage-flake-lib}

The `selfhostblocks.nixosModules.lib` module
adds a module argument called `shb` by setting the
`_module.args.shb` option.
It is imported by nearly all other SHB modules
but you could still import it on its own
if you want to access SHB's functions and no other module.

The library of functions is also available under the traditional
`selfhostblocks.lib` flake output.

The functions layout is, in pseudo-code:

- `shb.*` all functions from [`./lib/default.nix`](@REPO@/lib/default.nix).
- `shb.contracts.*` all functions from [`./modules/contracts/default.nix`](@REPO@/modules/contracts/default.nix).
- `shb.test.*` all functions from [`./test/common.nix`](@REPO@/test/common.nix).

## Example Deployments {#usage-examples}

### With Nixos-Rebuild {#usage-examples-nixosrebuild}

The following snippets show how to deploy SHB using the standard
deployment system [nixos-rebuild][nixos-rebuild].

[nixos-rebuild]: https://nixos.org/manual/nixos/stable/#sec-changing-config

```nix
{
  inputs = {
    selfhostblocks.url = "github:ibizaman/selfhostblocks";
  };

  outputs = { self, selfhostblocks }: let
    system = "x86_64-linux";
    nixpkgs' = selfhostblocks.lib.${system}.patchedNixpkgs;
  in {
    nixosConfigurations = {
      machine = nixpkgs'.nixosSystem {
        inherit system;
        modules = [
          selfhostblocks.nixosModules.default
        ];
      };
    };
  };
}
```

The above snippet assumes one machine to deploy to, so `nixpkgs` is defined
exclusively by the `selfhostblocks` input. It is more likely that you have
multiple machines, some not using SHB, then you can do the following:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    selfhostblocks.url = "github:ibizaman/selfhostblocks";
  };

  outputs = { self, selfhostblocks }: {
    let
      system = "x86_64-linux";
      nixpkgs' = selfhostblocks.lib.${system}.patchedNixpkgs;
    in
      nixosConfigurations = {
        machine1 = nixpkgs.lib.nixosSystem {
        };

        machine2 = nixpkgs'.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            selfhostblocks.nixosModules.default
          ];
        };
      };
  };
}
```

In the above snippet, `machine1` will use the `nixpkgs` version from your inputs
while `machine2` will use the `nixpkgs` version from `selfhostblocks`.

### With Colmena {#usage-examples-colmena}

The following snippets show how to deploy SHB using the deployment
system [Colmena][Colmena].

[colmena]: https://colmena.cli.rs

```nix
{
  inputs = {
    selfhostblocks.url = "github:ibizaman/selfhostblocks";
  };

  outputs = { self, selfhostblocks }: {
    let
      system = "x86_64-linux";
      nixpkgs' = selfhostblocks.lib.${system}.patchedNixpkgs;
      pkgs' = import nixpkgs' {
        inherit system;
      };
    in
      colmena = {
        meta = {
          nixpkgs = pkgs';
        };

        machine = { selfhostblocks, ... }: {
          imports = [
            selfhostblocks.nixosModules.default
          ];
        };
      };
  };
}
```

The above snippet assumes one machine to deploy to, so `nixpkgs` is defined
exclusively by the `selfhostblocks` input. It is more likely that you have
multiple machines, some not using SHB, in this case you can use the
`colmena.meta.nodeNixpkgs` option:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    selfhostblocks.url = "github:ibizaman/selfhostblocks";
  };

  outputs = { self, selfhostblocks }: {
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
      };

      nixpkgs' = selfhostblocks.lib.${system}.patchedNixpkgs;
      pkgs' = import nixpkgs' {
        inherit system;
      };
    in
      colmena = {
        meta = {
          nixpkgs = pkgs;

          nodeNixpkgs = {
            machine2 = pkgs';
          };
        };

        machine1 = ...;

        machine2 = { selfhostblocks, ... }: {
          imports = [
            selfhostblocks.nixosModules.default
          ];

          # Machine specific configuration goes here.
        };
      };
  };
}
```

In the above snippet, `machine1` will use the `nixpkgs` version from your inputs
while `machine2` will use the `nixpkgs` version from `selfhostblocks`.

### With Deploy-rs {#usage-examples-deploy-rs}

The following snippets show how to deploy SHB using the deployment
system [deploy-rs][deploy-rs].

[deploy-rs]: https://github.com/serokell/deploy-rs

```nix
{
  inputs = {
    selfhostblocks.url = "github:ibizaman/selfhostblocks";
  };

  outputs = { self, selfhostblocks }: {
    let
      system = "x86_64-linux";
      nixpkgs' = selfhostblocks.lib.${system}.patchedNixpkgs;
      pkgs' = import nixpkgs' {
        inherit system;
      };

      deployPkgs = import selfhostblocks.inputs.nixpkgs {
        inherit system;
        overlays = [
          deploy-rs.overlay
          (self: super: {
            deploy-rs = {
              inherit (pkgs') deploy-rs;
              lib = super.deploy-rs.lib;
            };
          })
        ];
      };
    in
      nixosModules.machine = {
        imports = [
          selfhostblocks.nixosModules.default
        ];
      };

      nixosConfigurations.machine = nixpkgs'.nixosSystem {
        inherit system;
        modules = [
          self.nixosModules.machine
        ];
      };

      deploy.nodes.machine = {
        hostname = ...;
        sshUser = ...;
        sshOpts = [ ... ];
        profiles = {
          system = {
            user = "root";
            path = deployPkgs.deploy-rs.lib.activate.nixos self.nixosConfigurations.machine;
          };
        };
      };

      # From https://github.com/serokell/deploy-rs?tab=readme-ov-file#overall-usage
      checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;
  };
}
```

The above snippet assumes one machine to deploy to, so `nixpkgs` is defined
exclusively by the `selfhostblocks` input. It is more likely that you have
multiple machines, some not using SHB, in this case you can do:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    selfhostblocks.url = "github:ibizaman/selfhostblocks";
  };

  outputs = { self, selfhostblocks }: {
    let
      system = "x86_64-linux";
      nixpkgs' = selfhostblocks.lib.${system}.patchedNixpkgs;
      pkgs' = import nixpkgs' {
        inherit system;
      };

      deployPkgs = import selfhostblocks.inputs.nixpkgs {
        inherit system;
        overlays = [
          deploy-rs.overlay
          (self: super: {
            deploy-rs = {
              inherit (pkgs') deploy-rs;
              lib = super.deploy-rs.lib;
            };
          })
        ];
      };
    in
      nixosModules.machine1 = {
        # ...
      };

      nixosModules.machine2 = {
        imports = [
          selfhostblocks.nixosModules.default
        ];
      };

      nixosConfigurations.machine1 = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          self.nixosModules.machine1
        ];
      };

      nixosConfigurations.machine2 = nixpkgs'.nixosSystem {
        inherit system;
        modules = [
          self.nixosModules.machine2
        ];
      };

      deploy.nodes.machine1 = {
        hostname = ...;
        sshUser = ...;
        sshOpts = [ ... ];
        profiles = {
          system = {
            user = "root";
            path = deployPkgs.deploy-rs.lib.activate.nixos self.nixosConfigurations.machine1;
          };
        };
      };

      deploy.nodes.machine2 = # Similar here

      # From https://github.com/serokell/deploy-rs?tab=readme-ov-file#overall-usage
      checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;
  };
}
```

In the above snippet, `machine1` will use the `nixpkgs` version from your inputs
while `machine2` will use the `nixpkgs` version from `selfhostblocks`.

## Secrets with sops-nix {#usage-secrets}

This section complements the official
[sops-nix](https://github.com/Mic92/sops-nix) guide.

Managing secrets is an important aspect of deploying. You cannot store your
secrets in nix directly because they get stored unencrypted and you don't want
that. We need to use another system that encrypts secrets when storing in the
nix store and then decrypts them on the target host upon system activation.
`sops-nix` is one of such system.

Sops-nix works by encrypting the secrets file with at least 2 keys. Your private
key and a private key from the target host. This way, you can edit the secrets
and the target host can decrypt the secrets. Separating the keys this way is
good practice because it reduces the impact of having one being compromised.

One way to setup secrets management using `sops-nix`:

1. Create your own private key that will be located in `keys.txt`. The public
   key will be printed on stdout.
   ```bash
   $ nix shell nixpkgs#age --command age-keygen -o keys.txt
   Public key: age1algdv9xwjre3tm7969eyremfw2ftx4h8qehmmjzksrv7f2qve9dqg8pug7
   ```
2. Get the target host's public key. We will use the key derived from the ssh
   key of the host.
   ```bash
   $ nix shell nixpkgs#ssh-to-age --command \
       sh -c 'ssh-keyscan -t ed25519 -4 <target_host> | ssh-to-age'
   # localhost:2222 SSH-2.0-OpenSSH_9.6
   age13wgyyae8epyw894ugd0rjjljh0rm98aurvzmsapcv7d852g9r5lq0pqfx8
   ```
3. Create a `sops.yaml` file that explains how sops-nix should encrypt the - yet
   to be created - `secrets.yaml` file. You can be creative here, but a basic
   snippet is:
   ```bash
   keys:
     - &me age1algdv9xwjre3tm7969eyremfw2ftx4h8qehmmjzksrv7f2qve9dqg8pug7
     - &target age13wgyyae8epyw894ugd0rjjljh0rm98aurvzmsapcv7d852g9r5lq0pqfx8
   creation_rules:
     - path_regex: secrets.yaml$
       key_groups:
       - age:
         - *me
         - *target
   ```
4. Create a `secrets.yaml` file that will contain the encrypted secrets as a
   Yaml file:
   ```bash
   $ SOPS_AGE_KEY_FILE=keys.txt nix run --impure nixpkgs#sops -- \
     secrets.yaml
   ```
   This will open your preferred editor. An example of yaml file is the
   following (secrets are elided for brevity):
   ```yaml
   nextcloud:
     adminpass: 43bb4b...
     onlyoffice:
       jwt_secret: 3a10fce3...
   ```
   The actual file on your filesystem will look like so, again with data elided:
   ```yaml
   nextcloud:
     adminpass: ENC[AES256_GCM,data:Tt99...GY=,tag:XlAqRYidkOMRZAPBsoeEMw==,type:str]
     onlyoffice:
       jwt_secret: ENC[AES256_GCM,data:f87a...Yg=,tag:Y1Vg2WqDnJbl1Xg2B6W1Hg==,type:str]
   sops:
     kms: []
     gcp_kms: []
     azure_kv: []
     hc_vault: []
     age:
       - recipient: age1algdv9xwjre3tm7969eyremfw2ftx4h8qehmmjzksrv7f2qve9dqg8pug7
         enc: |
           -----BEGIN AGE ENCRYPTED FILE-----
           YWdl...6g==
           -----END AGE ENCRYPTED FILE-----
       - recipient: age13wgyyae8epyw894ugd0rjjljh0rm98aurvzmsapcv7d852g9r5lq0pqfx8
         enc: |
           -----BEGIN AGE ENCRYPTED FILE-----
           YWdl...RA==
           -----END AGE ENCRYPTED FILE-----
     lastmodified: "2024-01-28T06:07:02Z"
     mac: ENC[AES256_GCM,data:lDJh...To=,tag:Opon9lMZBv5S7rRhkGFuQQ==,type:str]
     pgp: []
     unencrypted_suffix: _unencrypted
     version: 3.8.1
   ```

   To actually create random secrets, you can use:
   ```bash
   $ nix run nixpkgs#openssl -- rand -hex 64
   ```
5. Use `sops-nix` module in nix:
   ```bash
   imports = [
     inputs.sops-nix.nixosModules.default
     inputs.selfhostblocks.nixosModules.sops
   ];
   ```
   Import also the `sops` module provided by SHB.
6. Set default sops file:
   ```bash
   sops.defaultSopsFile = ./secrets.yaml;
   ```
   Setting the default this way makes all sops instances use that same file.
7. Reference the secrets in nix:
   ```nix
   shb.sops.secrets."nextcloud/adminpass".request = config.shb.nextcloud.adminPass.request;
   shb.nextcloud.adminPass.result = config.shb.sops.secrets."nextcloud/adminpass".result;
   ```
   The above snippet uses the [secrets contract](./contracts-secret.html) and
   [sops block](./blocks-sops.html) to ease the configuration.
