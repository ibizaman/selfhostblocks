# Blocks {#blocks}

Blocks help you self-host apps or services. They implement a specific function like backup or secure
access through a subdomain. Each block is designed to be usable on its own and to fit nicely with
others.

In practice, a block implements a [contract](contracts.html) that must be followed to implement a
specific self-hosting function. It also comes with a unit test and NixOS VM test suite to ensure any
implementation follows the contract.

As an example, let's take the HTTPS access block which allows for a service to be accessible through
a specific subdomain. In Nix terms, this block defines at minimum the inputs:

- subdomain,
- domain,
- and upstream address of the service.

It defines no outputs but has one major side effect:

- the service should be accessible through HTTPS at `https://subdomain.domain`.

Anything that provides the inputs and expected outputs and side effects defined by the block can be
used to fulfill its contract. In this example, we could use any of Nginx, Caddy, Haproxy or others.

Self Host Blocks provides at least one implementation for each block and allows you to use your own
implementation if you want to, as long as it passes the tests. You can then use blocks to improve
services you already have deployed.

::: {.note}
Not all blocks are yet documented. You can find all available blocks [in the repository](@REPO@/modules/blocks).
:::

```{=include=} chapters html:into-file=//blocks-ssl.html
modules/blocks/ssl/docs/default.md
```

```{=include=} chapters html:into-file=//blocks-backup.html
modules/blocks/backup/docs/default.md
```

```{=include=} chapters html:into-file=//blocks-monitoring.html
modules/blocks/monitoring/docs/default.md
```
