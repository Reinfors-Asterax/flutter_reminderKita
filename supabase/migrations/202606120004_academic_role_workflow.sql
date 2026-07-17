begin;

alter table public.matakuliah
  alter column kelas_id drop not null;

update public.tasks set target_role = null where target_role is not null;
alter table public.tasks
  drop constraint if exists tasks_target_role_must_be_null;
alter table public.tasks
  add constraint tasks_target_role_must_be_null check (target_role is null);

create or replace function public.delete_user_account(target_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  target_role text;
begin
  if public.current_user_role() <> 'admin' then
    raise exception 'Only an admin can delete user accounts';
  end if;
  if target_user_id = auth.uid() then
    raise exception 'Admin cannot delete the active account';
  end if;

  select role into target_role
  from public.profiles
  where id = target_user_id;

  if target_role is null then
    raise exception 'User account not found';
  end if;
  if target_role = 'admin' then
    raise exception 'Admin accounts cannot be deleted here';
  end if;

  delete from auth.users where id = target_user_id;
end;
$$;

create or replace function public.enforce_academic_role_rules()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  active_role text := public.current_user_role();
begin
  if tg_table_name = 'tasks' and tg_op in ('INSERT', 'UPDATE') then
    new.target_role := null;
  end if;

  if tg_table_name = 'kelas' then
    if tg_op = 'INSERT' and active_role not in ('student', 'class_leader') then
      raise exception 'Only students or class leaders can create classes';
    elsif tg_op = 'UPDATE' and not (
      active_role = 'admin'
      or old.created_by = auth.uid()
      or public.is_class_leader(old.id)
    ) then
      raise exception 'Only this class leader can update the class';
    elsif tg_op = 'DELETE' and active_role <> 'admin' then
      raise exception 'Only admins can delete classes';
    end if;
  elsif tg_table_name = 'matakuliah' then
    if tg_op = 'INSERT' and (
      active_role <> 'lecturer'
      or new.lecturer_id is distinct from auth.uid()
    ) then
      raise exception 'Only lecturers can create courses';
    elsif tg_op = 'UPDATE' and not (
      active_role = 'admin'
      or (
        active_role = 'lecturer'
        and old.lecturer_id is not distinct from auth.uid()
      )
    ) then
      raise exception 'Only the lecturer owner can update a course';
    elsif tg_op = 'DELETE' and active_role <> 'admin' then
      raise exception 'Only admins can delete courses';
    end if;
  elsif tg_table_name in ('tasks', 'jadwal_kelas') then
    if tg_op = 'INSERT' and not (
      active_role = 'admin'
      or (
        active_role in ('student', 'class_leader')
        and public.is_class_member(new.kelas_id)
      )
    ) then
      raise exception 'Only class members can create class data';
    elsif tg_op = 'UPDATE' and not (
      active_role = 'admin'
      or (
        active_role in ('student', 'class_leader')
        and public.is_class_member(old.kelas_id)
        and public.is_class_member(new.kelas_id)
      )
    ) then
      raise exception 'Only class members can update class data';
    elsif tg_op = 'DELETE' and not (
      active_role = 'admin'
      or (
        active_role in ('student', 'class_leader')
        and public.is_class_member(old.kelas_id)
      )
    ) then
      raise exception 'Only class members can delete class data';
    end if;
  elsif tg_table_name = 'announcements' then
    if tg_op = 'INSERT' and not (
      new.created_by = auth.uid()
      and (
        active_role = 'lecturer'
        or (
          active_role in ('student', 'class_leader')
          and new.target_class is not null
          and public.is_class_leader(new.target_class)
        )
      )
    ) then
      raise exception 'Role is not allowed to create this announcement';
    elsif tg_op = 'UPDATE' and not (
      old.created_by = auth.uid()
      and (
        active_role = 'lecturer'
        or (
          active_role in ('student', 'class_leader')
          and old.target_class is not null
          and new.target_class is not null
          and public.is_class_leader(old.target_class)
          and public.is_class_leader(new.target_class)
        )
      )
    ) then
      raise exception 'Only the author can update an announcement';
    elsif tg_op = 'DELETE' and not (
      active_role = 'admin'
      or (
        active_role in ('lecturer', 'student', 'class_leader')
        and old.created_by = auth.uid()
        and (
          active_role = 'lecturer'
          or (
            old.target_class is not null
            and public.is_class_leader(old.target_class)
          )
        )
      )
    ) then
      raise exception 'Role is not allowed to delete announcements';
    end if;
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists enforce_class_roles on public.kelas;
create trigger enforce_class_roles
  before insert or update or delete on public.kelas
  for each row execute function public.enforce_academic_role_rules();

drop trigger if exists enforce_course_roles on public.matakuliah;
create trigger enforce_course_roles
  before insert or update or delete on public.matakuliah
  for each row execute function public.enforce_academic_role_rules();

drop trigger if exists enforce_task_roles on public.tasks;
create trigger enforce_task_roles
  before insert or update or delete on public.tasks
  for each row execute function public.enforce_academic_role_rules();

drop trigger if exists enforce_schedule_roles on public.jadwal_kelas;
create trigger enforce_schedule_roles
  before insert or update or delete on public.jadwal_kelas
  for each row execute function public.enforce_academic_role_rules();

drop trigger if exists enforce_announcement_roles on public.announcements;
create trigger enforce_announcement_roles
  before insert or update or delete on public.announcements
  for each row execute function public.enforce_academic_role_rules();

grant execute on function public.delete_user_account(uuid) to authenticated;

commit;
