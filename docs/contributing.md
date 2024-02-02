# Contributing {#contributing}

All issues and Pull Requests are welcome!

For Pull Requests, if they are substantial changes, please open an issue to discuss the details
first.

## Chat Support {#contributing-chat}

Come hang out in the [Matrix channel](https://matrix.to/#/%23selfhostblocks%3Amatrix.org). :)

## Upstream Changes {#contributing-upstream}

One important goal of SHB is to be the smallest amount of code above what is available in
[nixpkgs](https://github.com/NixOS/nixpkgs). It should be the minimum necessary to make packages
available there conform with the contracts. This way, there are less chance of breakage when nixpkgs
gets updated. I intend to upstream to nixpkgs as much of those as makes sense.

## Run tests {#contributing-runtests}

Run all tests:

```bash
$ nix build .#checks.${system}.all
# or
$ nix flake check
# or
$ nix run github:Mic92/nix-fast-build -- --skip-cached --flake ".#checks.$(nix eval --raw --impure --expr builtins.currentSystem)"
```

Run one group of tests:

```bash
$ nix build .#checks.${system}.modules
$ nix build .#checks.${system}.vm_postgresql_peerAuth
```

Run one VM test interactively:

```bash
$ nix run .#checks.${system}.vm_postgresql_peerAuth.driverInteractive
```

When you get to the shell, run either `start_all()` or `test_script()`. The former just starts all
the VMs and service, then you can introspect. The latter also starts the VMs if they are not yet and
then will run the test script.

## Upload test results to CI {#contributing-upload}

Github actions do now have hardware acceleration, so running them there is not slow anymore. If
needed, the tests results can still be pushed to cachix so they can be reused in CI.

After running the `nix-fast-build` command from the previous section, run:

```bash
$ find . -type l -name "result-vm_*" | xargs readlink | nix run nixpkgs#cachix -- push selfhostblocks
```

## Deploy using colmena {#contributing-deploy-colmena}

```bash
$ nix run nixpkgs#colmena -- apply
```

## Use a local version of selfhostblocks {#contributing-localversion}

This works with any flake input you have. Either, change the `.url` field directly in you `flake.nix`:

```nix
selfhostblocks.url = "/home/me/projects/selfhostblocks";
```

Or override on the command line:

```bash
$ nix flake lock --override-input selfhostblocks ../selfhostblocks
```

I usually combine the override snippet above with deploying:

```bash
$ nix flake lock --override-input selfhostblocks ../selfhostblocks && nix run nixpkgs#colmena -- apply
```

## Diff changes {#contributing-diff}

First, you must know what to compare. You need to know the path to the nix store of what is already deployed and to what you will deploy.

### What is deployed {#contributing-diff-deployed}

To know what is deployed, either just stash the changes you made and run `build`:

```bash
$ nix run nixpkgs#colmena -- build
...
Built "/nix/store/yyw9rgn8v5jrn4657vwpg01ydq0hazgx-nixos-system-baryum-23.11pre-git"
```

Or ask the target machine:

```bash
$ nix run nixpkgs#colmena -- exec -v readlink -f /run/current-system
baryum | /nix/store/77n1hwhgmr9z0x3gs8z2g6cfx8gkr4nm-nixos-system-baryum-23.11pre-git
```

### What will get deployed {#contributing-diff-todeploy}

Assuming you made some changes, then instead of deploying with `apply`, just `build`:

```bash
$ nix run nixpkgs#colmena -- build
...
Built "/nix/store/16n1klx5cxkjpqhrdf0k12npx3vn5042-nixos-system-baryum-23.11pre-git"
```

### Get the full diff {#contributing-diff-full}

With `nix-diff`:

```
$ nix run nixpkgs#nix-diff -- \
  /nix/store/yyw9rgn8v5jrn4657vwpg01ydq0hazgx-nixos-system-baryum-23.11pre-git \
  /nix/store/16n1klx5cxkjpqhrdf0k12npx3vn5042-nixos-system-baryum-23.11pre-git \
  --color always | less
```

### Get version bumps {#contributing-diff-version}

A nice summary of version changes can be produced with:

```bash
$ nix run nixpkgs#nvd -- diff \
  /nix/store/yyw9rgn8v5jrn4657vwpg01ydq0hazgx-nixos-system-baryum-23.11pre-git \
  /nix/store/16n1klx5cxkjpqhrdf0k12npx3vn5042-nixos-system-baryum-23.11pre-git \
```

## Generate random secret {#contributing-gensecret}

```bash
$ nix run nixpkgs#openssl -- rand -hex 64
```

## Links that helped {#contributing-links}

While creating NixOS tests:

- https://www.haskellforall.com/2020/11/how-to-use-nixos-for-lightweight.html
- https://nixos.org/manual/nixos/stable/index.html#sec-nixos-tests

While creating an XML config generator for Radarr:

- https://stackoverflow.com/questions/4906977/how-can-i-access-environment-variables-in-python
- https://stackoverflow.com/questions/7771011/how-can-i-parse-read-and-use-json-in-python
- https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/writers/scripts.nix
- https://stackoverflow.com/questions/43837691/how-to-package-a-single-python-script-with-nix
- https://ryantm.github.io/nixpkgs/languages-frameworks/python/#python
- https://ryantm.github.io/nixpkgs/hooks/python/#setup-hook-python
- https://ryantm.github.io/nixpkgs/builders/trivial-builders/
- https://discourse.nixos.org/t/basic-flake-run-existing-python-bash-script/19886
- https://docs.python.org/3/tutorial/inputoutput.html
- https://pypi.org/project/json2xml/
- https://www.geeksforgeeks.org/serialize-python-dictionary-to-xml/
- https://nixos.org/manual/nix/stable/language/builtins.html#builtins-toXML
- https://github.com/NixOS/nixpkgs/blob/master/pkgs/pkgs-lib/formats.nix
