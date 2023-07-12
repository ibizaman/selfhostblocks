# Unit Tests

Unit tests are used in Self Host Blocks to check that parsing
configurations produce the expected result.

You can find all unit tests under the [tests/unit](/tests/unit) directory.

To run the units test, do:

```bash
nix-instantiate --eval --strict . -A tests.unit
```

If all tests pass, you'll see the following output:

```
{ }
```

Otherwise, you'll see one attribute for each failing test. For example, you can dig into the first failing haproxy test with:

```
nix-instantiate --eval --strict . -A tests.unit.haproxy.0
```
