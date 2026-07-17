begin;

delete from public.jadwal_kelas duplicate
using public.jadwal_kelas original
where duplicate.id > original.id
  and duplicate.kelas_id = original.kelas_id
  and duplicate.matakuliah_id = original.matakuliah_id
  and duplicate.hari = original.hari
  and duplicate.jam_mulai = original.jam_mulai
  and duplicate.jam_selesai = original.jam_selesai
  and lower(trim(duplicate.ruangan)) = lower(trim(original.ruangan));

drop index if exists public.schedule_exact_duplicate_idx;

create unique index schedule_exact_duplicate_idx
  on public.jadwal_kelas(
    kelas_id,
    matakuliah_id,
    hari,
    jam_mulai,
    jam_selesai,
    lower(trim(ruangan))
  );

commit;
