# Kontrak Backend (Supabase), sudah selesai dibuat, JANGAN diubah

## .env
- SUPABASE_URL
- SUPABASE_ANON_KEY
- EMAIL_DOMAIN (mis. absen.local)
Hanya 3 nilai ini yang boleh ada di .env. Jangan pernah memakai service_role key di Flutter.

## Login
Supabase Auth memakai email internal. Karyawan login dengan nomor HP:
email = '<hp_normalisasi>@<EMAIL_DOMAIN>', contoh 6281234567890@absen.local.
Normalisasi nomor HP: buang spasi, "-", "(", ")", "."; buang "+" di depan; awalan "0" diganti "62"; awalan "8" ditambah "62" di depan. Valid jika cocok regex ^628\d{8,12}$. Jika tidak valid tampilkan "Nomor HP tidak valid".
Password default akun baru: 123456 (wajib diganti saat login pertama).

## Tabel (schema public)
- profiles: id (uuid = auth user id), no_hp, nama, jabatan, role ('karyawan'|'admin'), aktif (bool), wajib_ganti_password (bool), created_at
- kantor_setting (1 baris): id, nama, latitude, longitude, radius_meter, jam_masuk (time), jam_pulang (time), toleransi_menit, hari_kerja (int[] 1=Senin..7=Minggu)
- hari_libur: id, tanggal (date, unik), keterangan
- absensi: id, user_id, tanggal (date), jam_masuk, foto_masuk, lat_masuk, lng_masuk, jarak_masuk_m, akurasi_masuk_m, jam_pulang, foto_pulang, lat_pulang, lng_pulang, jarak_pulang_m, akurasi_pulang_m, status ('hadir'|'terlambat'|'izin'|'sakit'|'alpha'), catatan, dikoreksi_oleh, dikoreksi_at, created_at. Unik (user_id, tanggal). jam_masuk dan jam_pulang bertipe timestamptz (UTC).

## Hak akses (RLS)
- Karyawan: hanya BACA absensi dan profil miliknya. TIDAK bisa insert/update absensi langsung. Boleh baca kantor_setting dan hari_libur.
- Admin: baca semua, update profiles, tulis kantor_setting dan hari_libur, insert/update absensi (untuk koreksi).

## RPC (supabase.rpc)
- submit_absensi(p_tipe 'masuk'|'pulang', p_lat, p_lng, p_akurasi, p_foto_path) → baris absensi. Server memvalidasi radius, hari kerja, dan waktu (waktu server), lalu menentukan status hadir/terlambat. Error dikirim sebagai pesan Bahasa Indonesia (PostgrestException.message), tampilkan apa adanya.
- selesai_ganti_password() → panggil setelah updateUser(password) berhasil pada ganti password awal.
- rekap_ringkasan(p_dari date, p_sampai date) → baris per karyawan: user_id, nama, no_hp, hadir, terlambat, izin, sakit, alpha (khusus admin).

## Edge Function: admin-karyawan (khusus admin)
Panggil dengan supabase.functions.invoke('admin-karyawan', body: {...}).
- {action:'create', nama, no_hp, jabatan, role?} → buat akun, password 123456
- {action:'reset-password', user_id} → password jadi 123456, wajib ganti lagi
- {action:'update-phone', user_id, no_hp} → ubah nomor HP dan akun login
Respons sukses {ok:true}; gagal {error:'pesan'} (tampilkan pesannya).

## Storage
Bucket privat 'absensi-foto'. Upload hanya ke folder milik sendiri.
Path: {user_id}/{yyyy-MM-dd}/{masuk|pulang}-{epochMillis}.jpg, JPEG, maks 1 MB.
Tampilkan foto lewat createSignedUrl (bukan URL publik).

## Aturan lain
- Zona waktu tampilan: WIB (UTC+7). Kolom tanggal absen mengikuti WIB.
- Alpha dibuat otomatis oleh server tiap malam; aplikasi tidak perlu membuatnya.
- Karyawan nonaktif (aktif=false): aplikasi harus langsung logout setelah login.
- Admin bukan peserta absen (tidak muncul sebagai karyawan di rekap).
- Bahasa UI: Indonesia.

