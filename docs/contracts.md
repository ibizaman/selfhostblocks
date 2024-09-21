# Contracts {#contracts}

A contract decouples modules that use a functionality from modules that provide it. A first
intuition for contracts is they are generally related to accessing a shared resource.

A few examples of contracts are generating SSL certificates, creating a user or knowing which files
and folders to backup. Indeed, when generating certificates, the service using those do not care how
they were created. They just need to know where the certificate files are located.

In practice, a contract is a set of options that any user of a contract expects to exist. Also, the
values of these options dictate the behavior of the implementation. This is enforced with NixOS VM
tests.

## Provided contracts {#contracts-provided}

Self Host Blocks is a proving ground of contracts. This repository adds a layer on top of services
available in nixpkgs to make them work using contracts. In time, we hope to upstream as much of this
as possible, reducing the quite thick layer that it is now.

Provided contracts are:

- [SSL generator contract](contracts-ssl.html) to generate SSL certificates.
  Two implementations are provided: self-signed and Let's Encrypt.
- [Backup contract](contracts-backup.html) to backup directories.
  This contract allows to backup multiple times the same directories for extra protection.
- [Secret contract](contracts-secret.html) to provide secrets that are deployed outside of the Nix store.

```{=include=} chapters html:into-file=//contracts-ssl.html
modules/contracts/ssl/docs/default.md
```

```{=include=} chapters html:into-file=//contracts-backup.html
modules/contracts/backup/docs/default.md
```

```{=include=} chapters html:into-file=//contracts-secret.html
modules/contracts/secret/docs/default.md
```

## Why do we need this new concept? {#contracts-why}

Currently in nixpkgs, every module needing access to a shared resource must implement the logic
needed to setup that resource themselves. Similarly, if the module is mature enough to let the user
select a particular implementation, the code lives inside that module.

![](./assets/contracts_before.png "A module composed of a core logic and a lot of peripheral logic.")

This has a few disadvantages:

- This leads to a lot of **duplicated code**. If a module wants to support a new implementation of a
contract, the maintainers of that module must write code to make that happen.
- This also leads to **tight coupling**. The code written by the maintainers cannot be reused in
  other modules, apart from copy pasting.
- There is also a **lack of separation of concerns**. The maintainers of a service must be experts
  in all implementations they let the users choose from.
- Finally, this is **not extensible**. If you, the user of the module, want to use another
  implementation that is not supported, you are out of luck. You can always dive into the module's
  code and extend it, but that is not an optimal experience.

We do believe that the decoupling contracts provides helps alleviate all the issues outlined above
which makes it an essential step towards more adoption of Nix, if only in the self hosting scene.

![](./assets/contracts_after.png "A module containing only logic using peripheral logic through contracts.")

Indeed, contracts allow:

- **Reuse of code**. Since the implementation of a contract lives outside of modules using it, using
  that implementation elsewhere is trivial.
- **Loose coupling**. Modules that use a contract do not care how they are implemented, as long as
  the implementation follows the behavior outlined by the contract.
- Full **separation of concerns** (see diagram below). Now, each party's concern is separated with a
  clear boundary. The maintainer of a module using a contract can be different from the maintainers
  of the implementation, allowing them to be experts in their own respective fields. But more
  importantly, the contracts themselves can be created and maintained by the community.
- Full **extensibility**. The final user themselves can choose an implementation, even new custom
  implementations not available in nixpkgs, without changing existing code.
- Last but not least, **Testability**. Thanks to NixOS VM test, we can even go one step further by
  ensuring each implementation of a contract, even custom ones, provides required options and
  behaves as the contract requires.

![](./assets/contracts_separationofconcerns.png "Separation of concerns thanks to contracts.")

## Are there contracts in nixpkgs already? {#contracts-nixpkgs}

Actually not quite, but close. There are some ubiquitous options in nixpkgs. Those I found are:

- `services.<name>.enable`
- `services.<name>.package`
- `services.<name>.openFirewall`
- `services.<name>.user`
- `services.<name>.group`

What makes those nearly contracts are:

- Pretty much every service provides them.
- Users of a service expects them to exist and expects a consistent type and behavior from them.
  Indeed, everyone knows what happens if you set `enable = true`.
- Maintainers of a service knows that users expects those options. They also know what behavior the
  user expects when setting those options.
- The name of the options is the same everywhere.

The only thing missing to make these explicit contracts is, well, the contracts themselves.
Currently, they are conventions and not contracts.
