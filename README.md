# Postgres Extension Security Methodology

A set of tools and a documented methodology for auditing curated,
allow-listed PostgreSQL extensions on managed cloud database platforms —
the model used by storage/compute-separated services, where an ordinary
role gets a curated extension list rather than raw superuser access.

This repository does **not** contain details of any specific
vulnerability, target, or program. It contains the reusable, generalized
tooling and process built while doing that kind of research, intended as
a reference workflow and a demonstration of the skills involved:
SQL-level reconnaissance, C/ABI-level verification, privilege-boundary
test design, and evidence-grade reproduction.

Portfolio: [oussamasaddati.vercel.app](https://oussamasaddati.vercel.app)

## Why this approach

On managed Postgres platforms, the interesting attack surface is rarely
"does the SQL parser have a bug" — it's whether the platform's privilege
model, the extension's own C code, and the boundary between
tenants/databases/roles actually line up the way the platform's
documentation claims. That means most of the real work is:

1. Enumerating exactly what a role can reach (not what the docs say it can reach).
2. Reading the extension's actual source where it's open, instead of
   guessing behavior from a black box.
3. Verifying any claim about an in-memory struct or wire format against
   the real compiled headers, not a hex dump someone eyeballed.
4. Building a privilege boundary that's provably zero before testing
   whether it holds.
5. Pairing every positive result with a negative control before trusting it.

## Repository layout

```
tools/
  extension-recon.sql        -- enumerate an extension's full function/type
                                 surface, ACLs, SECURITY DEFINER status,
                                 and owner, from catalog alone
  priv-boundary-harness.sql  -- build a provably zero-privilege test role
                                 and verify it with has_*_privilege() before
                                 using it for anything
  struct-offset-dumper.c     -- compile against real installed Postgres
                                 server headers to get exact offsetof()/
                                 sizeof() values for any C struct, instead
                                 of inferring layout from byte dumps

docs/
  methodology.md             -- the full workflow, step by step, with the
                                 reasoning for each stage
```

## Skills demonstrated

- PostgreSQL internals: catalog introspection, role/ACL model, extension
  mechanics, SECURITY DEFINER semantics, RLS enforcement paths
- C and the Postgres server API: compiling against
  `pg_config --includedir-server`, struct layout verification,
  varlena/bytea handling
- Source-assisted auditing of open-source extensions (reading upstream C
  before forming a hypothesis, not instead of testing one)
- Structured, controlled testing: positive/negative control pairs,
  independent secondary confirmation of any claimed result, provably
  zero-privilege test identities
- Clean evidence capture for formal reporting (reproducible transcripts,
  exact payload construction, no hand-waving)

## Scope note

This tooling was developed through authorized research under public bug
bounty programs, operating strictly within each program's published
scope and rules of engagement. No vulnerability details, payloads,
target names, or other program-identifying information are included
here; any finding from this work follows the responsible disclosure
timeline of the program it was reported to.

## License

MIT — see [LICENSE](./LICENSE). Provided for educational and authorized
security testing purposes only.
