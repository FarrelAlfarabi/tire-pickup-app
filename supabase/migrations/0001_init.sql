-- Jemput Ban: v1 schema, row level security and fraud checks.
-- Not applied to any database yet. Review, then run in a NEW Supabase project.
--
-- Roles (profiles.role): reporter (default), admin, finance.
-- Set admin/finance by hand in the SQL editor:
--   update public.profiles set role = 'admin' where id = '<user uuid>';
--
-- Draft values the client must confirm are marked [DRAFT].

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------- profiles
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null default '',
  role text not null default 'reporter' check (role in ('reporter', 'admin', 'finance')),
  created_at timestamptz not null default now()
);

create function public.my_role() returns text
language sql stable security definer set search_path = public as $$
  select role from public.profiles where id = auth.uid()
$$;

create function public.is_staff() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(public.my_role() in ('admin', 'finance'), false)
$$;

create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', ''));
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------- settings
-- [DRAFT] Fraud rules and price. Admin edits these; nothing is hard coded in the app.
create table public.settings (
  key text primary key,
  value numeric,
  note text
);
insert into public.settings (key, value, note) values
  ('kg_min_motor', 1.5, '[DRAFT] min kg per motorcycle tire'),
  ('kg_max_motor', 5, '[DRAFT] max kg per motorcycle tire'),
  ('kg_min_car', 5, '[DRAFT] min kg per car tire'),
  ('kg_max_car', 14, '[DRAFT] max kg per car tire'),
  ('kg_min_truck', 30, '[DRAFT] min kg per truck tire'),
  ('kg_max_truck', 70, '[DRAFT] max kg per truck tire'),
  ('max_tires_per_report', 500, '[DRAFT] cap per report'),
  ('duplicate_window_days', 30, '[DRAFT] days to look back for duplicate reports'),
  ('price_per_kg', null, '[DRAFT] not approved yet, keep null');

-- ----------------------------------------------------------------- reports
create sequence public.report_seq start 418;

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  reporter_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  whatsapp text not null,
  nib text not null,
  reporter_type text not null check (reporter_type in ('workshop', 'freelancer')),
  address text not null,
  motor int not null check (motor >= 0),
  car int not null check (car >= 0),
  truck int not null check (truck >= 0),
  weight_kg numeric not null check (weight_kg > 0),
  pickup_date date not null,
  status text not null default 'submitted'
    check (status in ('submitted', 'needs_fix', 'approved', 'rejected')),
  decision_note text,
  decided_by uuid references auth.users (id),
  decided_at timestamptz,
  counted_total int,
  counted_kg numeric,
  payment_status text not null default 'unpaid' check (payment_status in ('unpaid', 'paid')),
  transfer_ref text,
  paid_by uuid references auth.users (id),
  paid_at timestamptz,
  consent_at timestamptz not null,
  created_at timestamptz not null default now()
);
create index on public.reports (reporter_id);
create index on public.reports (nib);
create index on public.reports (created_at desc);

create table public.report_files (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.reports (id) on delete cascade,
  kind text not null check (kind in ('nib', 'po', 'photo')),
  name text not null,
  path text not null,
  hash text not null, -- sha256 of the file bytes, computed in the app
  created_at timestamptz not null default now()
);
create index on public.report_files (hash);
create index on public.report_files (report_id);

create table public.report_flags (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.reports (id) on delete cascade,
  kind text not null,
  level text not null check (level in ('bad', 'warn', 'ok')),
  text text not null,
  created_at timestamptz not null default now()
);
create index on public.report_flags (report_id);

-- Bank details live in their own table so RLS can hide them from plain admins.
create table public.bank_accounts (
  report_id uuid primary key references public.reports (id) on delete cascade,
  owner_id uuid not null references auth.users (id) on delete cascade,
  bank text not null,
  account_no text not null,
  holder text not null
);

create table public.partners (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  type text not null,
  address text not null,
  whatsapp text not null,
  nib text not null unique,
  blocked boolean not null default false,
  block_reason text,
  last_pickup date,
  pickups int not null default 0,
  created_at timestamptz not null default now()
);

create table public.audit_log (
  id bigserial primary key,
  actor uuid references auth.users (id),
  action text not null,
  target text not null,
  detail jsonb,
  at timestamptz not null default now()
);

-- -------------------------------------------------------------------- RLS
alter table public.profiles enable row level security;
alter table public.settings enable row level security;
alter table public.reports enable row level security;
alter table public.report_files enable row level security;
alter table public.report_flags enable row level security;
alter table public.bank_accounts enable row level security;
alter table public.partners enable row level security;
alter table public.audit_log enable row level security;

