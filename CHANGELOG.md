<!---

Template:

## Breaking Changes

## New Features

## User Facing Backwards Compatible Changes

## Fixes

## Other Changes

-->

# Upcoming Release

# v0.5.1

## New Features

- Added Karakeep service with SSO integration.
- Add SelfHostBlocks' `lib` into `pkgs.lib.shb`. Integrates with [Skarabox](https://github.com/ibizaman/skarabox/blob/631ff5af0b5c850bb63a3b3df451df9707c0af4e/template/flake.nix#L42-L43) too.

## Other Changes

- Moved implementation guide under contributing section.

# v0.5.0

## Breaking Changes

- Modules in the `nixosModules` output field do not anymore have the `system` in their path.
  `selfhostblocks.nixosModules.x86_64-linux.home-assistant` becomes `selfhostblocks.nixosModules.home-assistant`
  like it always should have been.

## Fixes

- Added test case making sure a user belonging to a not authorized LDAP group cannot login.
  Fixed Open WebUI module.
- Now importing a single module, like `selfhostblocks.nixosModules.home-assistant`, will
  import all needed block modules at the same time.

## Other Changes

- Nextcloud module can now setup SSO integration without setting up LDAP integration.

# v0.4.4

## New Features

- Added Pinchflat service with SSO integration. Declarative user creation only supported through SSO integration.
- Added Immich service with SSO integration.
- Added Open WebUI service with SSO integration.

# v0.4.3

## New Features

- Allow user to change their SSO password in Authelia.
- Make Audiobookshelf SSO integration respect admin users.

## Fixes

- Fix permission on Nextcloud systemd service.
- Delete Forgejo backups correctly to avoid them piling up.

## Other Changes

- Add recipes section to the documentation.

# v0.4.2

## New Features

- The LLDAP and Authelia modules gain a debug mode where a mitmdump instance is added so all traffic is printed.

## Fixes

- By default, LLDAP module only enforces groups declaratively. Users that are not defined declaratively
  are not anymore deleted by inadvertence.
- SSO integration with most services got fixed. A recent incompatible change in upstream Authelia broke most of them.
- Fixed PostgreSQL and Home Assistant modules after nixpkgs updates.
- Fixed Nextcloud module SSO integration with Authelia.
- Make Nextcloud SSO integration respect admin users.

# v0.4.1

## New Features

- LLDAP now manages users, groups, user attributes and group attributes declaratively.
- Individual modules are exposed in the flake output for each block and service.
- A mitmdump block is added that can be placed between two services and print all requests and responses.
- The SSO setup for Audiobookshelf is now a bit more declarative.

## Other Changes

- Forgejo got a new playwright test to check the LDAP integration.
- Some renaming options have been added retroactively for jellyfin and forgejo.

# v0.4.0

## Breaking Changes

- Rename ldap module to lldap as well as option name `shb.ldap` to `shb.lldap`.

## New Features

- Jellyfin service now waits for Jellyfin server to be fully available before starting.
- Add debug option for Jellyfin.
- Allow to choose port for Jellyfin.
- Make Jellyfin setup including initial admin user declarative.

## Fixes

- Fix Jellyfin redirect URI scheme after update.

## Other Changes

- Add documentation for LLDAP and Authelia block and link to it from other docs.

# v0.3.1

## Breaking Changes

- Default version of Nextcloud is now 30.
- Disable memories app on Nextcloud because it is broken.

## New Features

- Add patchNixpkgs function and pre-patched patchedNixpkgs output.

## Fixes

- Fix secrets passing to Nextcloud service after update.

## Other Changes

- Bump nixpkgs to https://github.com/NixOS/nixpkgs/commit/216207b1e58325f3590277d9102b45273afe9878

# v0.3.0

## New Features

- Add option to add extra args to hledger command.

## Breaking Changes

- Default version of Nextcloud is now 29.

## Fixes

- Home Assistant config gets correctly generated with secrets
  even if LDAP integration is not enabled.
- Fix Jellyfin SSO plugin which was left badly configured
  after a code refactoring.

## Other Changes

- Add a lot of playwright tests for services.
- Add service implementation manual page to document
  how to integrate a service in SHB.
- Add `update-redirects` command to manage the `redirect.json` page.
- Add home-assistant manual.

# v0.2.10

## New Features

- Add `shb.forgejo.users` option to create users declaratively.

## Fixes

- Make Nextcloud create the external storage if it's a local storage
  and the directory does not exist yet.
- Disable flow to change password on first login for admin Forgejo user.
  This is not necessary since the password comes from some secret store.

## Breaking Changes

