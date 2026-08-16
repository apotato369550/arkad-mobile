# Supabase setup for cloud backup

Client-side scaffolding (Supabase client, onboarding toggle, Settings card) is
already wired up — see `lib/services/cloud_backup_service.dart`,
`lib/models/backup_settings.dart`, `lib/widgets/cloud_backup_card.dart`. This
is the dashboard-side setup needed to make it actually work.

**Design note:** enabling backup (onboarding or Settings) signs the device in
*anonymously* to Supabase and starts backing up immediately — zero friction,
but that identity is device-bound. To survive a lost/reset device, the user
links an email from the Settings card (6-digit code, no magic-link/deep-link
handling needed), which upgrades the same anonymous account to a permanent
one without losing the backup.

## Steps

1. **Create a project** at supabase.com (free tier is plenty).

2. **Fill in `.env`** (already scaffolded, both blank) from Project Settings → API:
   ```
   SUPABASE_URL=https://xxxxxxxx.supabase.co
   SUPABASE_ANON_KEY=<the "anon public" / "publishable" key — never the service_role key>
   ```

3. **Enable anonymous sign-ins** — off by default. Authentication → Sign In /
   Providers → toggle "Allow anonymous sign-ins".

4. **Create the table + RLS policy** — SQL Editor, run:
   ```sql
   create table public.backups (
     user_id uuid primary key references auth.users (id) on delete cascade,
     data jsonb not null,
     updated_at timestamptz not null default now()
   );

   alter table public.backups enable row level security;

   create policy "Users can manage their own backup"
     on public.backups
     for all
     using (auth.uid() = user_id)
     with check (auth.uid() = user_id);
   ```

5. **Switch the email confirmation template to OTP-code style** —
   Authentication → Email Templates → "Change Email Address" (this is the
   template GoTrue uses when an anonymous user links an email via
   `updateUser`). Edit it to expose the 6-digit code instead of only a magic
   link, e.g.:
   ```
   Your Arkad verification code is {{ .Token }}
   ```
   Without this, Supabase still sends the code in the token field
   (`verifyOTP` will work regardless), but the emailed message itself won't
   display it unless the template references `{{ .Token }}` — so check this
   even if you leave the default template's wording otherwise intact. Also
   check the "Magic Link" template the same way, since a non-anonymous
   first-time `signInWithOtp` (a rarer path here — only hit if a session
   somehow doesn't exist yet) uses that one instead.

6. **Verify**: `flutter run`, go through onboarding, flip cloud backup on →
   should create a row in `backups` with a random `user_id`. In Settings,
   "Back up now" should update `updated_at`; entering an email + code should
   flip `auth.users.is_anonymous` to false for that user while keeping the
   same `user_id`/row.

That's the whole loop — no EC2, no custom API, just the Supabase project.
