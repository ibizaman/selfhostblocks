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

For now, Self Host Blocks has a hard dependency on `sops-nix`. I am [working on removing
that](https://github.com/ibizaman/selfhostblocks/issues/24) so you can use any secrets manager you
want. Until then, you also need to import the `sops-nix` module:

```nix
imports = [
  inputs.selfhostblocks.inputs.sops-nix.nixosModules.default
];
```

Self Host Blocks provides its own `nixpkgs` input so both can be updated in lock step, ensuring
maximum compatibility. It is recommended to use the following `nixpkgs` as input for your deployments:

```nix
inputs.selfhostblocks.inputs.nixpkgs
```

Advanced users can if they wish use a version of `nixpkgs` of their choosing but then we cannot
guarantee Self Host Block won't use a non-existing option from `nixpkgs`.

To avoid manually updating the `nixpkgs` version, the [GitHub repository][1] for Self Host Blocks
tries to update the `nixpkgs` input daily, verifying all tests pass before accepting this new
`nixpkgs` version. The setup is explained in [this blog post][2].

[1]: https://github.com/ibizaman/selfhostblocks
[2]: https://blog.tiserbox.com/posts/2023-12-25-automated-flake-lock-update-pull-requests-and-merging.html

## Example Deployment With Colmena {#usage-example-colmena}

The following snippets show how to deploy Self Host Blocks using the deployment system [Colmena][3].

[3]: https://colmena.cli.rs

```nix
{
  inputs = {
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
        };
    };
  };
}
```

In the above snippet, `machine1` will use the `nixpkgs` version from your inputs while `machine2`
will use the `nixpkgs` version from `selfhostblocks`.
