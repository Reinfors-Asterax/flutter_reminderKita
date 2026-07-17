# ReminderKita RBAC Implementation

Baseline: `Reinforss/flutter_reminderKita@c70ddb2`

## 1. Existing Architecture

- State management: local `StatefulWidget` and `setState`; no Provider, Bloc,
  Riverpod, or Redux.
- Routing: named routes on `MaterialApp`.
- Authentication: Supabase Auth with email/password. User name, NIM, and the
  previous role value were stored in auth metadata.
- Database: Supabase Postgres tables `kelas`, `anggota_kelas`, `matakuliah`,
  `jadwal_kelas`, and `tasks`.
- Storage: Supabase Storage bucket `files`.
- Notifications: `flutter_local_notifications` and `timezone`.
- Firebase: no Firebase dependency, config, or initialization exists.
- Models: data was passed as `Map<String, dynamic>` without domain models.
- Services: only `NotificationService` existed; pages queried Supabase
  directly.

The existing UI, `setState` state management, legacy tables, and primary pages
are retained.

## 2. Changed Files

### Configuration and documentation

- `.env.example`
- `.gitignore`
- `IMPLEMENTATION_REPORT.md`
- `RBAC_CHANGES.patch` (generated complete diff)
- `README.md`
- `pubspec.yaml`
- `pubspec.lock`

### Existing application files

- `lib/main.dart`
- `lib/login_page.dart`
- `lib/register_page.dart`
- `lib/home_page.dart`
- `lib/pages/class_board_page.dart`
- `lib/pages/create_class_page.dart`
- `lib/pages/profile_page.dart`
- `lib/pages/schedule_page.dart`
- `lib/pages/subject_management_page.dart`
- `lib/pages/task_form_page.dart`
- `lib/services/notification_service.dart`

### New RBAC and domain files

- `lib/models/user_role.dart`
- `lib/models/app_user.dart`
- `lib/models/class_model.dart`
- `lib/models/course.dart`
- `lib/models/class_schedule.dart`
- `lib/models/announcement.dart`
- `lib/models/reminder.dart`
- `lib/services/auth_service.dart`
- `lib/services/class_service.dart`
- `lib/services/course_service.dart`
- `lib/services/schedule_service.dart`
- `lib/services/announcement_service.dart`
- `lib/services/reminder_service.dart`
- `lib/routing/app_router.dart`
- `lib/routing/auth_guard.dart`
- `lib/routing/role_guard.dart`
- `lib/routing/navigation.dart`
- `lib/pages/auth_gate.dart`
- `lib/pages/access_denied_page.dart`
- `lib/pages/role_dashboard_page.dart`
- `lib/pages/user_management_page.dart`
- `lib/pages/announcement_page.dart`

### Database and tests

- `supabase/migrations/202606120001_rbac_modules.sql`
- `supabase/README.md`
- `test/rbac_models_test.dart`

## 3. Implementation Stages

1. Introduced canonical roles: `admin`, `lecturer`, `class_leader`, and
   `student`, including compatibility with legacy Indonesian role strings.
2. Added a centralized permission matrix, `AuthGuard`, and `RoleGuard`.
3. Added session loading from `profiles`, with auth metadata and class
   membership fallback for installations awaiting migration.
4. Added role-specific dashboards and automatic post-login redirect.
5. Added typed models and Supabase services for Class, Course, Schedule,
   Announcement, and Reminder.
6. Kept `tasks` as the physical reminder table and mapped its legacy Indonesian
   columns to the requested Reminder domain fields.
7. Added admin role management, announcement CRUD, course update support, and
   permission-aware actions in existing class/reminder/schedule pages.
8. Centralized local notification scheduling for H-7, H-3, H-1, and Hari H.
   Visible reminders are synchronized on every class refresh so target users
   schedule notifications on their own devices.
9. Added Supabase profiles, announcements, indexes, join-class RPC, migration
   backfills, and restrictive RLS policies.

## 4. Diff

The complete reviewable patch is generated in `RBAC_CHANGES.patch`. It is based
on the remote baseline commit because the provided workspace did not contain a
`.git` directory. On Windows clones using `core.autocrlf=true`, validate or
apply it with:

```bash
git apply --check --ignore-space-change RBAC_CHANGES.patch
git apply --ignore-space-change RBAC_CHANGES.patch
```

## 5. Migration Plan

1. Back up the Supabase database.
2. Apply the migration to a staging project.
3. Verify existing user, class membership, task, course, and schedule counts.
4. Bootstrap the first admin as documented in `supabase/README.md`.
5. Assign lecturer roles and link existing courses to lecturers. The migration
   automatically links exact lecturer-name matches.
6. Test every role against RLS before production rollout.
7. Deploy the Flutter build with `SUPABASE_URL` and `SUPABASE_ANON_KEY` supplied
   through `--dart-define`.
8. Roll out production migration during a maintenance window because existing
   policies on managed tables are replaced.

No destructive table rename is required. Existing `tasks` rows and legacy role
strings remain readable.

## 6. Testing Checklist

- [x] `flutter analyze` returns no issues.
- [x] Role parsing and permission matrix unit tests pass.
- [x] Reminder legacy mapping and effective expired status tests pass.
- [x] Windows debug build succeeds.
- [ ] Apply migration to staging Supabase and run SQL/RLS integration tests.
- [ ] Verify login redirect for all four roles.
- [ ] Verify students cannot mutate reminders, schedules, users, or courses.
- [ ] Verify lecturers only see taught/member classes.
- [ ] Verify class leaders can manage reminders and announcements for their
      classes.
- [ ] Verify admin role changes take effect after the next session refresh.
- [ ] Verify H-7, H-3, H-1, and Hari H notifications on Android and iOS.
- [ ] Verify notification rescheduling after reminder edit and cancellation
      after completion/deletion.

Firebase Cloud Messaging was not added because Firebase is not configured in
the repository. Local notifications are fully implemented; push notification
support requires Firebase project files, APNs/FCM credentials, token storage,
and a trusted server or Edge Function.

## 7. Pull Request Summary

### Summary

Add production RBAC and multi-role dashboards without replacing the existing
Flutter architecture or Supabase tables.

### Main changes

- Add Admin, Lecturer, Class Leader, and Student role handling.
- Add guarded routing and permission-aware UI actions.
- Add typed domain models/services for class, course, schedule, announcement,
  and reminder.
- Add announcement CRUD and admin user-role management.
- Extend reminders with target role, priority, status, creator, and centralized
  deadline notifications.
- Add Supabase migration with profiles, RLS, join RPC, and data backfills.

### Validation

- `flutter analyze`: passed with no issues.
- `flutter test`: 4 tests passed.
- `flutter build windows --debug`: passed.

Validation used a clean temporary Flutter 3.38.6 source/cache because the
machine's `D:\Flutter` installation contains corrupted framework source and Git
pack files.
