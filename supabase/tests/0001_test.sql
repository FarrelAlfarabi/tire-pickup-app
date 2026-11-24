-- Local-only SQL test. Run on a FRESH throwaway Postgres after stub_local_only.sql + migrations/0001_init.sql.
-- Not for the real Supabase project (it inserts fake auth users).
\set ON_ERROR_STOP off
insert into auth.users(id,raw_user_meta_data) values
 ('11111111-1111-1111-1111-111111111111','{"full_name":"Rina"}'),
 ('22222222-2222-2222-2222-222222222222','{"full_name":"Budi"}'),
 ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','{"full_name":"Admin"}'),
 ('ffffffff-ffff-ffff-ffff-ffffffffffff','{"full_name":"Fin"}');
update profiles set role='admin' where id='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
update profiles set role='finance' where id='ffffffff-ffff-ffff-ffff-ffffffffffff';
grant select,insert,update,delete on all tables in schema public to authenticated;
grant usage on all sequences in schema public to authenticated;

set role authenticated;
set request.jwt.sub='11111111-1111-1111-1111-111111111111';
\echo == T1 submit ok (Rina)
select submit_report('{"name":"Bengkel Rina","whatsapp":"0811","nib":"1234567890123","reporter_type":"workshop","address":"Jl. Contoh 1","motor":40,"car":80,"truck":0,"weight_kg":1050,"pickup_date":"2026-12-02","consent":true,"bank":{"bank":"BCA","account_no":"1234564821","holder":"Rina"},"files":[{"kind":"nib","name":"nib.jpg","path":"11111111-1111-1111-1111-111111111111/a","hash":"h-nib"},{"kind":"photo","name":"p1.jpg","path":"11111111-1111-1111-1111-111111111111/b","hash":"H1"},{"kind":"photo","name":"p2.jpg","path":"11111111-1111-1111-1111-111111111111/c","hash":"H2"}]}'::jsonb);
\echo == T2 no consent
select submit_report('{"name":"X Y Z","whatsapp":"0811","nib":"1","reporter_type":"workshop","address":"a","motor":1,"car":0,"truck":0,"weight_kg":3,"pickup_date":"2026-12-02","consent":false,"files":[]}'::jsonb);
\echo == T3 path of another user rejected
select submit_report('{"name":"Bengkel Budi","whatsapp":"0811","nib":"9999999999999","reporter_type":"workshop","address":"Jl. Lain 2","motor":10,"car":0,"truck":0,"weight_kg":30,"pickup_date":"2026-12-02","consent":true,"bank":{"bank":"BNI","account_no":"1","holder":"B"},"files":[{"kind":"nib","name":"n","path":"11111111-1111-1111-1111-111111111111/zz","hash":"x"}]}'::jsonb);

set request.jwt.sub='22222222-2222-2222-2222-222222222222';
\echo == T4 Budi reuses Rina photo H1 and same address -> flags
select submit_report('{"name":"Bengkel Budi","whatsapp":"0822","nib":"9999999999999","reporter_type":"workshop","address":"jl. contoh 1!","motor":10,"car":0,"truck":0,"weight_kg":300,"pickup_date":"2026-12-02","consent":true,"bank":{"bank":"BNI","account_no":"5550001111","holder":"Budi"},"files":[{"kind":"nib","name":"n.jpg","path":"22222222-2222-2222-2222-222222222222/a","hash":"h-nib2"},{"kind":"photo","name":"copy.jpg","path":"22222222-2222-2222-2222-222222222222/b","hash":"H1"},{"kind":"photo","name":"new.jpg","path":"22222222-2222-2222-2222-222222222222/c","hash":"H9"}]}'::jsonb);
\echo == T5 Budi sees only own reports, no flags, no others bank
select code from reports;
select count(*) as flags_visible from report_flags;
select count(*) as bank_rows_visible from bank_accounts;
\echo == T6 Budi cannot make himself admin / direct insert / call decide
update profiles set role='admin' where id='22222222-2222-2222-2222-222222222222';
select role from profiles;
insert into reports(code,reporter_id,name,whatsapp,nib,reporter_type,address,motor,car,truck,weight_kg,pickup_date,consent_at) values('R-HACK','22222222-2222-2222-2222-222222222222','a','b','c','workshop','d',1,0,0,1,now(),now());
select decide_report((select id from reports limit 1),'approved','',null,null);

reset role; set role authenticated;
set request.jwt.sub='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
\echo == T7 admin sees all reports + flags, not bank
select code, status from reports order by code;
select r.code, f.kind, f.level from report_flags f join reports r on r.id=f.report_id order by r.code, f.kind;
select count(*) as admin_bank_rows from bank_accounts;
\echo == T8 admin rejects without note fails; approve works; partner created
select decide_report((select id from reports where code='R-0418'),'rejected','',null,null);
select decide_report((select id from reports where code='R-0418'),'approved','ok',60,null);
select name, nib from partners;
select kind, level, text from report_flags where report_id=(select id from reports where code='R-0418') and kind='count_mismatch';
\echo == T9 admin cannot mark paid
select mark_paid((select id from reports where code='R-0418'),'TRF1');

set request.jwt.sub='ffffffff-ffff-ffff-ffff-ffffffffffff';
\echo == T10 finance sees bank, marks paid, second pay fails
select count(*) as finance_bank_rows from bank_accounts;
select mark_paid((select id from reports where code='R-0418'),'TRF1');
select mark_paid((select id from reports where code='R-0418'),'TRF2');
select code, payment_status, transfer_ref from reports where code='R-0418';

set request.jwt.sub='11111111-1111-1111-1111-111111111111';
\echo == T11 delete my data
select delete_my_data();
select name, whatsapp from reports where reporter_id='11111111-1111-1111-1111-111111111111';
select count(*) as bank_left from bank_accounts;
