-- Forward-only correction for the locally applied 0002 migration.
-- New tables have no implicit service_role privilege in the local stack.
-- The future trusted sync writer needs projection and immutable-event inserts;
-- a trigger still rejects log UPDATE/DELETE even for this role.
grant select, insert, update, delete on public.ledger_entries to service_role;
grant select, insert, update, delete on public.change_log to service_role;
