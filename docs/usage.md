# Usage {#usage}

## Flake {#usage-flake}

Self Host Blocks is available as a flake. To use it in your project, add the following flake input:

```nix
inputs.selfhostblocks.url = "github:ibizaman/selfhostblocks";
```

Then, in your `nixosConfigurations`, import the module with:

```nix
imports = [
  inputs.selfhostblocks.nixosModules.x86_64-linux.default
];
```

You can also use the public cache as a substituter with:

```nix
nix.settings.trusted-public-keys = [
  "selfhostblocks.cachix.org-1:H5h6Uj188DObUJDbEbSAwc377uvcjSFOfpxyCFP7cVs="
];

nix.settings.substituters = [
  "https://selfhostblocks.cachix.org"
];
```

Self Host Blocks provides its own `nixpkgs` input so both can be updated in lock step, ensuring
maximum compatibility. It is recommended to use the following `nixpkgs` as input for your
deployments. Also, patches can be applied by Self Host Blocks. To handle all this, you need the
following code instead wherever you import `nixpkgs`:

```nix
let
  system = "x86_64-linux";
  originPkgs = selfhostblocks.inputs.nixpkgs;

  nixpkgs' = originPkgs.legacyPackages.${system}.applyPatches {
    name = "nixpkgs-patched";
    src = originPkgs;
    patches = selfhostblocks.patches.${system};
  };
in
  nixpkgs = import nixpkgs' {
    inherit system;
  };
```

Advanced users can if they wish use a version of `nixpkgs` of their choosing but then we cannot
guarantee Self Host Block won't use a non-existing option from `nixpkgs`.

To avoid manually updating the `nixpkgs` version, the [GitHub repository][1] for Self Host Blocks
tries to update the `nixpkgs` input daily, verifying all tests pass before accepting this new
`nixpkgs` version. The setup is explained in [this blog post][2].

[1]: https://github.com/ibizaman/selfhostblocks
[2]: https://blog.tiserbox.com/posts/2023-12-25-automated-flake-lock-update-pull-requests-and-merging.html

## Example Deployment with Nixos-Rebuild {#usage-example-nixosrebuild}

The following snippets show how to deploy Self Host Blocks using the standard deployment system `nixos-rebuild`.

```nix
{
  inputs = {
    selfhostblocks.url = "github:ibizaman/selfhostblocks";
  };

  outputs = { self, selfhostblocks }: {
    nixosConfigurations = {
      machine = selfhostblocks.inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          selfhostblocks.nixosModules.${system}.default
        ];

        # Machine specific configuration goes here.
      };
    };
  };
}
```

The above snippet is very minimal as it assumes you have only one machine to deploy to, so `nixpkgs`
is defined exclusively by the `selfhostblocks.inputs.nixpkgs` input. If some machines are not using
Self Host Blocks, you can do the following:

```nix
{
  inputs = {
    selfhostblocks.url = "github:ibizaman/selfhostblocks";
  };

  outputs = { self, selfhostblocks }: {
    nixosConfigurations = {
      machine1 = nixpkgs.lib.nixosSystem {
      };

      machine2 = selfhostblocks.inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          selfhostblocks.nixosModules.${system}.default
        ];

        # Machine specific configuration goes here.
      };
    };
  };
}
```

## Example Deployment With Colmena {#usage-example-colmena}

The following snippets show how to deploy Self Host Blocks using the deployment system [Colmena][3].

[3]: https://colmena.cli.rs

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    selfhostblocks.url = "github:ibizaman/selfhostblocks";
  };

  outputs = { self, selfhostblocks }: {
    colmena =
      let
        system = "x86_64-linux";
      in {
        meta = {
          nixpkgs = import selfhostblocks.inputs.nixpkgs { inherit system; };
        };

        machine = { selfhostblocks, ... }: {
          imports = [
            selfhostblocks.nixosModules.${system}.default
          ];

          # Machine specific configuration goes here.
        };
      };
  };
}
```

The above snippet is very minimal as it assumes you have only one machine to deploy to, so `nixpkgs`
is defined exclusively by the `selfhostblocks` input. It is more likely that you have multiple machines, in this case you can use the `colmena.meta.nodeNixpkgs` option:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    selfhostblocks.url = "github:ibizaman/selfhostblocks";
  };

  outputs = { self, selfhostblocks }: {
    colmena = {
      let
        system = "x86_64-linux";
      in {
        meta =
          nixpkgs = import nixpkgs { inherit system; };
          nodeNixpkgs = {
            machine2 = import selfhostblocks.inputs.nixpkgs { inherit system; };
          };
        };

        machine1 = ...;

        machine2 = { selfhostblocks, ... }: {
          imports = [
            selfhostblocks.nixosModules.${system}.default
          ];

          # Machine specific configuration goes here.
        };
    };
  };
}
```

In the above snippet, `machine1` will use the `nixpkgs` version from your inputs while `machine2`
will use the `nixpkgs` version from `selfhostblocks`.

## Secrets with sops-nix {#usage-secrets}

This section complements the official [sops-nix](https://github.com/Mic92/sops-nix) guide.

Managing secrets is an important aspect of deploying. You cannot store your secrets in nix directly
because they get stored unencrypted and you don't want that. We need to use another system that
encrypts secrets when storing in the nix store and then decrypts them on the target host upon system
activation. `sops-nix` is one of such system.

Sops-nix works by encrypting the secrets file with at least 2 keys. Your private key and a private
key from the target host. This way, you can edit the secrets and the target host can decrypt the
secrets. Separating the keys this way is good practice because it reduces the impact of having one
being compromised.

One way to setup secrets management using `sops-nix`:

1. Create your own private key that will be located in `keys.txt`. The public key will be printed on stdout.
   ```bash
   $ nix shell nixpkgs#age --command age-keygen -o keys.txt
   Public key: age1algdv9xwjre3tm7969eyremfw2ftx4h8qehmmjzksrv7f2qve9dqg8pug7
   ```
2. Get the target host's public key. We will use the key derived from the ssh key of the host.
   ```bash
   $ nix shell nixpkgs#ssh-to-age --command \
       sh -c 'ssh-keyscan -t ed25519 -4 <target_host> | ssh-to-age'
   # localhost:2222 SSH-2.0-OpenSSH_9.6
   age13wgyyae8epyw894ugd0rjjljh0rm98aurvzmsapcv7d852g9r5lq0pqfx8
   ```
3. Create a `sops.yaml` file that explains how sops-nix should encrypt the - yet to be created -
   `secrets.yaml` file. You can be creative here, but a basic snippet is:
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
4. Create a `secrets.yaml` file that will contain the encrypted secrets as a Yaml file:
   ```bash
   $ SOPS_AGE_KEY_FILE=keys.txt nix run --impure nixpkgs#sops -- \
     secrets.yaml
   ```
   This will open your preferred editor. An example of yaml file is the following (secrets are elided for brevity):
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
       selfhostblocks.inputs.sops-nix.nixosModules.default
   ];
   ```
6. Set default sops file:
   ```bash
   sops.defaultSopsFile = ./secrets.yaml;
   ```
   Setting the default this way makes all sops instances use that same file.
7. Reference the secrets in nix:
   ```nix
   shb.nextcloud.adminPass.result.path = config.sops.secrets."nextcloud/adminpass".path;

   sops.secrets."nextcloud/adminpass" = config.shb.nextcloud.adminPass.request;
   ```
   The above snippet uses the [secrets contract](./contracts-secret.html) to ease configuration.