- Fix internal link for Home Assistant
  which now points to the fqdn. This fixes Voice Assistant
  onboarding. This is a breaking change if one relies on
  reaching Home Assistant through the IP address but I
  don't recommend that. It's much better to have a DNS
  server running locally which redirects the fqdn to the
  server running Home Assistant.

## Other Changes

- Refactor tests and add playwright tests for services.

# v0.2.9

## New Features

- Add Memories Nextcloud app declaratively configured.
- Add Recognize Nextcloud app declaratively configured.

# v0.2.8

## New Features

- Add dashboard for SSL certificates validity
  and alert they did not renew on time.

## Fixes

- Only enable php-fpm exporter when php-fpm is enabled.

## Breaking Changes

- Remove upgrade script from postgres 13 to 14 and 14 to 15.

# v0.2.7

## New Features

- Add dashboard for Nextcloud with PHP-FPM exporter.
- Add voice option to Home-Assistant.

## User Facing Backwards Compatible Changes

- Add hostname and domain labels for scraped Prometheus metrics and Loki logs.

# v0.2.6

## New Features

- Add dashboard for deluge.

# v0.2.5

## Other Changes

- Fix more modules using backup contract.

# v0.2.4

## Other Changes

- Fix modules using backup contract.

# v0.2.3

## Breaking Changes

- Options `before_backup` and `after_backup` for backup contract have been renamed to
  `beforeBackup` and `afterBackup`.
- All options using the backup and databasebackup contracts now use the new style.

## Other Changes

- Show how to pin Self Host Blocks flake input to a tag.

# v0.2.2

## User Facing Backwards Compatible Changes

- Fix: add implementation for `sops.nix` module.

## Other Changes

- Use VERSION when rendering manual too.

# v0.2.1

## User Facing Backwards Compatible Changes

- Add `sops.nix` module to `nixosModules.default`.

## Other Changes

- Auto-tagging of git repo when VERSION file gets updated.
- Add VERSION file to track version.

# v0.2.0

## New Features

- Backup:
  - Add feature to backup databases with the database backup contract, implemented with `shb.restic.databases`.

## Breaking Changes

- Remove dependency on `sops-nix`.
- Rename `shb.nginx.autheliaProtect` to `shb.nginx.vhosts`. Indeed, the option allows to define a vhost with _optional_ Authelia protection but the former name made it look like Authelia protection was enforced.
- Rename all `shb.arr.*.APIKey` to `shb.arr.*.ApiKey`.
- Remove `shb.vaultwarden.ldapEndpoint` option because it was not used in the implementation anyway.
- Bump Nextcloud default version from 27 to 28. Add support for version 29.
- Deluge config breaks the authFile into an attrset of user to password file. Also deluge has tests now.
- Nextcloud now configures the LDAP app to use the `user_id` from LLDAP as the user ID used in Nextcloud. This makes all source of user - internal, LDAP and SSO - agree on the user ID.
- Authelia options changed:
  - `shb.authelia.oidcClients.id` -> `shb.authelia.oidcClients.client_id`
  - `shb.authelia.oidcClients.description` -> `shb.authelia.oidcClients.client_name`
  - `shb.authelia.oidcClients.secret` -> `shb.authelia.oidcClients.client_secret`
  - `shb.authelia.ldapEndpoint` -> `shb.authelia.ldapHostname` and `shb.authelia.ldapPort`
  - `shb.authelia.jwtSecretFile` -> `shb.authelia.jwtSecret.result.path`
  - `shb.authelia.ldapAdminPasswordFile` -> `shb.authelia.ldapAdminPassword.result.path`
  - `shb.authelia.sessionSecretFile` -> `shb.authelia.sessionSecret.result.path`
  - `shb.authelia.storageEncryptionKeyFile` -> `shb.authelia.storageEncryptionKey.result.path`
  - `shb.authelia.identityProvidersOIDCIssuerPrivateKeyFile` -> `shb.authelia.identityProvidersOIDCIssuerPrivateKey.result.path`
  - `shb.authelia.smtp.passwordFile` -> `shb.authelia.smtp.password.result.path`
- Make Nextcloud automatically disable maintenance mode upon service restart.
- `shb.ldap.ldapUserPasswordFile` -> `shb.ldap.ldapUserPassword.result.path`
- `shb.ldap.jwtSecretFile` -> `shb.ldap.jwtSecret.result.path`
- Jellyfin changes:
  - `shb.jellyfin.ldap.passwordFile` -> `shb.jellyfin.ldap.adminPassword.result.path`.
  - `shb.jellyfin.sso.secretFile` -> `shb.jellyfin.ldap.sharedSecret.result.path`.
  - + `shb.jellyfin.ldap.sharedSecretForAuthelia`.
