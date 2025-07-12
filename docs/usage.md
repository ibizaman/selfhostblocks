<!-- Read these docs at https://shb.skarabox.com -->
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

### Follow Nixpkgs {#usage-flake-nixpkgs}

Self Host Blocks provides its own `nixpkgs` input so both can be updated in lock step, ensuring
maximum compatibility. It is recommended to use the following `nixpkgs` as input for your
deployments. Also, patches can be applied by Self Host Blocks. To handle all this, you need the
following code instead wherever you import `nixpkgs`:

```nix
{
  inputs.selfhostblocks.url = "github:ibizaman/selfhostblocks";

  outputs = { selfhostblocks, ... }: let
    system = "x86_64-linux";
    shbLib = selfhostblocks.lib.${system};

    nixpkgs' = shbLib.patchedNixpkgs;

    shbNixpkgs = import nixpkgs' {
      inherit system;
    };
  in
```

Advanced users can if they wish use a version of `nixpkgs` of their choosing but then we cannot
guarantee Self Host Block won't use a non-existing option from `nixpkgs`.

### Tag Updates {#usage-flake-tag}

To pin Self Host Blocks to a release/tag, run the following snippet:

```nix
nix flake update --override-input selfhostblocks github:ibizaman/selfhostblocks/@VERSION@ selfhostblocks
```

Updating Self Host Blocks to a new version can be done the same way.

### Auto Updates {#usage-flake-autoupdate}

To avoid burden on the maintainers to keep `nixpkgs` input updated with upstream,
the [GitHub repository][1] for Self Host Blocks updates the `nixpkgs` input every couple days,
and verifies all tests pass before automatically merging the new `nixpkgs` version.
The setup is explained in [this blog post][2].

[repo]: https://github.com/ibizaman/selfhostblocks
[automerge]: https://blog.tiserbox.com/posts/2023-12-25-automated-flake-lock-update-pull-requests-and-merging.html

### Use SelfHostBlocks' lib {#usage-lib}

Access any functions exposed by the [lib][] with this snippet:

```nix
{
  inputs = {
    selfhostblocks.url = "github:ibizaman/selfhostblocks";
  };
  outputs = { selfhostblocks, ... }:
    let
      shblib = selfhostblocks.lib.${system};
    in
      {
        // Use shblib.replaceSecrets for example.
      }
}
```

[lib]: https://github.com/ibizaman/selfhostblocks/blob/main/lib/default.nix

## Example Deployment with Nixos-Rebuild {#usage-example-nixosrebuild}

The following snippets show how to deploy Self Host Blocks using the standard deployment system [nixos-rebuild][].

[nixos-rebuild]:https://nixos.org/manual/nixos/stable/#sec-changing-config

```nix
{
  inputs = {
    selfhostblocks.url = "github:ibizaman/selfhostblocks";
  };

  outputs = { self, selfhostblocks }: {
    let
      system = "x86_64-linux";
      shbLib = selfhostblocks.lib.${system};

      nixpkgs' = shbLib.patchedNixpkgs;

      nixosSystem' = import "${nixpkgs'}/nixos/lib/eval-config.nix";
    in
      nixosConfigurations = {
        machine = nixosSystem' {
          inherit system;
          modules = [
            selfhostblocks.nixosModules.${system}.default
          ];
        };
      };
  };
}
```

