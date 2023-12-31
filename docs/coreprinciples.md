# Core Principles {#core-principles}

## Best practices by default {#core-principles-best-practices}

Backups, SSL, monitoring, etc. should be enabled by default and should be easier to configure than
not having those.

## Contracts With Tests {#core-principles-contracts}

Each building block defines a part of what a self-hosted app should provide. For example, HTTPS
access through a subdomain or Single Sign-On.

The goal of SHB is to make sure those blocks all fit together, whatever the actual implementation.
For example, the subdomain access could be done using Caddy or Nginx. This is achieved by providing
an explicit contract for each block and validating that contract using NixOS VM integration tests.

Ensuring the blocks respect their respective contracts is done through module and NixOS VM tests.

## Nixpkgs First {#core-principles-nixpkgs}

SHB uses as many packages already defined in [nixpkgs](https://github.com/NixOS/nixpkgs) as
possible. Not doing so would be at minimum a terrible waste of time and efficiency.

SHB should then be the smallest amount of code above what is available in nixpkgs. It should be the
minimum necessary to make packages available there conform with the contracts. This way, there are
less chance of breakage when nixpkgs gets updated. Related, SHB should contribute as much upstream
as it makes sense.

## Be a library, not a framework {#core-principles-library}

Users should be able to pick one block from SHB and add it to their pre-existing system.

Deploying SHB to a machine is done through any of the [supported
methods](https://nixos.wiki/wiki/Applications#Deployment) for NixOS.

As few abstractions should be created as possible. Stick to NixOS modules.

## Perennial Software {#core-principles-perennial}

Thanks to the principles above, I believe Self Host Blocks can be useful even if the project one day
does not get updates anymore. You can always copy parts you like and incorporate that in your own repository.
