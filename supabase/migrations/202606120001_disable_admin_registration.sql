begin;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_role text := lower(
    coalesce(
      new.raw_user_meta_data ->> 'requested_role',
      new.raw_user_meta_data ->> 'role',
      'student'
    )
  );
begin
  selected_role := case selected_role
    when 'lecturer' then 'lecturer'
    when 'dosen' then 'lecturer'
    else 'student'
  end;

  insert into public.profiles (
    id,
    email,
    display_name,
    student_number,
    role,
    requested_role,
    approval_status,
    avatar_url
  )
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data ->> 'name', 'Pengguna'),
    new.raw_user_meta_data ->> 'nim',
    selected_role,
    null,
    'active',
    new.raw_user_meta_data ->> 'avatar_url'
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

commit;
