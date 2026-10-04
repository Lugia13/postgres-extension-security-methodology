# Methodology: Auditing Curated Postgres Extensions on Managed Cloud Platforms

This describes the general workflow, independent of any specific target,
program, or finding.

## 1. Establish the actual scope

Managed Postgres platforms publish a curated, allow-listed set of
extensions. Before testing anything, confirm:

- Which extensions are *actually* installable by an ordinary role, versus
  which are present in the catalog but gated behind a superuser-only
  `CREATE EXTENSION` check. Don't assume from a docs page — query
  `pg_available_extensions` and try each one directly.
- Which extensions are documented as supported versus which are simply
  present in the compiled binary. A gap between the two is worth noting
  for scope purposes, but isn't itself a finding.
- What the platform's actual privilege model is. Most of these platforms
  replace the real Postgres superuser with a scoped "cloud admin" style
  role, and build their own authorization layer (often as a C extension)
  on top. That custom layer, not the underlying Postgres internals, is
  usually where logic bugs live.

## 2. Map every function's real reachability

For every extension in scope, pull the full function surface from
`pg_proc`/`pg_extension`/`pg_depend`: language, owner, ACL, and whether
it's `SECURITY DEFINER`. An empty `proacl` means the Postgres default
applies (PUBLIC EXECUTE for functions) — don't assume a function is
protected just because it looks internal or is prefixed with an
underscore.

Cross-reference against what the calling role can actually do:
`has_function_privilege()`, `has_database_privilege()`, `pg_has_role()`.
Never infer a privilege boundary from documentation or from a function's
apparent purpose — query it directly, every time, including for roles you
believe should obviously have no access.

## 3. Read the source before forming a hypothesis, where it's available

A large share of the realistic attack surface on these platforms is
open-source, upstream code (the extensions themselves), reachable but
*deployed* by the platform. Pull the actual source rather than guessing
behavior from a black box:

- Identify the extension's exact shipped version from `pg_extension`.
- Find the matching tag/commit in the upstream repository.
- Read the validation logic specifically, not just the feature code: what
  is checked, what order it's checked in, and — critically — what is
  *not* checked that a reasonable implementation would check (a caller-
  supplied identifier never cross-referenced against the caller's own
  context is a common shape worth looking for).

## 4. Get binary ground truth before crafting anything

If a hypothesis depends on an in-memory struct layout or a serialized
binary format, don't reconstruct it by eyeballing a hex dump. Compile a
small program against the real installed server headers
(`pg_config --includedir-server`) and use `offsetof()`/`sizeof()` to get
exact values. This takes minutes and removes an entire category of
self-inflicted error from payload construction.

Validate the computed offsets against a real, known-good sample captured
live from the target (e.g. the output of a legitimate call that produces
the format you're about to forge), not just against the struct
definition in isolation.

## 5. Build a provably zero-privilege test identity

Before testing any privilege-boundary claim, build the test role and
*verify its privilege level directly* — don't assume `REVOKE` worked, or
that a fresh role has no inherited grants. Check every relevant
predefined role membership (`pg_read_all_data`, `pg_write_all_data`,
etc.) and every relevant attribute (`rolsuper`, `rolbypassrls`,
`rolcreaterole`) explicitly, for the exact role you're about to test as,
not for your own session.

This step catches a specific, easy mistake: testing "as" a low-privilege
role via `SET ROLE` from an account that is itself the project/database
owner. `session_user` stays the owner throughout, and some authorization
checks key off `session_user` specifically rather than the effective
role — so a result obtained this way can look like a privilege bypass
when it's actually an artifact of the owner's own standing access. Always
confirm which identity a given check is actually keying off before
trusting the result.

## 6. Pair every positive result with a negative control

A single successful-looking result is not evidence. Repeat the identical
test with one identifying field deliberately corrupted (wrong id, wrong
key, wrong target). A genuine positive must produce an observably
different outcome from the corrupted-input run — a different return
value, a distinct error or warning, a different side effect visible
elsewhere in the system. If the two runs are indistinguishable, the
"positive" result isn't demonstrating what it appears to.

## 7. Confirm through a second, independent code path

Where the platform or extension offers more than one way to observe the
same underlying state, use a second one to confirm a result rather than
relying on a single function's output. Two independently implemented
views of the same state agreeing is substantially stronger evidence than
one result taken alone, and will surface disagreements (parsing
mistakes, stale state, caching artifacts) that a single check won't.

## 8. Know where the boundary actually is before claiming severity

Before writing anything up, work out — architecturally, not just
empirically — the maximum impact the underlying mechanism could ever
reach, and say so explicitly rather than letting severity assessment
default to the most dramatic plausible reading. If a shared resource's
scope is architecturally bounded (for example, per-instance rather than
per-tenant), no exploitation of it can exceed that boundary, regardless
of what privilege is obtained within it. Stating this ceiling plainly,
backed by the platform's own architecture, is part of the evidence — it
tells a reviewer you understand the system rather than just having found
something that looks interesting.

## 9. Capture clean, reproducible evidence

Favor plain, redirected output over terminal screen recordings — a
`script`-captured session carries raw ANSI/VTE escape sequences that
render as garbage outside a real terminal. Redirecting `psql` output
directly to a file (`psql -f input.sql -o output.txt`, or `\o` inside a
session) produces a clean transcript that's safe to attach to a report
and easy for anyone else to read or paste from.
