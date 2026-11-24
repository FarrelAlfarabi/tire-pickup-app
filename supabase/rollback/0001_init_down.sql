-- Rollback for 0001_init.sql. Deletes ALL app data. Run only on a throwaway or after backup.
drop function if exists public.delete_my_data();
drop function if exists public.set_partner_blocked(uuid, boolean, text);
drop function if exists public.mark_paid(uuid, text);
drop function if exists public.decide_report(uuid, text, text, int, numeric);
drop function if exists public.submit_report(jsonb);
drop policy if exists proofs_insert on storage.objects;
drop policy if exists proofs_read on storage.objects;
delete from storage.buckets where id = 'proofs';
drop table if exists public.audit_log, public.partners, public.bank_accounts, public.report_flags,
  public.report_files, public.reports, public.settings cascade;
drop trigger if exists on_auth_user_created on auth.users;
drop function if exists public.handle_new_user();
drop table if exists public.profiles cascade;
drop sequence if exists public.report_seq;
drop function if exists public.is_staff();
drop function if exists public.my_role();
