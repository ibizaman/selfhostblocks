# Preface {#preface}

Self Host Blocks intends to help you self host any service you would like with best practices out of
the box.

::: {.note}
Self Host Blocks is hosted on [GitHub](https://github.com/ibizaman/selfhostblocks). If you encounter
problems or bugs then please report them on the [issue
tracker](https://github.com/ibizaman/selfhostblocks/issues).

Feel free to join the dedicated Matrix room
[matrix.org#selfhostblocks](https://matrix.to/#/#selfhostblocks:matrix.org).
:::

Self Host Blocks provides building blocks, each providing part of what a self hosted app should do
(SSO, HTTPS, backup, etc.). It also provides some services that are already integrated with all
those building blocks (Nextcloud, Home Assistant, etc.).

- You are new to self hosting and want pre-configured services to deploy easily. Look at the
  [services section](services.html).
- You are a seasoned self-hoster but want to enhance some services you deploy already. Go to the
  [blocks section](blocks.html).
- You are a user of Self Host Blocks but would like to use your own implementation for a block. Head
  over to the [matrix channel](https://matrix.to/#/#selfhostblocks:matrix.org) (this is WIP).

Self Host Blocks uses the full power of NixOS modules to achieve these goals. Blocks and service are
both NixOS modules.