The above snippet assumes one machine to deploy to,
so `nixpkgs` is defined exclusively by the `selfhostblocks` input.
It is more likely that you have multiple machines,
some not using Self Host Blocks, then you can do the following:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    selfhostblocks.url = "github:ibizaman/selfhostblocks";
  };

  outputs = { self, selfhostblocks }: {
    let
      system = "x86_64-linux";
      shbLib = selfhostblocks.lib.${system};

      nixpkgs' = shbLib.patchedNixpkgs;

      shbNixpkgs = import nixpkgs' {
        inherit system;
      };
    in
      nixosConfigurations = {
        machine1 = nixpkgs.lib.nixosSystem {
        };

        machine2 = shbNixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            selfhostblocks.nixosModules.${system}.default
          ];
        };
      };
  };
}
```
In the above snippet, `machine1` will use the `nixpkgs` version from your inputs
while `machine2` will use the `nixpkgs` version from `selfhostblocks`.

## Example Deployment With Colmena {#usage-example-colmena}

The following snippets show how to deploy Self Host Blocks using the deployment system [Colmena][].

[colmena]: https://colmena.cli.rs

```nix
{
  inputs = {
    selfhostblocks.url = "github:ibizaman/selfhostblocks";
  };

  outputs = { self, selfhostblocks }: {
    let
      system = "x86_64-linux";
      shbLib = selfhostblocks.lib.${system};

      nixpkgs' = shbLib.patchedNixpkgs;

      shbNixpkgs = import nixpkgs' {
        inherit system;
      };
    in
      colmena = {
        meta = {
          nixpkgs = shbNixpkgs;
        };

        machine = { selfhostblocks, ... }: {
          imports = [
            selfhostblocks.nixosModules.${system}.default
          ];
        };
      };
  };
}
```

The above snippet assumes one machine to deploy to,
so `nixpkgs` is defined exclusively by the `selfhostblocks` input.
It is more likely that you have multiple machines,
some not using Self Host Blocks,
in this case you can use the `colmena.meta.nodeNixpkgs` option:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    selfhostblocks.url = "github:ibizaman/selfhostblocks";
  };

  outputs = { self, selfhostblocks }: {
    let
      system = "x86_64-linux";
      shbLib = selfhostblocks.lib.${system};

      nixpkgs' = shbLib.patchedNixpkgs;

      shbNixpkgs = import nixpkgs' {
        inherit system;
      };
    in
      colmena = {
        meta = {
          nixpkgs = import nixpkgs { inherit system; };

          nodeNixpkgs = {
            machine2 = shbNixpkgs;
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

In the above snippet, `machine1` will use the `nixpkgs` version from your inputs
while `machine2` will use the `nixpkgs` version from `selfhostblocks`.

## Example Deployment with deploy-rs {#usage-example-deployrs}

The following snippets show how to deploy Self Host Blocks using the deployment system [deploy-rs][].

[deploy-rs]: https://github.com/serokell/deploy-rs

```nix
{
  inputs = {
    selfhostblocks.url = "github:ibizaman/selfhostblocks";
  };

  outputs = { self, selfhostblocks }: {
    let
      system = "x86_64-linux";
      shbLib = selfhostblocks.lib.${system};

      nixpkgs' = shbLib.patchedNixpkgs;

      shbPkgs = import shbNixpkgs { inherit system; };

      deployPkgs = import selfhostblocks.inputs.nixpkgs {
        inherit system;
        overlays = [
          deploy-rs.overlay
          (self: super: {
            deploy-rs = {
              inherit (shbPkgs) deploy-rs;
              lib = super.deploy-rs.lib;
            };
          })
        ];
      };
    in
      nixosModules.machine = {
        imports = [
          selfhostblocks.nixosModules.${system}.default
        ];
      };

      nixosConfigurations.machine = shbNixpkgs.lib.nixosSystem {
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

The above snippet assumes one machine to deploy to,
so `nixpkgs` is defined exclusively by the `selfhostblocks` input.
It is more likely that you have multiple machines,
some not using Self Host Blocks,
in this case you can do:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    selfhostblocks.url = "github:ibizaman/selfhostblocks";
  };

  outputs = { self, selfhostblocks }: {
    let
      system = "x86_64-linux";
      shbLib = selfhostblocks.lib.${system};

      nixpkgs' = shbLib.patchedNixpkgs;

      shbPkgs = import nixpkgs' { inherit system; };

      deployPkgs = import selfhostblocks.inputs.nixpkgs {
        inherit system;
        overlays = [
          deploy-rs.overlay
          (self: super: {
            deploy-rs = {
              inherit (shbPkgs) deploy-rs;
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
          selfhostblocks.nixosModules.${system}.default
        ];
      };

      nixosConfigurations.machine1 = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          self.nixosModules.machine1
        ];
      };

      nixosConfigurations.machine2 = shbNixpkgs.lib.nixosSystem {
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
   shb.sops.secrets."nextcloud/adminpass".request = config.shb.nextcloud.adminPass.request;
   shb.nextcloud.adminPass.result = config.shb.sops.secrets."nextcloud/adminpass".result;
   ```
   The above snippet uses the [secrets contract](./contracts-secret.html)
   and [sops block](./blocks-sops.html) to ease the configuration.

## Complete Example {#usage-complete-example}

This is my own config, which is using Self Host Blocks
as well as [Skarabox][], my sibling project used to bootstrap a server.

[Skarabox]:  https://github.com/ibizaman/skarabox

`flake.nix`

```nix
{
  description = "Ibizaman's config.";

  inputs = {
    selfhostblocks.url = "github:ibizaman/selfhostblocks";

    skarabox.url = "github:ibizaman/skarabox";
    skarabox.inputs.nixpkgs.follows = "selfhostblocks/nixpkgs";

    deploy-rs.url = "github:serokell/deploy-rs";

    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs = { self, skarabox, selfhostblocks, sops-nix, deploy-rs }:
    let
      system = "x86_64-linux";
      shbLib = selfhostblocks.lib.${system};

      nixpkgs' = shbLib.patchedNixpkgs;

      shbPkgs = import nixpkgs' { inherit system; };

      # Taken from https://github.com/serokell/deploy-rs?tab=readme-ov-file#overall-usage
      deployPkgs = import selfhostblocks.inputs.nixpkgs {
        inherit system;
        overlays = [
          deploy-rs.overlay
          (self: super: {
            deploy-rs = {
              inherit (shbPkgs) deploy-rs;
              lib = super.deploy-rs.lib;
            };
          })
        ];
      };

      domain = # My domain here
    in
    {
      nixosModules.skarabox = {
        imports = [
          skarabox.nixosModules.skarabox
          selfhostblocks.nixosModules.${system}.default
          sops-nix.nixosModules.default
          ({ config, ... }: {
            skarabox.hostname = "skarabox";
            skarabox.username = "skarabox";
            skarabox.disks.rootDisk = "/dev/nvme0n1";
            # 10% of size SSD. Default value assumes drive size is 1 Tb.
            skarabox.disks.rootReservation = "100G";
            skarabox.disks.dataDisk1 = "/dev/sda";
            skarabox.disks.dataDisk2 = "/dev/sdb";
            # 5% of size Hard Drives. Default value assumes drive size is 10 Tb.
            skarabox.disks.dataReservation = "500G";
            skarabox.sshAuthorizedKeyFile = ./ssh_skarabox.pub;
            skarabox.hostId = builtins.readFile ./hostid;
            # Needed to be able to ssh to decrypt the SSD.
            boot.initrd.availableKernelModules = [
              "rtw88_8821ce"
              "r8169"
            ];
            sops.defaultSopsFile = ./secrets.yaml;
            sops.age = {
              sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
            };
          })
          {
            me.domain = domain;
          }

          ./configuration.nix
        ];
      };

      # Used with nixos-anywere for installation.
      nixosConfigurations.skarabox = shbNixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          self.nixosModules.skarabox
          {
            nix.settings.trusted-public-keys = [
              "selfhostblocks.cachix.org-1:H5h6Uj188DObUJDbEbSAwc377uvcjSFOfpxyCFP7cVs="
            ];

            nix.settings.substituters = [
              "https://selfhostblocks.cachix.org"
            ];
          }
        ];
      };

      # Used with deploy-rs for updates.
      deploy.nodes.skarabox = {
        hostname = domain;
        sshUser = "skarabox";
        sshOpts = [ "-o" "IdentitiesOnly=yes" "-i" "ssh_skarabox" ];
        activationTimeout = 600;
        profiles = {
          system = {
            user = "root";
            path = deployPkgs.deploy-rs.lib.activate.nixos self.nixosConfigurations.skarabox;
          };
        };
      };
      # From https://github.com/serokell/deploy-rs?tab=readme-ov-file#overall-usage
      checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;
    };
}
```

`configuration.nix`

```nix
{ config, lib, pkgs, ... }:
let
  inherit (lib) optionals optionalAttrs;
  inherit (config.me) domain;

  backupCfg = { enable ? true, shbOpt ? null }: name: let
    bck = (if shbOpt != null then shbOpt else config.shb.${name}.backup.request);
  in {
    shb.restic.instances.${name} = {
      request = bck;
      settings = {
        enable = enable;

        passphrase.result = config.shb.sops.secret."${name}/backup/passphrase".result;

        repository = {
          path = "/srv/backup/restic/skarabox/${name}";
          timerConfig = {
            OnBootSec = "15min";
            OnUnitActiveSec = "1h";
            RandomizedDelaySec = "7min";
          };
        };

        retention = {
          keep_within = "1d";
          keep_hourly = 24;
          keep_daily = 7;
          keep_weekly = 4;
          keep_monthly = 6;
        };
      };
    };
    shb.sops.secret."${name}/backup/passphrase" = {
      request = config.shb.restic.instances.${name}.settings.passphrase.request;
    };
    shb.sops.secret."${name}/backup/b2_access_key_id" = {
      request = config.shb.restic.instances.${name}.settings.passphrase.request;
      settings.key = "backup/b2/access_key_id";
    };
    shb.sops.secret."${name}/backup/b2_secret_access_key" = {
      request = config.shb.restic.instances.${name}.settings.passphrase.request;
      settings.key = "backup/b2/secret_access_key";
    };
  };
in
{
  options = {
    me.domain = lib.mkOption {
      type = lib.types.str;
    };
  };

  config = lib.mkMerge [
    {
      shb.zfs.defaultPoolName = "root";
      sops.defaultSopsFile = ./secrets.yaml;
    }
    {
      services.openssh.listenAddresses = [
        {
          addr = "0.0.0.0"; # Needs to be 0.0.0.0 otherwise it cannot bind on boot.
          port = 22;
        }
        {
          addr = "0.0.0.0";
          port = 2222;
        }
      ];
      networking.firewall.allowedTCPPorts = [ 2222 ];
    }
    {
      networking.firewall.allowedUDPPorts = [ 53 ];
      services.dnsmasq = {
        enable = true;
        settings = {
          # When switching DNS server, accept old leases from previous server.
          dhcp-authoritative = true;

          dhcp-range = "192.168.1.101,192.168.1.150,255.255.255.0,6h";

          dhcp-host = [
            "aa:bb:cc:dd:ee:ff,skarabox,192.168.1.30,infinite"
          ];

          dhcp-option = [
            "3,192.168.1.1"
          ];

          server = [
            # Stubby
            # Also https://wiki.archlinux.org/title/Stubby#Change_port
            "127.0.0.1#53000"
            "::1#53000"
          ];

          log-queries = false;

          # For stubby
          proxy-dnssec = true;

          inherit domain;
          no-resolv = true;
          bogus-priv = true;
          strict-order = true;
          # Got issues with bind-interface on startup, needing to restart dnsmasq for it to listen correctly.
          # bind-interfaces = true;
          # add-cpe-id = 858972;
          address = (map (hostname: "/${hostname}.${domain}/192.168.1.30") [
            "authelia"
            "ldap"

            "forgejo"
            "grafana"
            "ha"
            "hledger"
            "jellyfin"
            "n"
            "vaultwarden"

            "deluge"
            "radarr"
            "sonarr"
            "jackett"
          ])
          ++ (map (hostname: "/${hostname}.${domain}/192.168.1.1") [
            "router"
          ]);
        };
      };

      services.stubby = {
        enable = true;
        # https://github.com/getdnsapi/stubby/blob/develop/stubby.yml.example
        settings = pkgs.stubby.passthru.settingsExample // {
          listen_addresses = [
            "127.0.0.1@53000"
            "0::1@53000"
          ];
          # https://dnsprivacy.org/public_resolvers/
          # digest from https://nixos.wiki/wiki/Encrypted_DNS#Stubby
          upstream_recursive_servers = [{
            address_data = "9.9.9.9";
            tls_auth_name = "dns.quad9.net";
            tls_pubkey_pinset = [{
              digest = "sha256";
              value = "i2kObfz0qIKCGNWt7MjBUeSrh0Dyjb0/zWINImZES+I=";
            }];
          } {
            address_data = "149.112.112.112";
            tls_auth_name = "dns.quad9.net";
            tls_pubkey_pinset = [{
              digest = "sha256";
              value = "i2kObfz0qIKCGNWt7MjBUeSrh0Dyjb0/zWINImZES+I=";
            }];
          }];
        };
      };
    }
    {
      services.nginx.enable = true;
      shb.nginx.accessLog = true;
      networking.firewall.allowedTCPPorts = [ 80 443 ];

      # Need to wait on auth endpoint to be available otherwise nginx can fail to start.
      systemd.services.nginx = {
        wants = optionals config.services.dnsmasq.enable [ "dnsmasq.service" ];
        after = optionals config.services.dnsmasq.enable [ "dnsmasq.service" ];
      };
    }

    (optionalAttrs true {
      shb.user.acme = {
        uid = 995;
        gid = 994;
      };

      shb.certs.certs.letsencrypt.${domain} = {
        inherit domain;
        group = "nginx";
        reloadServices = [ "nginx.service" ];
        adminEmail = "ibizaman@${domain}";
        afterAndWants = optionals config.services.dnsmasq.enable [ "dnsmasq.service" ];
      };
    })

    (optionalAttrs true {
      shb.user.lldap = {
        uid = 991;
        gid = 989;
      };

      shb.certs.certs.letsencrypt.${domain}.extraDomains = [ "ldap.${domain}" ];
      shb.lldap = {
        enable = true;
        inherit domain;
        subdomain = "ldap";
        ssl = config.shb.certs.certs.letsencrypt.${domain};
        ldapPort = 3890;
        webUIListenPort = 17170;
        dcdomain = "dc=mydomain,dc=com";
        ldapUserPassword.result = config.shb.sops.secret."ldap/user_password".result;
        jwtSecret.result = config.shb.sops.secret."ldap/jwt_secret".result;
        # restrictAccessIPRange = "192.168.50.0/24";
        debug = false;
      };
      shb.sops.secret."ldap/user_password".request = config.shb.lldap.ldapUserPassword.request;
      shb.sops.secret."ldap/jwt_secret".request = config.shb.lldap.jwtSecret.request;

      shb.zfs.datasets."safe/ldap2".path = "/var/lib/private/lldap";

    })
    (backupCfg {
      shbOpt = {
        user = "root";
        sourceDirectories = [
          "/var/lib/private/lldap/"
        ];
      }; } "ldap")

    (optionalAttrs true {
      shb.user.authelia = {
        uid = 993;
        gid = 992;
      };

      shb.certs.certs.letsencrypt.${domain}.extraDomains = [ "authelia.${domain}" ];
      shb.authelia = {
        enable = true;
        inherit domain;
        subdomain = "authelia";
        ssl = config.shb.certs.certs.letsencrypt.${domain};

        ldapHostname = "127.0.0.1";
        ldapPort = config.shb.lldap.ldapPort;
        dcdomain = config.shb.lldap.dcdomain;

        smtp = {
          host = "smtp.eu.mailgun.org";
          port = 587;
          username = "postmaster@mg.${domain}";
          from_address = "authelia@${domain}";
          password.result = config.shb.sops.secret."authelia/smtp_password".result;
        };

        secrets = {
          jwtSecret.result = config.shb.sops.secret."authelia/jwt_secret".result;
          ldapAdminPassword.result = config.shb.sops.secret."authelia/ldap_admin_password".result;
          sessionSecret.result = config.shb.sops.secret."authelia/session_secret".result;
          storageEncryptionKey.result = config.shb.sops.secret."authelia/storage_encryption_key".result;
          identityProvidersOIDCHMACSecret.result = config.shb.sops.secret."authelia/hmac_secret".result;
          identityProvidersOIDCIssuerPrivateKey.result = config.shb.sops.secret."authelia/private_key".result;
        };
      };
      shb.sops.secret."authelia/jwt_secret".request = config.shb.authelia.secrets.jwtSecret.request;
      shb.sops.secret."authelia/ldap_admin_password".request = config.shb.authelia.secrets.ldapAdminPassword.request;
      shb.sops.secret."authelia/session_secret".request = config.shb.authelia.secrets.sessionSecret.request;
      shb.sops.secret."authelia/storage_encryption_key".request = config.shb.authelia.secrets.storageEncryptionKey.request;
      shb.sops.secret."authelia/hmac_secret".request = config.shb.authelia.secrets.identityProvidersOIDCHMACSecret.request;
      shb.sops.secret."authelia/private_key".request = config.shb.authelia.secrets.identityProvidersOIDCIssuerPrivateKey.request;
      shb.sops.secret."authelia/smtp_password".request = config.shb.authelia.smtp.password.request;

      # Need to wait on auth endpoint to be available otherwise nginx can fail to start.
      systemd.services."authelia-${domain}" = {
        wants = optionals config.services.dnsmasq.enable [ "dnsmasq.service" "nginx.service" ];
        after = optionals config.services.dnsmasq.enable [ "dnsmasq.service" "nginx.service" ];
      };

      shb.zfs.datasets."safe/authelia-${domain}" = config.shb.authelia.mount;
      shb.zfs.datasets."safe/authelia-redis" = config.shb.authelia.mountRedis;
    })

    (optionalAttrs true {
      shb.certs.certs.letsencrypt.${domain}.extraDomains = [ "forgejo.${domain}" ];
      shb.forgejo = {
        enable = true;
        subdomain = "forgejo";
        inherit domain;
        ssl = config.shb.certs.certs.letsencrypt."${domain}";
        adminPassword.result = config.shb.sops.secret."forgejo/adminPassword".result;
        databasePassword.result = config.shb.sops.secret."forgejo/databasePassword".result;
        repositoryRoot = "/srv/projects";

        smtp = {
          host = "smtp.eu.mailgun.org";
          port = 587;
          username = "postmaster@mg.${domain}";
          from_address = "authelia@${domain}";
          passwordFile = config.shb.sops.secret."forgejo/smtpPassword".result.path;
        };

        ldap = {
          enable = true;
          host = "127.0.0.1";
          port = config.shb.lldap.ldapPort;
          dcdomain = config.shb.lldap.dcdomain;
          adminPassword.result = config.shb.sops.secret."forgejo/ldap_admin_password".result;
        };

        sso = {
          enable = true;
          endpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
          clientID = "forgejo";

          sharedSecret.result = config.shb.sops.secret."forgejo/ssoSecret".result;
          sharedSecretForAuthelia.result = config.shb.sops.secret."forgejo/authelia/ssoSecret".result;
        };
      };
      services.forgejo.settings.repository.ENABLE_PUSH_CREATE_USER = true;

      # Need to wait on auth endpoint to be available otherwise nginx can fail to start.
      systemd.services."forgejo" = {
        wants = optionals config.services.dnsmasq.enable [ "dnsmasq.service" "nginx.service" ];
        after = optionals config.services.dnsmasq.enable [ "dnsmasq.service" "nginx.service" ];
      };

      nix.settings.trusted-users = [ "forgejo" ];
      users.users.forgejo.openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
      ];

      shb.sops.secret."forgejo/adminPassword" = {
        request = config.shb.forgejo.adminPassword.request;
      };
      shb.sops.secret."forgejo/databasePassword" = {
        request = config.shb.forgejo.databasePassword.request;
      };
      shb.sops.secret."forgejo/smtpPassword".request = {
        mode = "0400";
        owner = config.services.forgejo.user;
        restartUnits = [ "forgejo.service" ];
      };
      shb.sops.secret."forgejo/ldap_admin_password" = {
        request = config.shb.forgejo.ldap.adminPassword.request;
        settings.key = "ldap/user_password";
      };
      shb.sops.secret."forgejo/ssoSecret" = {
        request = config.shb.forgejo.sso.sharedSecret.request;
      };
      shb.sops.secret."forgejo/authelia/ssoSecret" = {
        request = config.shb.forgejo.sso.sharedSecretForAuthelia.request;
        settings.key = "forgejo/ssoSecret";
      };

      shb.zfs.datasets."safe/forgejo" = config.shb.forgejo.mount;
    })
    (optionalAttrs true (backupCfg {} "forgejo"))

    (optionalAttrs true {
      shb.user.vaultwarden = {
        uid = 989;
        gid = 987;
      };

      shb.certs.certs.letsencrypt.${domain}.extraDomains = [ "vaultwarden.${domain}" ];
      shb.vaultwarden = {
        enable = true;
        inherit domain;
        subdomain = "vaultwarden";
        ssl = config.shb.certs.certs.letsencrypt.${domain};
        port = 8222;
        authEndpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
        databasePassword.result = config.shb.sops.secret."vaultwarden/db".result;
        smtp = {
          host = "smtp.eu.mailgun.org";
          port = 587;
          username = "postmaster@mg.${domain}";
          from_address = "authelia@${domain}";
          password.result = config.shb.sops.secret."vaultwarden/smtp".result;
        };
      };
      shb.sops.secret."vaultwarden/db" = {
        request = config.shb.vaultwarden.databasePassword.request;
      };
      shb.sops.secret."vaultwarden/smtp" = {
        request = config.shb.vaultwarden.smtp.password.request;
      };

      shb.zfs.datasets."safe/vaultwarden" = config.shb.vaultwarden.mount;
      shb.zfs.datasets."safe/postgresql".path = "/var/lib/postgresql";
      systemd.services."restic-backups-vaultwarden_s3_s3.us-west-000.backblazeb2.com_skarabox-backup_vaultwarden.service" = {
        wants = optionals config.services.dnsmasq.enable [ "dnsmasq.service" ];
        after = optionals config.services.dnsmasq.enable [ "dnsmasq.service" ];
      };
      systemd.services."restic-backups-vaultwarden_srv_backup_restic_skarabox_vaultwarden.service" = {
        wants = optionals config.services.dnsmasq.enable [ "dnsmasq.service" ];
        after = optionals config.services.dnsmasq.enable [ "dnsmasq.service" ];
      };

    })
    (optionalAttrs true (backupCfg {} "vaultwarden"))

    (optionalAttrs true {
      shb.zfs.datasets."safe/nextcloud".path = "/var/lib/nextcloud";
      shb.zfs.datasets."safe/redis-nextcloud".path = "/var/lib/redis-nextcloud";
      shb.zfs.datasets."nextcloud" = {
        poolName = "zdata";
        path = "/srv/nextcloud/data";
      };
      shb.user.nextcloud.uid = 10020;

      shb.certs.certs.letsencrypt.${domain}.extraDomains = [ "n.${domain}" ];
      shb.nextcloud = {
        enable = true;
        debug = false;
        inherit domain;
        subdomain = "n";
        ssl = config.shb.certs.certs.letsencrypt.${domain};
        defaultPhoneRegion = "US";

        version = 29;
        dataDir = "/var/lib/nextcloud";
        adminPass.result = config.shb.sops.secret."nextcloud/adminpass".result;
        apps = {
          previewgenerator.enable = true;
          externalStorage = {
            enable = true;
            userLocalMount.directory = "/srv/nextcloud/data/$user/files";
            userLocalMount.mountName = "/";
          };
          ldap = {
            enable = true;
            host = "127.0.0.1";
            port = config.shb.lldap.ldapPort;
            dcdomain = config.shb.lldap.dcdomain;
            adminName = "admin";
            adminPassword.result = config.shb.sops.secret."nextcloud/ldap_admin_password".result;
            userGroup = "nextcloud_user";
          };
          sso = {
            enable = true;
            endpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
            clientID = "nextcloud";

            secret.result = config.shb.sops.secret."nextcloud/sso/secret".result;
            secretForAuthelia.result = config.shb.sops.secret."authelia/nextcloud_sso_secret".result;

            fallbackDefaultAuth = false;
          };
        };
        extraApps = apps: {
          inherit (apps)
            bookmarks
            calendar
            contacts
            groupfolders
            mail
          ;
        };
        postgresSettings = {
          # From https://pgtune.leopard.in.ua/ with:

          # DB Version: 14
          # OS Type: linux
          # DB Type: dw
          # Total Memory (RAM): 12 GB
          # CPUs num: 4
          # Connections num: <none>
          # Data Storage: ssd

          max_connections = "400";
          shared_buffers = "3GB";
          effective_cache_size = "9GB";
          maintenance_work_mem = "768MB";
          checkpoint_completion_target = "0.9";
          wal_buffers = "16MB";
          default_statistics_target = "100";
          random_page_cost = "1.1";
          effective_io_concurrency = "200";
          work_mem = "7864kB";
          huge_pages = "off";
          min_wal_size = "1GB";
          max_wal_size = "4GB";
          max_worker_processes = "4";
          max_parallel_workers_per_gather = "2";
          max_parallel_workers = "4";
          max_parallel_maintenance_workers = "2";
        };
        # Chose static and small number of children to avoid too much I/O strain on hard drives.
        phpFpmPoolSettings = {
          "pm" = "static";
          "pm.max_children" = 150;
        };
      };
      systemd.services.postgresql.serviceConfig.Restart = "always";
      # Secret needed for services.nextcloud.config.adminpassFile.
      shb.sops.secret."nextcloud/adminpass" = {
        request = config.shb.nextcloud.adminPass.request;
      };
      shb.sops.secret."nextcloud/ldap_admin_password" = {
        request = config.shb.nextcloud.apps.ldap.adminPassword.request;
        settings.key = "ldap/user_password";
      };

      shb.sops.secret."nextcloud/sso/secret" = {
        request = config.shb.nextcloud.apps.sso.secret.request;
      };
      shb.sops.secret."authelia/nextcloud_sso_secret" = {
        request = config.shb.nextcloud.apps.sso.secretForAuthelia.request;
        settings.key = "nextcloud/sso/secret";
      };
    })
    (optionalAttrs true (backupCfg {} "nextcloud"))
    (optionalAttrs true (backupCfg {
      shbOpt = {
        user = "nextcloud";
        sourceDirectories = [
          "/srv/nextcloud/data"
        ];
      };
    } "nextcloud-data"))

    (optionalAttrs true {
      shb.user.jellyfin = {
        uid = 984;
        gid = 981;
        extraGroups = [ "media" ];
      };

      shb.certs.certs.letsencrypt.${domain}.extraDomains = [ "jellyfin.${domain}" ];
      shb.jellyfin = {
        enable = true;
        inherit domain;
        subdomain = "jellyfin";
        ssl = config.shb.certs.certs.letsencrypt.${domain};
        ldap = {
          enable = true;
          host = "127.0.0.1";
          port = config.shb.lldap.ldapPort;
          dcdomain = config.shb.lldap.dcdomain;
          adminPassword.result = config.shb.sops.secret."jellyfin/ldap_password".result;
          userGroup = "jellyfin_user";
        };
        sso = {
          enable = true;
          endpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
          clientID = "jellyfin";
          sharedSecret.result = config.shb.sops.secret."jellyfin/sso_secret".result;
          sharedSecretForAuthelia.result = config.shb.sops.secret."jellyfin/authelia/sso_secret".result;
          userGroup = "jellyfin_user";
          adminUserGroup = "jellyfin_admin";
        };
      };
      shb.sops.secret."jellyfin/ldap_password" = {
        request = config.shb.jellyfin.ldap.adminPassword.request;
        settings.key = "ldap/user_password";
      };
      shb.sops.secret."jellyfin/sso_secret" = {
        request = config.shb.jellyfin.sso.sharedSecret.request;
      };
      shb.sops.secret."jellyfin/authelia/sso_secret" = {
        request = config.shb.jellyfin.sso.sharedSecretForAuthelia.request;
        settings.key = "jellyfin/sso_secret";
      };

      shb.zfs.datasets."safe/jellyfin".path = "/var/lib/jellyfin";
    })
    (backupCfg {} "jellyfin")

    (optionalAttrs true {
      shb.user.hass = {
        uid = 286;
        gid = 286;
      };

      shb.certs.certs.letsencrypt.${domain}.extraDomains = [ "ha.${domain}" ];
      shb.home-assistant = {
        enable = true;
        inherit domain;
        subdomain = "ha";
        ssl = config.shb.certs.certs.letsencrypt.${domain};

        config = {
          name = "Skarabox";
          country.source = config.shb.sops.secret."home-assistant/country".result.path;
          latitude.source = config.shb.sops.secret."home-assistant/latitude_home".result.path;
          longitude.source = config.shb.sops.secret."home-assistant/longitude_home".result.path;
          time_zone.source = config.shb.sops.secret."home-assistant/time_zone".result.path;
          unit_system = "metric";
        };

        ldap = {
          enable = true;
          host = "127.0.0.1";
          port = config.shb.lldap.webUIListenPort;
          userGroup = "homeassistant_user";
        };
      };
      shb.sops.secret."home-assistant/country".request = {
        mode = "0440";
        owner = "hass";
        group = "hass";
        restartUnits = [ "home-assistant.service" ];
      };
      shb.sops.secret."home-assistant/latitude_home".request = {
        mode = "0440";
        owner = "hass";
        group = "hass";
        restartUnits = [ "home-assistant.service" ];
      };
      shb.sops.secret."home-assistant/longitude_home".request = {
        mode = "0440";
        owner = "hass";
        group = "hass";
        restartUnits = [ "home-assistant.service" ];
      };
      shb.sops.secret."home-assistant/time_zone".request = {
        mode = "0440";
        owner = "hass";
        group = "hass";
        restartUnits = [ "home-assistant.service" ];
      };
      services.home-assistant = {
        extraComponents = [
          "accuweather"
          "apple_tv"
          "asuswrt"
          "backup"
          "bluetooth"
          "cast"
          "deluge"
          "esphome"
          "ibeacon"
          "icloud"
          "ipp"
          "jellyfin"
          "kegtron"
          "kodi"
          "nest"
          "nmap_tracker"
          "openweathermap"
          "oralb"
          "overkiz"
          "philips_js"
          "radarr"
          "simplisafe"
          "somfy"
          "somfy_mylink"
          "sonarr"
          "sonos"
          "subaru"
          "tradfri"
          "wled"
          "zha"

          "assist_pipeline"
          "conversation"
          "piper"
          "wake_word"
          "whisper"
          "wyoming"
        ];

        # Need to add them manually by enabling advanced mode in user profile
        # then adding in Settings > Dashboards > Resources:
        #   - /local/nixos-lovelace-modules/mini-graph-card-bundle.js
        #   - /local/nixos-lovelace-modules/mini-media-player-bundle.js
        customLovelaceModules = with pkgs.home-assistant-custom-lovelace-modules; [
          mini-graph-card
          mini-media-player
        ];
        extraPackages = python3Packages: [
          python3Packages.grpcio  # Needed for nest
        ];
      };
      users.users.hass.extraGroups = [ "dialout" ];
      nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (pkgs.lib.getName pkg) [
        "python-nest"
      ];

      shb.zfs.datasets."safe/home-assistant".path = "/var/lib/hass";
    })
    (backupCfg {} "home-assistant")

    (optionalAttrs true {
      shb.user.grafana = {
        uid = 196;
        gid = 986;
      };
      shb.user.loki = {
        uid = 988;
        gid = 985;
      };
      shb.user.netdata = {
        uid = 987;
        gid = 984;
      };

      shb.certs.certs.letsencrypt.${domain}.extraDomains = [ "grafana.${domain}" ];
      shb.monitoring = {
        enable = true;
        inherit domain;
        subdomain = "grafana";
        ssl = config.shb.certs.certs.letsencrypt.${domain};

        contactPoints = [ "ibizaman@${domain}" ];
        adminPassword.result = config.shb.sops.secret."monitoring/admin_password".result;
        secretKey.result = config.shb.sops.secret."monitoring/secret_key".result;
        smtp = {
          from_address = "grafana@${domain}";
          from_name = "Grafana";
          host = "smtp.mailgun.org";
          port = 587;
          username = "postmaster@mg.${domain}";
          passwordFile = config.shb.sops.secret."monitoring/smtp".result.path;
        };
      };
      shb.sops.secret."monitoring/smtp".request = {
        mode = "0400";
        owner = "grafana";
        group = "grafana";
        restartUnits = [ "grafana.service" ];
      };
      shb.sops.secret."monitoring/admin_password".request = config.shb.monitoring.adminPassword.request;
      shb.sops.secret."monitoring/secret_key".request = config.shb.monitoring.secretKey.request;

      services.prometheus.scrapeConfigs = [
        {
          job_name = "netdata";
          metrics_path = "/api/v1/allmetrics?format=prometheus&help=yes&source=as-collected";
          static_configs = [
            {
              targets = ["192.168.50.168:19999"];
            }
          ];
        }
      ];

      shb.zfs.datasets."safe/grafana".path = "/var/lib/grafana";
      shb.zfs.datasets."safe/loki".path = "/var/lib/loki";
      shb.zfs.datasets."safe/netdata".path = "/var/lib/netdata";
    })

    (optionalAttrs true {
      shb.user.hledger.uid = 990;

      shb.certs.certs.letsencrypt.${domain}.extraDomains = [ "hledger.${domain}" ];
      shb.hledger = {
        enable = true;
        inherit domain;
        subdomain = "hledger";
        ssl = config.shb.certs.certs.letsencrypt.${domain};
        authEndpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
        localNetworkIPRange = "192.168.1.0/24";
      };

      shb.zfs.datasets."safe/hledger".path = "/var/lib/hledger";
    })
    (backupCfg {} "hledger")

    (optionalAttrs true {
      shb.vpn.nordvpnfr = {
        enable = true;
        provider = "nordvpn";
        dev = "tun2";
        routingNumber = 11;
        remoteServerIP = # One of the servers
        authFile = config.shb.sops.secret."nordvpnfr/auth".result.path;
        proxyPort = 12001;
      };
      shb.sops.secret."nordvpnfr/auth".request = {
        mode = "0440";
        restartUnits = [ "openvpn-nordvpnfr.service" ];
      };

      shb.user.deluge.uid = 10001;

      shb.certs.certs.letsencrypt.${domain}.extraDomains = [ "deluge.${domain}" ];
      shb.deluge = {
        enable = true;
        inherit domain;
        subdomain = "deluge";
        ssl = config.shb.certs.certs.letsencrypt.${domain};

        daemonPort = 58846;
        daemonListenPorts = [ 6881 6889 ];
        webPort = 8112;
        # Some things do not work with the proxy, so instead bind to the interface directly
        # proxyPort = config.shb.vpn.nordvpnus.proxyPort;
        outgoingInterface = config.shb.vpn.nordvpnfr.dev;
        authEndpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
        localclientPassword.result = config.shb.sops.secret."deluge/auth/localclient".result;
        extraUsers = {
          ibizaman.password.source = config.shb.sops.secret."deluge/auth/ibizaman".result.path;
        };
        prometheusScraperPassword.result = config.shb.sops.secret."deluge/auth/prometheus".result;
        settings = {
          downloadLocation = "/srv/downloads";
        };
        extraServiceConfig = {
          MemoryHigh = "5G";
          MemoryMax = "6G";
        };
        logLevel = "info";
      };
      shb.sops.secret."deluge/auth/localclient".request = config.shb.deluge.localclientPassword.request;
      shb.sops.secret."deluge/auth/ibizaman".request = {
        mode = "0440";
        owner = config.services.deluge.user;
        group = config.services.deluge.group;
        restartUnits = [ "deluged.service" "delugeweb.service" ];
      };
      shb.sops.secret."deluge/auth/prometheus".request = config.shb.deluge.prometheusScraperPassword.request;

      shb.zfs.datasets."safe/deluge".path = "/var/lib/deluge";
    })
    (backupCfg {} "deluge")

    (optionalAttrs true {
      shb.user.radarr.uid = 10010;
      shb.user.radarr.extraGroups = [ "media" ];
      shb.user.sonarr.uid = 10011;
      shb.user.sonarr.extraGroups = [ "media" ];
      shb.user.jackett.uid = 10015;

      shb.certs.certs.letsencrypt.${domain}.extraDomains = [
        "moviesdl.${domain}"
        "seriesdl.${domain}"
        "subtitlesdl.${domain}"
        "booksdl.${domain}"
        "musicdl.${domain}"
        "indexer.${domain}"
      ];
      shb.arr = {
        radarr = {
          subdomain = "radarr";
          inherit domain;
          enable = true;
          ssl = config.shb.certs.certs.letsencrypt.${domain};
          authEndpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
          settings = {
            ApiKey.source = config.shb.sops.secret."radarr/apikey".result.path;
          };
        };
        sonarr = {
          subdomain = "sonarr";
          inherit domain;
          enable = true;
          ssl = config.shb.certs.certs.letsencrypt."${domain}";
          authEndpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
          settings = {
            ApiKey.source = config.shb.sops.secret."sonarr/apikey".result.path;
          };
        };
        jackett = {
          subdomain = "jackett";
          inherit domain;
          enable = true;
          ssl = config.shb.certs.certs.letsencrypt."${domain}";
          authEndpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
          settings = {
            ApiKey.source = config.shb.sops.secret."jackett/apikey".result.path;
            ProxyType = "0";
            ProxyUrl = "127.0.0.1:${toString config.shb.vpn.nordvpnfr.proxyPort}";
          };
        };
      };
      shb.sops.secret."radarr/apikey".request = {
        mode = "0440";
        owner = "radarr";
        group = "radarr";
        restartUnits = [ "radarr.service" ];
      };
      shb.sops.secret."sonarr/apikey".request = {
        mode = "0440";
        owner = "sonarr";
        group = "sonarr";
        restartUnits = [ "sonarr.service" ];
      };
      shb.sops.secret."jackett/apikey".request = {
        mode = "0440";
        owner = "jackett";
        group = "jackett";
        restartUnits = [ "jackett.service" ];
      };

      shb.zfs.datasets."safe/radarr".path = "/var/lib/radarr";
      shb.zfs.datasets."safe/sonarr".path = "/var/lib/sonarr";
      shb.zfs.datasets."safe/jackett".path = "/var/lib/jackett";
    })
    (backupCfg { shbOpt = config.shb.arr.radarr; } "radarr")
    (backupCfg { shbOpt = config.shb.arr.sonarr; } "sonarr")
    (backupCfg { shbOpt = config.shb.arr.jackett; } "jackett")
  ];
}
```
