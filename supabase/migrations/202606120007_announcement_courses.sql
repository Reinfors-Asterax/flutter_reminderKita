begin;

alter table public.announcements
  add column if not exists course_id bigint;

alter table public.announcements
  drop constraint if exists announcements_course_id_fkey;

alter table public.announcements
  add constraint announcements_course_id_fkey
  foreign key (course_id)
  references public.matakuliah(id)
  on delete set null;

create index if not exists announcements_course_idx
  on public.announcements(course_id);

create or replace function public.validate_announcement_course()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  active_role text := public.current_user_role();
begin
  if active_role = 'lecturer' then
    if new.course_id is null or not exists (
      select 1
      from public.matakuliah course
      where course.id = new.course_id
        and course.lecturer_id = auth.uid()
    ) then
      raise exception 'Lecturers must select one of their own courses';
    end if;
  elsif new.course_id is not null then
    raise exception 'Only lecturers can attach courses to announcements';
  end if;

  return new;
end;
$$;

drop trigger if exists validate_announcement_course
  on public.announcements;
create trigger validate_announcement_course
  before insert or update on public.announcements
  for each row execute function public.validate_announcement_course();

commit;