- Forgejo changes:
  - `shb.forgejo.ldap.adminPasswordFile` -> `shb.forgejo.ldap.adminPassword.result.path`.
  - `shb.forgejo.sso.secretFile` -> `shb.forgejo.ldap.sharedSecret.result.path`.
  - `shb.forgejo.sso.secretFileForAuthelia` -> `shb.forgejo.ldap.sharedSecretForAuthelia.result.path`.
  - `shb.forgejo.adminPasswordFile` -> `shb.forgejo.adminPassword.result.path`.
  - `shb.forgejo.databasePasswordFile` -> `shb.forgejo.databasePassword.result.path`.
- Backup:
  - `shb.restic.instances` options has been split between `shb.restic.instances.request` and `shb.restic.instances.settings`, matching better with contracts.
- Use of secret contract everywhere.

## User Facing Backwards Compatible Changes

- Add mount contract.
- Export torrent metrics.
- Bump chunkSize in Nextcloud to boost performance.
- Fix home-assistant onboarding file generation. Added new VM test.
- OIDC and SMTP config are now optional in Vaultwarden. Added new VM test.
- Add default OIDC config for Authelia. This way, Authelia can start even with no config or only forward auth configs.
- Fix replaceSecrets function. It wasn't working correctly with functions from `lib.generators` and `pkgs.pkgs-lib.formats`. Also more test coverage.
- Add udev extra rules to allow smartctl Prometheus exporter to find NVMe drives.
- Revert Loki to major version 2 because upgrading to version 3 required manual intervention as Loki
  refuses to start. So until this issue is tackled, reverting is the best immediate fix.
  See https://github.com/NixOS/nixpkgs/commit/8f95320f39d7e4e4a29ee70b8718974295a619f4
- Add prometheus deluge exporter support. It just needs the `shb.deluge.prometheusScraperPasswordFile` option to be set.

## Other Changes

- Add pretty printing of test errors. Instead of:
  ```
  error: testRadarr failed: expected {"services":{"bazarr":{},"jackett":{},"lidarr":{},"nginx":{"enable":true},"radarr":{"dataDir":"/var/lib/radarr","enable":true,"group":"radarr","user":"radarr"},"readarr":{},"sonarr":{}},"shb":{"backup":{"instances":{"radarr":{"excludePatterns":[".db-shm",".db-wal",".mono"],"sourceDirectories":["/var/lib/radarr"]}}},"nginx":{"autheliaProtect":[{"authEndpoint":"https://oidc.example.com","autheliaRules":[{"domain":"radarr.example.com","policy":"bypass","resources":["^/api.*"]},{"domain":"radarr.example.com","policy":"two_factor","subject":["group:arr_user"]}],"domain":"example.com","ssl":null,"subdomain":"radarr","upstream":"http://127.0.0.1:7878"}]}},"systemd":{"services":{"radarr":{"serviceConfig":{"StateDirectoryMode":"0750","UMask":"0027"}}},"tmpfiles":{"rules":["d '/var/lib/radarr' 0750 radarr radarr - -"]}},"users":{"groups":{"radarr":{"members":["backup"]}}}}, but got {"services":{"bazarr":{},"jackett":{},"lidarr":{},"nginx":{"enable":true},"radarr":{"dataDir":"/var/lib/radarr","enable":true,"group":"radarr","user":"radarr"},"readarr":{},"sonarr":{}},"shb":{"backup":{"instances":{"radarr":{"excludePatterns":[".db-shm",".db-wal",".mono"],"sourceDirectories":["/var/lib/radarr"]}}},"nginx":{"vhosts":[{"authEndpoint":"https://oidc.example.com","autheliaRules":[{"domain":"radarr.example.com","policy":"bypass","resources":["^/api.*"]},{"domain":"radarr.example.com","policy":"two_factor","subject":["group:arr_user"]}],"domain":"example.com","ssl":null,"subdomain":"radarr","upstream":"http://127.0.0.1:7878"}]}},"systemd":{"services":{"radarr":{"serviceConfig":{"StateDirectoryMode":"0750","UMask":"0027"}}},"tmpfiles":{"rules":["d '/var/lib/radarr' 0750 radarr radarr - -"]}},"users":{"groups":{"radarr":{"members":["backup"]}}}}
  ```
  You now see:
  ```
  error: testRadarr failed (- expected, + result)
   {
     "dictionary_item_added": [
       "root['shb']['nginx']['vhosts']"
     ],
     "dictionary_item_removed": [
       "root['shb']['nginx']['authEndpoint']"
     ]
   }
  ```
- Made Nextcloud LDAP setup use a hardcoded configID. This makes the detection of an existing config much more robust.

# 0.1.0

Creation of CHANGELOG.md
