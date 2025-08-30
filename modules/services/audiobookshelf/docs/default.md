# Audiobookshelf Service {#services-audiobookshelf}

Defined in [`/modules/services/audiobookshelf.nix`](@REPO@/modules/services/audiobookshelf.nix).

This NixOS module is a service that sets up a [Audiobookshelf](https://www.audiobookshelf.org/) instance.

## Features {#services-audiobookshelf-features}

- Declarative selection of listening port.
- Access through [subdomain](#services-audiobookshelf-options-shb.audiobookshelf.subdomain) using reverse proxy. [Manual](#services-audiobookshelf-usage-configuration).
- Access through [HTTPS](#services-audiobookshelf-options-shb.audiobookshelf.ssl) using reverse proxy. [Manual](#services-audiobookshelf-usage-https).
- Declarative [SSO](#services-audiobookshelf-options-shb.audiobookshelf.sso) configuration (Manual setup in app required). [Manual](#services-audiobookshelf-usage-sso).
- [Backup](#services-audiobookshelf-options-shb.audiobookshelf.backup) through the [backup block](./blocks-backup.html). [Manual](#services-audiobookshelf-usage-backup).

## Usage {#services-audiobookshelf-usage}

### Login

Upon first login, Audiobookshelf will ask you to create a root user. This user will be used to
set up [SSO]{#services-audiobookshelf-usage-sso}, or to provision admin privileges to other users.

### With SSO Support {#services-audiobookshelf-usage-sso}

:::: {.note}
Some manual setup in the app is required.
::::

We will use the [SSO block][] provided by Self Host Blocks.
Assuming it [has been set already][SSO block setup], add the following configuration:

[SSO block]: blocks-sso.html
[SSO block setup]: blocks-sso.html#blocks-sso-global-setup

```nix
shb.audiobookshelf.sso = {
  enable = true;
  endpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";

  secretFile = <path/to/oidcJellyfinSharedSecret>;
  secretFileForAuthelia = <path/to/oidcJellyfinSharedSecret>;
};
```

The `shb.audiobookshelf.sso.secretFile` and `shb.audiobookshelf.sso.secretFileForAuthelia` options
must have the same content. The former is a file that must be owned by the `audiobookshelf` user while
the latter must be owned by the `authelia` user. I want to avoid needing to define the same secret
twice with a future secrets SHB block.

In the Audiobookshelf app, you can now log in with your Audiobookshelf root user and go to
"Settings->Authentication", and then enable "OpenID Connect Authentication" and enter your
"Issuer URL" (e.g. `https://auth.example.com`). Then click the "Auto-populate" button. Next, paste
in the client secret (from `secrets.yaml`). Then set up "Client ID" to be `audiobookshelf`. Make
sure to also select `None` in "Subfolder for Redirect URLs". Then make sure to tick "Auto Register".
You can also tick "Auto Launch" to make Audiobookshelf automatically redirect users to the SSO
sign-in page instead. This can later be circumvented by accessing
`https://<your-domain>/login?autoLaunch=0`, if you're having SSO issues.
Finally, set "Group Claim" to `audiobookshelf_groups`. This enables Audiobookshelf to allow access
only to users belonging to `userGroup` (default `audiobookshelf_user`), and to grant admin
privileges to members of `adminUserGroup` (default `audiobookshelf_admin`).

Save the settings and restart the Audiobookshelf service (`systemctl restart audiobookshelf.service`).

You should now be able to log in with users belonging to either of the aforementioned allowed groups.
