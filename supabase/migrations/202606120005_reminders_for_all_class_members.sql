begin;

update public.tasks
set target_role = null
where target_role is not null;

alter table public.tasks
  drop constraint if exists tasks_target_role_must_be_null;

alter table public.tasks
  add constraint tasks_target_role_must_be_null
  check (target_role is null);

create or replace function public.clear_task_target_role()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.target_role := null;
  return new;
end;
$$;

drop trigger if exists clear_task_target_role on public.tasks;
create trigger clear_task_target_role
  before insert or update on public.tasks
  for each row execute function public.clear_task_target_role();

commit;
