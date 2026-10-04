-- priv-boundary-harness.sql
--
-- Build a test role that is provably zero-privilege before using it for
-- anything, and a second-database target to test cross-database or
-- cross-object isolation against. The order here matters: verify the
-- boundary is actually zero *before* running the thing you're testing,
-- not after, or a positive result is ambiguous.
--
-- Replace :'target_db' with a second database on the same cluster/project
-- you control, and :'test_table' with an object inside it you also
-- control. Never point this at data or objects you don't own.


-- 1. Create a no-login test role and strip every privilege you can
-- think of, explicitly, rather than relying on defaults.
CREATE ROLE zz_zero_priv NOLOGIN
    NOCREATEROLE NOCREATEDB NOSUPERUSER NOBYPASSRLS NOREPLICATION;
GRANT zz_zero_priv TO CURRENT_USER;


-- 1b. *** SAFETY WARNING ***
-- The REVOKE below targets `zz_zero_priv, PUBLIC`. Revoking from PUBLIC
-- does not just lock down your throwaway role -- it strips the default
-- CONNECT privilege from EVERY role on :'target_db', including ones you
-- did not create. Only run this against a disposable sandbox database
-- you fully control and nobody else depends on. If you only want to
-- strip privileges from the test role itself, drop ", PUBLIC" from the
-- line below.
REVOKE ALL ON DATABASE :'target_db' FROM zz_zero_priv, PUBLIC;


-- 2. Verify the boundary is actually zero before trusting any test run
-- against it. Don't skip this -- a "successful" bypass test means
-- nothing if the role secretly had access the whole time.
SELECT has_database_privilege('zz_zero_priv', :'target_db', 'CONNECT');
-- expect: false

SELECT rolcreaterole, rolcreatedb, rolsuper, rolbypassrls, rolreplication
FROM pg_roles WHERE rolname = 'zz_zero_priv';
-- expect: all false

SELECT pg_has_role('zz_zero_priv', 'pg_read_all_data', 'MEMBER');
SELECT pg_has_role('zz_zero_priv', 'pg_write_all_data', 'MEMBER');
-- expect: both false


-- 3. Run the actual test as that role. Template: replace the SELECT with
-- whatever function or query you're testing.
SET ROLE zz_zero_priv;
SELECT current_user, session_user;
-- <<< run the thing under test here >>>
RESET ROLE;


-- 4. Negative control. Repeat the exact same test with one field
-- deliberately corrupted (wrong id, wrong oid, wrong key -- whatever the
-- test's identifying argument is). A genuine positive result must look
-- different from this control: a different return value, a distinct
-- error/warning, or a different observable side effect. If the positive
-- and the corrupted-input run look identical, the "positive" result is
-- not evidence of anything.


-- 5. Independent confirmation. Wherever possible, confirm a positive
-- result through a second, different function or view rather than
-- trusting a single code path. Two independently-implemented confirmations
-- agreeing is much stronger evidence than one result taken on faith.


-- 6. Cleanup.
RESET ROLE;
DROP ROLE IF EXISTS zz_zero_priv;
