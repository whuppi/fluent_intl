# Vendored bundle corpus - provenance

`bundle/*.yaml` - bundle-format end-to-end fixtures from Mozilla's Project
Fluent reference impl. They exercise locale-aware NUMBER / DATETIME /
plural-rules behavior, so they need a real CLDR backend. The runner
(`bundle_corpus_test.dart`) wires `IntlBackend()` so the fixtures exercise
the intl backend's full surface.

The same pristine fixture set is vendored in `fluent_icu/test/_corpus/`
for the icu backend — each satellite carries its own copy so its test
suite stands alone. The two copies must stay byte-identical and re-sync
together (both PROVENANCE files pin the same upstream commit). The
parser-only `syntax/*` fixtures live with the core package instead —
see `fluent_bundle/test/_corpus/PROVENANCE.md`.

## Source

- **Upstream repo:** https://github.com/projectfluent/fluent-rs
- **Source commit:** `b822cfe0ac5f35099ee71d3cf6f43b7c01d5fc6d`
- **Source date:** 2026-03-27
- **Vendored on:** 2026-04-27
- **License:** Apache-2.0 (compatible with this package's Apache-2.0)

## Source paths

| Local path | Upstream path |
|---|---|
| `bundle/*.yaml` | `fluent-bundle/tests/fixtures/*.yaml` |

## Updating the corpus

```sh
# Pull the latest fluent-rs into a scratch checkout
git clone --depth 1 https://github.com/projectfluent/fluent-rs.git /tmp/fluent-rs

# Diff our copy against upstream
diff -r /tmp/fluent-rs/fluent-bundle/tests/fixtures \
        test/_corpus/bundle

# If diffs look intentional (upstream added/changed fixtures), copy the
# new files in, run the corpus suite, fix any newly-failing fixtures,
# then update this file's commit + date — AND do the same refresh in
# fluent_icu/test/_corpus/ in the same session (the copies must not
# drift apart).
```

## Why we vendor as plain copies (not a git submodule)

The corpus is read-only test data — never compiled or shipped to
consumers. A submodule would add a clone step that doesn't pay for itself
and hurts discoverability. This file is the manual ledger; bump it on
every refresh.
