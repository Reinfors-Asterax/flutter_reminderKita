# ReminderKita

Aplikasi mobile berbasis Flutter dan Supabase untuk mengelola reminder tugas kuliah.

## Fitur Utama

- Autentikasi pengguna (Login & Register)
- Manajemen kelas dan anggota
- CRUD tugas kuliah
- Upload gambar tugas (Supabase Storage)
- Reminder notifikasi deadline
- Multi-role user (Ketua, Wakil, Mahasiswa)

## Teknologi

- Flutter
- Supabase (Auth, Database, Storage)
- Flutter Local Notifications

## Catatan

Konfigurasi Supabase diberikan saat build agar tidak dibundel sebagai asset:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

Gunakan `.env.example` sebagai referensi nama variabel. Firebase tidak
dikonfigurasi pada repository ini; notifikasi yang aktif adalah local
notification.

Repositori ini digunakan untuk keperluan pengembangan dan dokumentasi
tugas akhir perkuliahan Pemrograman Mobile
