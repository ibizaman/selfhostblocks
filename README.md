# Self Host Blocks

*Building blocks for self-hosting with best practices.*

SHB's (Self Host Blocks) goal is to provide a lower entry-bar for
self-hosting. I intend to achieve this by providing building blocks
promoting best practices to self-host a wide range of services. Also,
the design will be extendable to allow user defined services.

As far as features and best practices go, I intend to provide, for all
services:
- protection and single sign-on using [Keycloak](https://www.keycloak.org/), where possible
- automated backing up of data and databases with [Borgmatic](https://torsion.org/borgmatic/)
- encrypted external backup with [Rclone](https://rclone.org/)
- central logging, monitoring and dashboards with [Prometheus](prometheus.io/) and [Grafana](https://grafana.com/)
- integration with external services that are hard to self-host, like email sending
- deployment of services on the same or different machines
- home dashboard with [Dashy](https://github.com/lissy93/dashy)
- vault to store passwords and api keys using [Password Store](https://www.passwordstore.org/), those shouldn't be stored in config or on disk
- test changes using local virtual machines to avoid botching prod
- automated CI tests

Implementation is made with the disnix suite -
[Disnix](https://github.com/svanderburg/disnix),
[Dysnomia](https://github.com/svanderburg/dysnomia),
[NixOps](https://github.com/NixOS/nixops) - built on top of the nix
ecosystem.

## Progress Status

Currently, this repo is WIP and the first two services I intend to
provide are [Tiny Tiny RSS](https://tt-rss.org/) and
[Vaultwarden](https://github.com/dani-garcia/vaultwarden). Vaultwarden
was chosen as it's IMO the first stepping stone to enable
self-hosting. Tiny Tiny RSS was chosen because it requires quite a lot
of moving parts and also will allow me to test single sign-on.
