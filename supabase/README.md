# Supabase Setup

Run the complete contents of this file once from the Supabase SQL Editor:

`migrations/202606120000_fresh_no_rls.sql`

The script is destructive. It deletes and recreates all application tables,
but it does not delete users from Supabase Authentication.

RLS is intentionally disabled on the application tables for this academic
project. The `files` Storage bucket still uses one permissive authenticated
policy because Supabase Storage requires policies for client uploads.

After the script succeeds, public registration creates Mahasiswa accounts
only. Metadata that requests Admin, Dosen, or Ketua Kelas is ignored and stored
as Mahasiswa.

If the fresh schema was already installed, run these non-destructive patches
in order:

`migrations/202606120001_disable_admin_registration.sql`

`migrations/202606120002_student_only_registration.sql`

`migrations/202606120003_protect_role_changes.sql`

`migrations/202606120004_academic_role_workflow.sql`

`migrations/202606120005_reminders_for_all_class_members.sql`

`migrations/202606120006_prevent_duplicate_schedules.sql`

`migrations/202606120007_announcement_courses.sql`

`migrations/202606120008_class_leader_schedules.sql`

The last patch changes the academic workflow:

- Dosen create and edit the global course catalog.
- Mahasiswa and Ketua Kelas create classes, reminders, and schedules.
- Reminders always apply to every member of their class; they cannot target a
  selected account role.
- Schedules select courses from the global lecturer-owned catalog.
- Dosen create announcements; Ketua Kelas can create class announcements.
- Matching users can read announcements from the dashboard or class page.
- Admin can delete classes, courses, and non-Admin user accounts.

If an Authentication user already existed before running the script, its role
is reconstructed from user metadata and defaults to Mahasiswa when metadata is
missing. Create or promote an Admin only from the SQL Editor:

```sql
update public.profiles
set role = 'admin'
where email = 'admin@example.com';
```

After the first Admin can log in, use **Kelola User** to promote Mahasiswa
accounts to Dosen or other internal roles.

## Create Lecturer Function

The Admin dashboard creates lecturer Auth accounts through the server-side
Edge Function in `functions/create-lecturer`.

Deploy it with the Supabase CLI:

```bash
supabase functions deploy create-lecturer
```

The hosted function receives `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and
`SUPABASE_SERVICE_ROLE_KEY` from Supabase automatically. Never add the
service-role key to the Flutter `.env.json` file.

When the Edge Function has not been deployed, the Flutter application uses a
development fallback based on a separate anonymous Auth client. The active
Admin session then promotes the new profile to Dosen. With Supabase email
confirmation enabled, the lecturer must confirm the email before logging in.
