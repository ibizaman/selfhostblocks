# Mailserver Service {#services-mailserver}

Defined in [`/modules/services/mailserver.nix`](@REPO@/modules/services/mailserver.nix).

This NixOS module is a service that sets up
the [NixOS Simple Mailserver](https://gitlab.com/simple-nixos-mailserver/nixos-mailserver) project.
It integrates the upstream project
with the SHB modules like the SSL module, the contract for secrets and the LLDAP module.

It also exposes an XML file which allows some email clients to auto configure themselves.

Setting up a self-hosted email server in this age
can be quite time consuming because you need to maintain
a good IP hygiene to avoid being marked as spam from the big players.
To avoid needing to deal with this,
this module provides the means
to use an email provider (like Fastmail or ProtonMail) as a mere proxy.
If you also setup the email provider using your own custom domain,
this combination allows you to change email provider
without needing to change your clients or notify your email correspondents
and keep a backup of all your emails at the same time.
The setup looks like so:

```
Domain --[ DNS records ]->  Email Provider  --[ mbsync  ]->  SHB Server

Internet <----------------  Email Provider  <-[ postfix ]--  SHB Server
```

Configuring your domain name to point to your email provider is out of scope here.
See the documentation for "custom domain" for you email provider,
like for [Fastmail](https://www.fastmail.com/features/domains/)
and [ProtonMail](https://proton.me/support/custom-domain)

To use an email provider as a proxy, use the
[shb.mailserver.imapSync](#services-mailserver-options-shb.mailserver.imapSync)
and [shb.mailserver.smtpRelay](#services-mailserver-options-shb.mailserver.smtpRelay),
options.

## Usage {#services-mailserver-usage}

The following snippet assumes a few blocks have been setup already:

- the [secrets block](usage.html#usage-secrets) with SOPS,
- the [`shb.ssl` block](blocks-ssl.html#usage),
- the [`shb.lldap` block](blocks-lldap.html#blocks-lldap-global-setup).

```nix
let
  domain = "example.com";
  username = "me@example.com";
in
{
  imports = [
    selfhostblocks.nixosModules.mailserver
  ];

  shb.mailserver = {
    enable = true;
    inherit domain;
    subdomain = "imap";
    ssl = config.shb.certs.certs.letsencrypt."domain";

    imapSync = {
      syncTimer = "10s";
      accounts.fastmail = {
        host = "imap.fastmail.com";
        port = 993;
        inherit username;
        password.result = config.shb.sops.secret."mailserver/imap/fastmail/password".result;
        mapSpecialJunk = "Spam";
      };
    };

    smtpRelay = {
      host = "smtp.fastmail.com";
      port = 587;
        inherit username;
      password.result = config.shb.sops.secret."mailserver/smtp/fastmail/password".result;
    };

    ldap = {
      enable = true;
      host = "127.0.0.1";
      port = config.shb.lldap.ldapPort;
      dcdomain = config.shb.lldap.dcdomain;
      adminName = "admin";
      adminPassword.result = config.shb.sops.secret."mailserver/ldap_admin_password".result;
      account = "fastmail";
    };
  };

  # Optionally add some mailboxes
  mailserver.mailboxes = {
    Drafts = {
      auto = "subscribe";
      specialUse = "Drafts";
    };
    Junk = {
      auto = "subscribe";
      specialUse = "Junk";
    };
    Sent = {
      auto = "subscribe";
      specialUse = "Sent";
    };
    Trash = {
      auto = "subscribe";
      specialUse = "Trash";
    };
    Archive = {
      auto = "subscribe";
      specialUse = "Archive";
    };
  };

  shb.sops.secret."mailserver/smtp/fastmail/password".request =
    config.shb.mailserver.smtpRelay.password.request;

  shb.sops.secret."mailserver/imap/fastmail/password".request =
    config.shb.mailserver.imapSync.accounts.fastmail.password.request;

  shb.sops.secret."mailserver/ldap_admin_password" = {
    request = config.shb.mailserver.ldap.adminPassword.request;
    # This reuses the admin password set in the shb.lldap module.
    settings.key = "lldap/user_password";
  };
}
```

### Secrets {#services-mailserver-usage-secrets}

Secrets can be randomly generated with `nix run nixpkgs#openssl -- rand -hex 64`.

### LDAP {#services-mailserver-usage-ldap}

The [user](#services-mailserver-options-shb.mailserver.ldap.userGroup)
LDAP group is created automatically.

### Disk Layout {#services-mailserver-usage-disk-layout}

The disk layout has been purposely set to use slashes `/` for subfolders.
By experience, this works better with iOS mail.

### Backup {#services-mailserver-usage-backup}

Backing up your emails using the [Restic block](blocks-restic.html) is done like so:

```nix
shb.restic.instances."mailserver" = {
  request = config.shb.mailserver.backup;
  settings = {
    enable = true;
  };
};
```

The name `"mailserver"` in the `instances` can be anything.
The `config.shb.mailserver.backup` option provides what directories to backup.
You can define any number of Restic instances to backup your emails multiple times.

You will then need to configure more options like the `repository`,
as explained in the [restic](blocks-restic.html) documentation.

### Certificates {#services-mailserver-certs}

For Let's Encrypt certificates, add:

```nix
let
  domain = "example.com";
in
{
  shb.certs.certs.letsencrypt.${domain}.extraDomains = [
    "${config.shb.mailserver.subdomain}.${config.shb.mailserver.domain}"
  ];
}
```

### Impermanence {#services-mailserver-impermanence}

To save the data folder in an impermanence setup, add:

```nix
{
  shb.zfs.datasets."safe/mailserver/index".path = config.shb.mailserver.impermanence.index;
  shb.zfs.datasets."safe/mailserver/mail".path = config.shb.mailserver.impermanence.mail;
  shb.zfs.datasets."safe/mailserver/sieve".path = config.shb.mailserver.impermanence.sieve;
  shb.zfs.datasets."safe/mailserver/dkim".path = config.shb.mailserver.impermanence.dkim;
}
```

### Declarative LDAP {#services-mailserver-declarative-ldap}

To add a user `USERNAME` to the user group, add:

```nix
shb.lldap.ensureUsers.USERNAME.groups = [
  config.shb.mailserver.ldap.userGroup
];
```

## Debug {#services-mailserver-debug}

Debugging this will be certainly necessary.
The first issue you will encounter will probably be with `mbsync`
under the [shb.mailserver.imapSync](#services-mailserver-options-shb.mailserver.imapSync) option
with the folder name mapping.

### Systemd Services {#services-mailserver-debug-systemd}

The 3 systemd services setup by this module are:

- `mbsync.service`
- `dovecot.service`
- `postfix.service`

### Folders {#services-mailserver-debug-folders}

The 4 folders where state is stored are:

- `config.mailserver.indexDir` = `/var/lib/dovecot/indices`
- `config.mailserver.mailDirectory` = `/var/vmail`
- `config.mailserver.sieveDirectory` = `/var/sieve`
- `config.mailserver.dkimKeyDirectory` = `/var/dkim`

### Open Ports {#services-mailserver-debug-ports}

The ports opened by default in this module are:

- Submissions: 465
- Imap: 993

You will need to forward those ports on your router
if you want to access to your emails from the internet.

The complete list can be found in the [upstream repository](https://gitlab.com/simple-nixos-mailserver/nixos-mailserver/-/blob/5965fae920b6b97f39f94bdb6195631e274c93a5/mail-server/networking.nix).

### List Email Provider Folder Mapping {#services-mailserver-debug-folder-mapping}

Replace `$USER` and `$PASSWORD` by those used to connect to your email provider.
Yes, you will need to enter verbatim `a LOGIN ...` and `b LIST "" "*"`.

```
$ nix run nixpkgs#openssl -- s_client -connect imap.fastmail.com:993 -crlf -quiet
a LOGIN $USER $password
b LIST "" "*"
```

Example output will be:

```
* LIST (\HasNoChildren) "/" INBOX
* LIST (\HasNoChildren \Drafts) "/" Drafts
* LIST (\HasNoChildren \Sent) "/" Sent
* LIST (\Noinferiors \HasNoChildren \Junk) "/" Spam

...
```

Here you can see the special folder `\Junk` is actually named `Spam`.
To handle this, set the `.mapSpecial*` options:

```
{
  shb.mailserver.imapSync.accounts.<account> = {
    mapSpecialJunk = "Spam";
  };
}
```

### List Local Folders {#services-mailserver-debug-local-folders}

Check the local folders to make sure the mapping is correct
and all folders are correctly downloaded.
For example, if the mapping above is wrong, you will see both a
`Junk` and `Spam` folder while if it is correct,
you will only see the `Junk` folder.

```
$ sudo doveadm mailbox list -u $USER
Junk
Trash
Drafts
Sent
INBOX
MyCustomFolder
```

The following command shows the number of messages in a folder:

```
$ sudo doveadm mailbox status -u $USER messages INBOX
INBOX messages=13591
```

If any folder is not appearing or has 0 message but should have some,
it could mean dovecot is not setup correctly and assumes an incorrect folder layout.
If that is the case, check the user config with:

```
$ sudo doveadm user $USER
field   value
uid     5000
gid     5000
home    /var/vmail/fastmail/$USER
mail    maildir:~/mail:LAYOUT=fs
virtualMail
```

### Test Auth {#services-mailserver-debug-auth}

To test authentication to your dovecot instance, run:

```
$ nix run nixpkgs#openssl -- s_client -connect $SUBDOMAIN.$DOMAIN:993 -crlf -quiet
. LOGIN $USER $PASSWORD
```

You must here also enter the second line verbatim,
replacing your user and password with the real one.

On success, you will see:

```
. OK [CAPABILITY IMAP4rev1 ...] Logged in
```

Otherwise, either if the password is wrong or,
when using LDAP if the user is not part of the LDAP group, you will see:

```
. NO [AUTHENTICATIONFAILED] Authentication failed.
```

To test the postfix instance, run:

```
$ swaks \
    --server $SUBDOMAIN.$DOMAIN \
    --port 465 \
    --tls-on-connect \
    --auth LOGIN \
    --auth-user $USER \
    --auth-password '$PASSWORD' \
    --from $USER \
    --to $USER
```

Try once with a wrong password and once with a correct one.
The former should log:

```
<~* 535 5.7.8 Error: authentication failed: (reason unavailable)
```

## Mobile Apps {#services-mailserver-mobile}

This module was tested with:
- the iOS mail mobile app,
- Thunderbird on NixOS.

The iOS mail app is pretty finicky.
If downloading emails does not work,
make sure the certificate used includes the whole chain:

```bash
$ openssl s_client -connect $SUBDOMAIN.$DOMAIN:993 -showcerts
```

Normally, the other options are setup correctly but if it fails for you,
feel free to open an issue.

## Options Reference {#services-mailserver-options}

```{=include=} options
id-prefix: services-mailserver-options-
list-id: selfhostblocks-service-mailserver-options
source: @OPTIONS_JSON@
```
