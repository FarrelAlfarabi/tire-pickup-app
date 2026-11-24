# Jemput Ban (used tire pickup app), v1

Flutter web app + Supabase (auth, database, private file storage) + Vercel.
Design B (green, step by step form, big touch targets).

## What it does
- Reporter (workshop or freelancer): 3 step report form with NIB, optional PO, 2 to 5 photos, bank account for transfer, UU PDP consent. Sees own report status.
- Admin: queue sorted by fraud risk, evidence with file hashes, survey numbers (counted tires, weight), approve / ask for fix / reject with reason.
- Finance: sees bank details (admins cannot), marks the manual transfer as paid with a reference.
- Directory: approved partners, search, block with reason, copy WhatsApp for repeat orders.

## Two modes
- **Demo mode** (no keys): everything lives in memory, resets on reload. Sample data only. Good for walking through the screens.
- **Supabase mode**: set `SUPABASE_URL` and `SUPABASE_ANON_KEY` (use the publishable/anon key, never the service key).

## Setup (Supabase mode)
1. Create a NEW Supabase project (keep client data apart from other apps).
2. Run `supabase/migrations/0001_init.sql` in the SQL editor.
3. Sign up in the app, then promote accounts by hand:
   `update public.profiles set role = 'admin' where id = '<user uuid>';` (use `'finance'` for the finance person).
4. In Vercel, add env vars `SUPABASE_URL` and `SUPABASE_ANON_KEY`, then redeploy.
5. Auth settings: turn on email confirmation, set the site URL to the Vercel URL.

Local run: `flutter run -d chrome --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`

## Fraud checks (all in `submit_report()` on the server)
| Check | How | Limit |
|---|---|---|
| Duplicate photo | SHA-256 of file bytes compared with every other report | Exact copies only. Re-saved, cropped, or screenshotted photos pass. Needs perceptual hashing later. |
| Duplicate report | Same NIB or same address (punctuation ignored) within 30 days | Typos in the address pass. |
| Weight sanity | Claimed kg vs min/max kg per tire type | Ranges are DRAFT guesses in the `settings` table. |
| Count cap | Over 500 tires per report | DRAFT cap. |
| NIB format | 13 digits | Does NOT check the NIB with OSS. Admin checks manually. |
| Survey mismatch | Admin's counted tires vs claim (over 10% warn, over 30% bad) | Depends on the admin entering numbers. |
| Blocked partner | NIB belongs to a blocked partner | |
| Rate limit | 5 reports per user per day | |

Reporters cannot see which check flagged them (so they cannot tune around the checks).

## UU PDP notes
- Row level security on every table. Bank details are in their own table: only the owner and finance can read them.
- Files are in a private bucket, per user folder, no overwrite or delete.
- Consent is stored with a timestamp. `delete_my_data()` anonymises reports and removes bank rows and file records.
- Still open: delete the storage objects (needs a service role job), a retention period, a privacy notice text from the client's lawyer, and who the data controller is.
- Account numbers are protected by RLS and Supabase disk encryption, not by column encryption. Add pgsodium or Vault if the client wants more.

## Not decided yet (placeholders in the UI)
- Waste class of used tires (B3 or non-B3) and the permits, transport rules, and records that follow. Needs written confirmation from the client.
- Prices: shown as `Rp [___] DRAF`. No price logic exists.
- Partner rating criteria.
- Whether freelancers buy tires from workshops or only introduce them.

## Tested
- SQL migration run on a local PostgreSQL 16 with stubs for the Supabase auth and storage schemas: duplicate photo, duplicate address, weight range, role escalation blocked, reporter cannot see flags or other people's bank rows, admin cannot read bank, finance can, double payment blocked, data deletion.
- NOT tested against a real Supabase project (no project exists yet). Auth emails, storage uploads, and the Dart Supabase calls are unverified.

## UI notes (Design B, phone first)
- Indonesian UI, big buttons, bottom tabs, sticky action bar, inline field errors, labeled steps.
- Photos are resized to 1600 px and saved as JPG before upload (3 to 8 MB phone photos become small). PDF max 5 MB.
- Lists load the latest 100 reports and 200 partners (no paging UI yet).
- Light theme only. Dark mode is not supported.
- Status is shown with an icon and a word, not color alone.

## Database safety
- `supabase/rollback/0001_init_down.sql` undoes the first migration (deletes all app data).
- `supabase/tests/0001_test.sql` is a local-only SQL test (run on a fresh throwaway Postgres with `stub_local_only.sql` first).
- Not yet done: automatic SQL tests in CI, a paged list screen, dark mode.
