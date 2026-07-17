begin;

create or replace function public.enforce_schedule_leader_only()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' and not public.is_class_leader(new.kelas_id) then
    raise exception 'Only the class leader can create schedules';
  elsif tg_op = 'UPDATE' and not (
    public.is_admin()
    or (
      public.is_class_leader(old.kelas_id)
      and public.is_class_leader(new.kelas_id)
    )
  ) then
    raise exception 'Only the class leader can update schedules';
  elsif tg_op = 'DELETE' and not (
    public.is_admin()
    or public.is_class_leader(old.kelas_id)
  ) then
    raise exception 'Only the class leader can delete schedules';
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists enforce_schedule_leader_only
  on public.jadwal_kelas;
create trigger enforce_schedule_leader_only
  before insert or update or delete on public.jadwal_kelas
  for each row execute function public.enforce_schedule_leader_only();

commit;
