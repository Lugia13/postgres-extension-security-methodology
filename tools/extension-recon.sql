-- extension-recon.sql
--
-- Catalog-only reconnaissance for a Postgres extension's SQL-visible
-- surface. Run each section separately; mixing a backslash meta-command
-- with a multi-line block in the same psql submission will swallow the
-- rest of the input, so keep \-commands on their own line.
--
-- Usage: replace :'ext_name' with the extension you're auditing, e.g.
--   psql -v ext_name=some_extension -f extension-recon.sql


-- 1. Does the extension exist, and where is it installed?
SELECT e.extname, n.nspname AS schema, e.extversion
FROM pg_extension e
JOIN pg_namespace n ON n.oid = e.extnamespace
WHERE e.extname = :'ext_name';


-- 2. Full function surface: language, owner, ACL, SECURITY DEFINER status.
-- An empty proacl means the default applies -- PUBLIC EXECUTE for
-- functions. prosecdef = t is the first thing to check for a
-- privilege-escalation candidate.
SELECT
    p.proname,
    p.prosecdef           AS security_definer,
    p.proacl,
    l.lanname              AS language,
    pg_get_userbyid(p.proowner) AS owner,
    p.proargtypes::regtype[]    AS arg_types,
    p.prorettype::regtype       AS ret_type
FROM pg_proc p
JOIN pg_language l ON l.oid = p.prolang
JOIN pg_depend d ON d.objid = p.oid AND d.classid = 'pg_proc'::regclass
JOIN pg_extension e ON e.oid = d.refobjid
WHERE e.extname = :'ext_name'
ORDER BY p.proname;


-- 3. Any views, tables, or other relations the extension installs.
SELECT d.deptype, c.relkind, c.relname AS object_name
FROM pg_depend d
JOIN pg_extension e ON e.oid = d.refobjid
LEFT JOIN pg_class c ON c.oid = d.objid AND d.classid = 'pg_class'::regclass
WHERE e.extname = :'ext_name'
  AND c.relname IS NOT NULL
ORDER BY 1, 2, 3;


-- 4. Cluster-wide inventory of every SECURITY DEFINER function currently
-- loaded, regardless of extension. Useful as a first pass across an
-- entire platform's installed extension set.
SELECT n.nspname, p.proname, pg_get_userbyid(p.proowner) AS owner
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.prosecdef = true
ORDER BY 1, 2;


-- 5. Does the current role actually hold the server-side capabilities
-- that matter most (file access, program execution)? Don't assume from
-- documentation -- check directly.
SELECT rolname FROM pg_roles
WHERE rolname IN ('pg_read_server_files', 'pg_write_server_files',
                   'pg_execute_server_program', 'pg_read_all_data',
                   'pg_write_all_data');

SELECT pg_has_role(current_user, 'pg_read_server_files', 'MEMBER');
SELECT pg_has_role(current_user, 'pg_write_server_files', 'MEMBER');
SELECT pg_has_role(current_user, 'pg_execute_server_program', 'MEMBER');

SELECT has_function_privilege(current_user, 'pg_read_file(text)', 'EXECUTE');
SELECT has_function_privilege(current_user, 'pg_read_binary_file(text)', 'EXECUTE');
SELECT has_function_privilege(current_user, 'lo_import(text)', 'EXECUTE');