-- profiles: read your own, staff read all. Nobody can change role from the client.
create policy profiles_read on public.profiles for select
  using (id = auth.uid() or public.is_staff());
create policy profiles_update_name on public.profiles for update
  using (id = auth.uid()) with check (id = auth.uid() and role = public.my_role());

-- settings: staff read, admin write.
create policy settings_read on public.settings for select using (public.is_staff());
create policy settings_write on public.settings for all
  using (public.my_role() = 'admin') with check (public.my_role() = 'admin');

-- reports and children: reporter sees own, staff see all. No direct inserts or
-- updates. Writes go through the security definer functions below.
create policy reports_read on public.reports for select
  using (reporter_id = auth.uid() or public.is_staff());
create policy files_read on public.report_files for select using (
  public.is_staff() or exists (
    select 1 from public.reports r where r.id = report_id and r.reporter_id = auth.uid()));
-- Reporters do not see flags: it would teach them what trips the checks.
create policy flags_read on public.report_flags for select using (public.is_staff());

-- bank: finance reads all; the owner reads their own. Plain admins cannot.
create policy bank_read on public.bank_accounts for select
  using (owner_id = auth.uid() or public.my_role() = 'finance');

create policy partners_read on public.partners for select using (public.is_staff());
create policy audit_read on public.audit_log for select using (public.my_role() = 'admin');

-- Reporters should not see staff only columns on their own report. Hide the
-- survey and payment internals behind a view if the client wants stricter
-- separation. v1 keeps them readable because they are the reporter's own data.

-- ---------------------------------------------------------------- storage
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('proofs', 'proofs', false, 5242880,
        array['image/jpeg', 'image/png', 'application/pdf'])
on conflict (id) do nothing;

-- Files are stored under <user id>/<file>. Owner uploads and reads their own.
-- Staff read everything. Nobody can overwrite or delete (keeps evidence intact).
create policy proofs_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'proofs' and (storage.foldername(name))[1] = auth.uid()::text);
create policy proofs_read on storage.objects for select to authenticated
  using (bucket_id = 'proofs' and
         ((storage.foldername(name))[1] = auth.uid()::text or public.is_staff()));

-- -------------------------------------------------------- submit_report()
-- One transaction: validate, insert report, files, bank, run fraud checks.
create function public.submit_report(p jsonb) returns text
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  rid uuid := gen_random_uuid();
  rcode text;
  f jsonb;
  v_motor int := (p ->> 'motor')::int;
  v_car int := (p ->> 'car')::int;
  v_truck int := (p ->> 'truck')::int;
  v_kg numeric := (p ->> 'weight_kg')::numeric;
  v_nib text := trim(p ->> 'nib');
  v_addr text := trim(p ->> 'address');
  v_total int;
  v_lo numeric;
  v_hi numeric;
  v_cap numeric;
  v_days numeric;
  n_photo int := 0;
  has_nib boolean := false;
  has_po boolean := false;
  hit text;
  dup record;
  s record;
