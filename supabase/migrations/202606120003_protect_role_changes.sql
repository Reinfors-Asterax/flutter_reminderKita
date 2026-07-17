begin;

create or replace function public.prevent_unauthorized_role_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (
    new.role is distinct from old.role
    or new.requested_role is distinct from old.requested_role
    or new.approval_status is distinct from old.approval_status
  )
  and coalesce(auth.role(), '') <> 'service_role'
  and session_user <> 'postgres'
  and public.current_user_role() <> 'admin'
  then
    raise exception 'Only an admin can change user roles';
  end if;

  return new;
end;
$$;

drop trigger if exists protect_profile_role on public.profiles;
create trigger protect_profile_role
  before update on public.profiles
  for each row execute function public.prevent_unauthorized_role_change();

commit;
