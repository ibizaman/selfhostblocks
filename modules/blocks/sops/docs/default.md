# SOPS Block {#blocks-sops}

Defined in [`/modules/blocks/sops.nix`](@REPO@/modules/blocks/sops.nix).

This block sets up a [sops-nix][] secret.

It is only a small layer on top of `sops-nix` options
to adapt it to the [secret contract](./contract-secret.html).

[sops-nix]: https://github.com/Mic92/sops-nix

## Provider Contracts {#blocks-sops-contract-provider}

This block provides the following contracts:

- [secret contract][] under the [`shb.sops.secrets`][secret] option.
  It is not yet tested with [contract tests][secret contract tests] but it is used extensively on several machines.

[secret]: #blocks-sops-options-shb.sops.secret
[secret contract]: contracts-secret.html
[secret contract tests]: @REPO@/test/contracts/secret.nix

As requested by the contract, when asking for a secret with the `shb.sops` module,
the path where the secret will be located can be found under the [`shb.sops.secrets.<name>.result`][result] option.

[result]: #blocks-sops-options-shb.sops.secret._name_.result

## Usage {#blocks-sops-usage}

First, a file with encrypted secrets must be created by following the [secrets setup section](usage.html#usage-secrets).

### With Requester Module {#blocks-sops-usage-requester}

This example shows how to use this sops block
to fulfill the request of a module using the [secret contract][] under the option `services.mymodule.mysecret`.

```nix

```

## Options Reference {#blocks-sops-options}

```{=include=} options
id-prefix: blocks-sops-options-
list-id: selfhostblocks-block-sops-options
source: @OPTIONS_JSON@
```