begin
  if uid is null then raise exception 'Harus masuk dulu.'; end if;
  if (p ->> 'consent')::boolean is not true then
    raise exception 'Persetujuan data pribadi wajib.';
  end if;
  if v_motor < 0 or v_car < 0 or v_truck < 0 then raise exception 'Jumlah ban tidak valid.'; end if;
  v_total := v_motor + v_car + v_truck;
  if v_total = 0 then raise exception 'Isi minimal satu ban.'; end if;
  if v_kg <= 0 then raise exception 'Berat tidak valid.'; end if;
  if length(trim(p ->> 'name')) < 3 then raise exception 'Nama terlalu pendek.'; end if;

  -- Light rate limit: at most 5 reports per user per day.
  if (select count(*) from reports where reporter_id = uid and created_at > now() - interval '1 day') >= 5 then
    raise exception 'Batas 5 laporan per hari tercapai.';
  end if;

  for f in select * from jsonb_array_elements(p -> 'files') loop
    if (f ->> 'path') not like uid::text || '/%' then
      raise exception 'Path berkas tidak valid.';
    end if;
    if f ->> 'kind' = 'photo' then n_photo := n_photo + 1; end if;
    if f ->> 'kind' = 'nib' then has_nib := true; end if;
    if f ->> 'kind' = 'po' then has_po := true; end if;
  end loop;
  if not has_nib then raise exception 'Berkas NIB wajib.'; end if;
  if n_photo < 2 then raise exception 'Minimal 2 foto.'; end if;
  if p ->> 'reporter_type' = 'freelancer' and not has_po then
    raise exception 'Freelancer wajib melampirkan purchase order.';
  end if;

  rcode := 'R-' || lpad(nextval('report_seq')::text, 4, '0');
  insert into reports (id, code, reporter_id, name, whatsapp, nib, reporter_type, address,
                       motor, car, truck, weight_kg, pickup_date, consent_at)
  values (rid, rcode, uid, trim(p ->> 'name'), trim(p ->> 'whatsapp'), v_nib,
          p ->> 'reporter_type', v_addr, v_motor, v_car, v_truck, v_kg,
          (p ->> 'pickup_date')::date, now());

  for f in select * from jsonb_array_elements(p -> 'files') loop
    insert into report_files (report_id, kind, name, path, hash)
    values (rid, f ->> 'kind', f ->> 'name', f ->> 'path', f ->> 'hash');
  end loop;

  insert into bank_accounts (report_id, owner_id, bank, account_no, holder)
  values (rid, uid, p -> 'bank' ->> 'bank', p -> 'bank' ->> 'account_no', p -> 'bank' ->> 'holder');

  -- ---- fraud checks ----
  select value into v_cap from settings where key = 'max_tires_per_report';
  select value into v_days from settings where key = 'duplicate_window_days';

  if v_nib !~ '^\d{13}$' then
    insert into report_flags (report_id, kind, level, text)
    values (rid, 'nib_format', 'warn', 'NIB bukan 13 digit. Cek manual ke OSS.');
  end if;

  if v_total > coalesce(v_cap, 500) then
    insert into report_flags (report_id, kind, level, text)
    values (rid, 'count_cap', 'warn',
      format('Klaim %s ban, di atas batas %s per laporan [batas draf].', v_total, v_cap));
  end if;

  select v_motor * (select value from settings where key = 'kg_min_motor')
       + v_car   * (select value from settings where key = 'kg_min_car')
       + v_truck * (select value from settings where key = 'kg_min_truck'),
         v_motor * (select value from settings where key = 'kg_max_motor')
       + v_car   * (select value from settings where key = 'kg_max_car')
       + v_truck * (select value from settings where key = 'kg_max_truck')
    into v_lo, v_hi;
  if v_kg < v_lo or v_kg > v_hi then
    insert into report_flags (report_id, kind, level, text)
    values (rid, 'weight_range', 'warn',
      format('Berat %s kg di luar kisaran %s sampai %s kg untuk jumlah ini [kisaran draf].',
             round(v_kg), round(v_lo), round(v_hi)));
  end if;

  -- Duplicate photo: same SHA-256 as a photo in any other report. Exact copies
  -- only. Re-saved, cropped or screenshotted photos are NOT caught (v1 limit).
  for dup in
    select distinct f2.name as fname, r.code as other_code
    from report_files f2
    join report_files o on o.hash = f2.hash and o.report_id <> rid and o.kind = 'photo'
    join reports r on r.id = o.report_id
    where f2.report_id = rid and f2.kind = 'photo'
  loop
    insert into report_flags (report_id, kind, level, text)
    values (rid, 'duplicate_photo', 'bad',
      format('Foto "%s" sama persis dengan foto di laporan %s.', dup.fname, dup.other_code));
  end loop;

  -- Duplicate report: same NIB, or same address once punctuation is removed.
  select r.code into hit
  from reports r
  where r.id <> rid
    and r.status <> 'rejected'
    and r.created_at > now() - make_interval(days => coalesce(v_days, 30)::int)
    and (r.nib = v_nib
         or regexp_replace(lower(r.address), '[^a-z0-9]', '', 'g')
          = regexp_replace(lower(v_addr), '[^a-z0-9]', '', 'g'))
  order by r.created_at desc limit 1;
  if hit is not null then
    insert into report_flags (report_id, kind, level, text)
    values (rid, 'duplicate_report', 'warn',
      format('NIB atau alamat sama dengan laporan %s dalam %s hari terakhir.', hit, coalesce(v_days, 30)));
  end if;

  -- Blocked partner with the same NIB.
  if exists (select 1 from partners where nib = v_nib and blocked) then
    insert into report_flags (report_id, kind, level, text)
    values (rid, 'blocked_partner', 'bad', 'NIB ini milik mitra yang sedang diblokir.');
  end if;

  insert into audit_log (actor, action, target) values (uid, 'submit_report', rcode);
  return rcode;
end $$;

-- ---------------------------------------------------------- decide_report()
create function public.decide_report(
  p_id uuid, p_status text, p_note text, p_counted_total int, p_counted_kg numeric
) returns void
language plpgsql security definer set search_path = public as $$
declare
  r reports%rowtype;
  diff numeric;
begin
  if not public.is_staff() then raise exception 'Hanya admin.'; end if;
  if p_status not in ('approved', 'needs_fix', 'rejected') then raise exception 'Status tidak valid.'; end if;
  if p_status <> 'approved' and coalesce(trim(p_note), '') = '' then
    raise exception 'Alasan wajib untuk keputusan ini.';
  end if;
  select * into r from reports where id = p_id for update;
  if not found then raise exception 'Laporan tidak ditemukan.'; end if;

  update reports set status = p_status, decision_note = nullif(trim(p_note), ''),
    decided_by = auth.uid(), decided_at = now(),
    counted_total = p_counted_total, counted_kg = p_counted_kg
  where id = p_id;

  delete from report_flags where report_id = p_id and kind = 'count_mismatch';
  if p_counted_total is not null and (r.motor + r.car + r.truck) > 0 then
    diff := abs(p_counted_total - (r.motor + r.car + r.truck))::numeric / (r.motor + r.car + r.truck);
    insert into report_flags (report_id, kind, level, text) values (p_id, 'count_mismatch',
      case when diff > 0.3 then 'bad' when diff > 0.1 then 'warn' else 'ok' end,
      format('Hitung di lokasi %s ban, klaim %s ban.', p_counted_total, r.motor + r.car + r.truck));
  end if;

  if p_status = 'approved' then
    insert into partners (name, type, address, whatsapp, nib)
    values (r.name, r.reporter_type, r.address, r.whatsapp, r.nib)
    on conflict (nib) do nothing;
  end if;

  insert into audit_log (actor, action, target, detail)
  values (auth.uid(), 'decide_report', r.code, jsonb_build_object('status', p_status, 'note', p_note));
end $$;

-- ------------------------------------------------------------- mark_paid()
-- Payment stays manual: finance transfers by bank, then records the reference.
create function public.mark_paid(p_id uuid, p_ref text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if public.my_role() <> 'finance' then raise exception 'Hanya admin keuangan.'; end if;
  if coalesce(trim(p_ref), '') = '' then raise exception 'Referensi transfer wajib.'; end if;
  update reports set payment_status = 'paid', transfer_ref = trim(p_ref),
    paid_by = auth.uid(), paid_at = now()
  where id = p_id and status = 'approved' and payment_status = 'unpaid';
  if not found then raise exception 'Laporan belum disetujui atau sudah dibayar.'; end if;
  insert into audit_log (actor, action, target, detail)
  values (auth.uid(), 'mark_paid', p_id::text, jsonb_build_object('ref', p_ref));
end $$;

-- ------------------------------------------------- set_partner_blocked()
create function public.set_partner_blocked(p_id uuid, p_blocked boolean, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_staff() then raise exception 'Hanya admin.'; end if;
  if p_blocked and coalesce(trim(p_reason), '') = '' then raise exception 'Alasan blokir wajib.'; end if;
  update partners set blocked = p_blocked,
    block_reason = case when p_blocked then trim(p_reason) else null end
  where id = p_id;
  insert into audit_log (actor, action, target, detail)
  values (auth.uid(), 'set_partner_blocked', p_id::text,
          jsonb_build_object('blocked', p_blocked, 'reason', p_reason));
end $$;

-- --------------------------------------------------------- delete_my_data()
-- UU PDP: erase personal data on request. Reports are kept for the client's
-- records but anonymised; bank details and uploaded files' links are removed.
-- Storage objects must also be deleted (run from a service role job, see README).
create function public.delete_my_data() returns void
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'Harus masuk dulu.'; end if;
  delete from bank_accounts where owner_id = uid;
  update reports set name = '[dihapus]', whatsapp = '[dihapus]', address = '[dihapus]'
  where reporter_id = uid;
  delete from report_files where report_id in (select id from reports where reporter_id = uid);
  update profiles set full_name = '[dihapus]' where id = uid;
  insert into audit_log (actor, action, target) values (uid, 'delete_my_data', uid::text);
end $$;

-- ------------------------------------------------------------- grants
-- Only logged in users call the functions. Revoke the default public execute.
revoke all on function public.submit_report(jsonb) from public;
revoke all on function public.decide_report(uuid, text, text, int, numeric) from public;
revoke all on function public.mark_paid(uuid, text) from public;
revoke all on function public.set_partner_blocked(uuid, boolean, text) from public;
revoke all on function public.delete_my_data() from public;
grant execute on function public.submit_report(jsonb) to authenticated;
grant execute on function public.decide_report(uuid, text, text, int, numeric) to authenticated;
grant execute on function public.mark_paid(uuid, text) to authenticated;
grant execute on function public.set_partner_blocked(uuid, boolean, text) to authenticated;
grant execute on function public.delete_my_data() to authenticated;
