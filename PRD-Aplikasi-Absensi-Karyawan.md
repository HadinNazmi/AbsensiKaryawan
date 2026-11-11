# PRD — Aplikasi Absensi Karyawan

| | |
|---|---|
| **Versi** | 1.1 (Draft) |
| **Tanggal** | 11 November 2026 |
| **Platform** | Flutter Web (PWA) |
| **Backend** | Supabase (Auth, Postgres, Storage, Edge Functions) |
| **Role** | Karyawan, Admin |

---

## 1. Ringkasan

Aplikasi absensi berbasis web/PWA untuk karyawan kantor. Karyawan absen dengan **foto selfie langsung** dan hanya bisa absen jika berada dalam **radius titik kantor**. Waktu absen dicatat otomatis oleh server. Admin dapat melihat absensi hari ini, mengelola karyawan, dan mengekspor rekap ke **Excel**.

## 2. Tujuan

1. Absensi karyawan tercatat valid: lokasi + foto + waktu.
2. Mengurangi manipulasi absen (titip absen, absen dari luar kantor).
3. Admin mendapat rekap harian dan bulanan tanpa input manual.
4. Satu codebase Flutter, dapat diinstal sebagai PWA di HP.

### Di Luar Cakupan (v1)
- Aplikasi native Android/iOS (Play Store / App Store)
- Face recognition / pencocokan wajah otomatis
- Penggajian (payroll)
- Multi-kantor / multi-cabang (disiapkan di database, belum di UI)
- Pengajuan cuti/izin oleh karyawan (lihat Fase 2)

## 3. Pengguna

| Role | Platform | Deskripsi |
|---|---|---|
| **Karyawan** | Web PWA (HP) | Absen masuk dan pulang, melihat riwayat absen sendiri |
| **Admin** | Web (desktop) dan Web PWA | Memantau absensi, mengelola karyawan, pengaturan kantor, ekspor Excel |

## 4. Alur Utama

### 4.1 Absen Karyawan
1. Karyawan login (**nomor HP + password**). Jika pertama kali login (password masih default), wajib ganti password dulu sebelum bisa absen.
2. Buka halaman **Absen**. Aplikasi meminta izin **Lokasi** dan **Kamera**.
3. Aplikasi mengambil koordinat GPS dan menghitung jarak ke titik kantor.
4. Jika **di dalam radius** → tombol **Absen** aktif. Jika di luar → tombol nonaktif, tampil jarak dan pesan "Anda di luar area kantor".
5. Karyawan menekan tombol, kamera depan terbuka, ambil foto (hanya kamera langsung, tanpa upload dari galeri).
6. Aplikasi mengirim foto + koordinat ke Supabase.
7. **Server** memvalidasi ulang radius, mencatat waktu server, menentukan status (Hadir / Terlambat), lalu menyimpan.
8. Karyawan melihat konfirmasi: jam, status, foto.

### 4.2 Absen Pulang
Sama dengan alur di atas, hanya bisa setelah absen masuk pada hari yang sama.

### 4.3 Admin
1. Login → Dashboard hari ini.
2. Lihat daftar absensi hari ini (nama, jam masuk, jam pulang, status, foto, jarak).
3. Buka halaman **Rekap**, pilih rentang tanggal, lalu **Ekspor Excel**.
4. Kelola karyawan dan pengaturan kantor.

## 5. Kebutuhan Fungsional

### 5.1 Autentikasi
| ID | Kebutuhan | Prioritas |
|---|---|---|
| AUTH-1 | Login **nomor HP + password** via Supabase Auth. Nomor HP dinormalisasi ke format `62xxx` lalu dipetakan ke email internal (`62xxx@absen.local`). Tidak ada email atau SMS yang dikirim | Must |
| AUTH-2 | Role disimpan di tabel `profiles` (`karyawan` / `admin`), routing halaman sesuai role | Must |
| AUTH-3 | Sesi tetap login di PWA | Must |
| AUTH-4 | Karyawan tidak bisa mendaftar sendiri. Akun dibuat admin (nama, nomor HP, jabatan) dengan password default `123456` | Must |
| AUTH-5 | **Wajib ganti password saat pertama login**: jika `wajib_ganti_password = true`, hanya halaman Ganti Password yang bisa dibuka. Pada ganti password awal ini **tidak perlu mengisi password lama** (karyawan baru saja login). Password baru minimal 6 karakter dan tidak boleh `123456` | Must |
| AUTH-6 | Ganti password kapan saja dari halaman Profil. Wajib mengisi **password lama**, **password baru**, dan **konfirmasi password baru**. Password lama salah → ditolak. Password baru minimal 6 karakter, tidak boleh `123456`, dan tidak boleh sama dengan password lama | Must |
| AUTH-7 | Lupa password: admin reset ke `123456`, flag `wajib_ganti_password` kembali `true` | Must |
| AUTH-8 | Tidak ada verifikasi email atau OTP SMS di v1 | Must |

### 5.2 Absensi Karyawan
| ID | Kebutuhan | Prioritas |
|---|---|---|
| ABS-1 | Meminta izin lokasi dan kamera; tampil panduan jika ditolak | Must |
| ABS-2 | Menghitung jarak real-time ke titik kantor, tampil status di dalam/di luar radius | Must |
| ABS-3 | Tombol absen aktif hanya jika di dalam radius | Must |
| ABS-4 | Foto diambil langsung dari kamera (tanpa galeri) | Must |
| ABS-5 | Waktu absen = waktu server (bukan jam HP) | Must |
| ABS-6 | Validasi ulang radius di server saat submit | Must |
| ABS-7 | Satu absen masuk dan satu absen pulang per hari per karyawan | Must |
| ABS-8 | Status otomatis: **Hadir** (≤ jam masuk + toleransi) atau **Terlambat** | Must |
| ABS-9 | Foto dibubuhi watermark: nama, tanggal, jam | Should |
| ABS-10 | Riwayat absen pribadi (list per bulan) | Must |
| ABS-11 | Menolak akurasi GPS buruk (mis. > 50 m) dengan pesan ulang | Should |

### 5.3 Admin — Monitoring
| ID | Kebutuhan | Prioritas |
|---|---|---|
| ADM-1 | Dashboard hari ini: jumlah hadir, terlambat, belum absen, tidak hadir | Must |
| ADM-2 | Daftar absensi hari ini dengan foto, jam, jarak, status | Must |
| ADM-3 | Filter berdasarkan tanggal, karyawan, status | Must |
| ADM-4 | Lihat foto absen ukuran penuh | Must |
| ADM-5 | Koreksi status manual (mis. ubah ke Izin/Sakit) dengan catatan | Should |

### 5.4 Admin — Manajemen
| ID | Kebutuhan | Prioritas |
|---|---|---|
| MNG-1 | CRUD karyawan (nama, nomor HP, jabatan, status aktif) | Must |
| MNG-2 | Nonaktifkan karyawan (tidak bisa login, data lama tetap ada) | Must |
| MNG-3 | Pengaturan kantor: titik koordinat, radius (meter), jam masuk, jam pulang, toleransi keterlambatan | Must |
| MNG-4 | Pengaturan hari kerja (mis. Senin–Jumat) | Must |
| MNG-5 | Daftar hari libur | Should |
| MNG-6 | Reset password karyawan ke `123456` | Must |
| MNG-7 | Ubah nomor HP karyawan (sinkron ke akun login) | Must |

### 5.5 Admin — Rekap dan Ekspor Excel
| ID | Kebutuhan | Prioritas |
|---|---|---|
| REP-1 | Rekap per rentang tanggal | Must |
| REP-2 | Ekspor **Excel (.xlsx)**: sheet **Detail** (satu baris per absen) | Must |
| REP-3 | Sheet **Ringkasan** per karyawan: total Hadir, Terlambat, Tidak Hadir (Alpha), Izin/Sakit | Must |
| REP-4 | Kolom Detail: Tanggal, No. HP, Nama, Jam Masuk, Jam Pulang, Status, Jarak (m), Link Foto | Must |
| REP-5 | Nama file otomatis, mis. `rekap-absensi_2026-11-01_2026-11-30.xlsx` | Should |

### 5.6 PWA
| ID | Kebutuhan | Prioritas |
|---|---|---|
| PWA-1 | Bisa diinstal ke layar utama (manifest, ikon, splash) | Must |
| PWA-2 | Wajib HTTPS (syarat kamera dan GPS di browser) | Must |
| PWA-3 | UI responsif: karyawan mobile-first, admin desktop-first dan tetap nyaman di HP | Must |
| PWA-4 | Absen **tidak** mendukung offline (butuh validasi server); tampil pesan jika tidak ada koneksi | Must |

## 6. Aturan Bisnis

1. **Radius**: jarak dihitung dengan rumus Haversine (atau PostGIS) antara koordinat karyawan dan titik kantor. Absen valid jika jarak ≤ radius.
2. **Status**:
   - `hadir` — absen masuk ≤ jam masuk + toleransi
   - `terlambat` — absen masuk > jam masuk + toleransi
   - `alpha` — hari kerja tanpa absen masuk dan tanpa izin
   - `izin` / `sakit` — diinput admin (v1) atau pengajuan karyawan (Fase 2)
3. **Alpha** dibuat otomatis tiap akhir hari kerja oleh job terjadwal (`pg_cron`) untuk karyawan aktif yang belum punya data absen, kecuali hari libur.
4. Absen pulang tanpa absen masuk ditolak.
5. Jika karyawan lupa absen pulang, jam pulang kosong dan ditandai "Belum pulang" di rekap.
6. Data absensi tidak bisa dihapus oleh karyawan; hanya admin yang bisa mengoreksi dan setiap koreksi dicatat.
7. **Nomor HP** unik per karyawan. Input `0812...`, `+62812...`, atau `62812...` dinormalisasi ke `62812...`.
8. Karyawan nonaktif tidak bisa login, dan nomor HP-nya tetap tercatat agar riwayat absen tidak hilang.

## 7. Arsitektur dan Teknis

### 7.1 Stack
| Lapisan | Teknologi |
|---|---|
| Frontend | Flutter Web (PWA) |
| Auth | Supabase Auth (login nomor HP + password, dipetakan ke email internal) |
| Database | Supabase Postgres (+ RLS) |
| File foto | Supabase Storage (bucket privat `absensi-foto`) |
| Logika server | Postgres Function (RPC) dan/atau Edge Function |
| Job terjadwal | `pg_cron` |
| Hosting | Vercel / Netlify / Firebase Hosting / Cloudflare Pages (static, HTTPS) |
| Excel | Package Flutter `excel` (generate di sisi klien) |

### 7.2 Paket Flutter (saran)
`supabase_flutter`, `geolocator`, `camera`, `excel`, `go_router`, state management pilihan (Riverpod/Bloc), `intl`.

### 7.3 Alur Submit Absen (aman)
```
Flutter → ambil GPS + foto
        → upload foto ke Storage (path: {user_id}/{tanggal}/{masuk|pulang}.jpg)
        → panggil RPC `submit_absensi(tipe, lat, lng, akurasi, foto_path)`
RPC     → cek auth.uid() dan role
        → cek belum absen untuk tipe tersebut hari ini
        → hitung jarak ke kantor, tolak jika > radius
        → set waktu = now() (server)
        → hitung status
        → insert ke tabel absensi
```
Kunci keamanan: **klien tidak boleh insert langsung ke tabel `absensi`**. Semua lewat RPC (`SECURITY DEFINER`).

### 7.4 Skema Database

**profiles**
| Kolom | Tipe | Keterangan |
|---|---|---|
| id | uuid (PK, FK auth.users) | |
| no_hp | text, unique | Format `62xxx`, dipakai untuk login |
| nama | text | |
| jabatan | text | |
| role | text | `karyawan` / `admin` |
| aktif | boolean | default true |
| wajib_ganti_password | boolean | default true; jadi `false` setelah ganti password |
| created_at | timestamptz | |

**kantor_setting** (1 baris di v1)
| Kolom | Tipe |
|---|---|
| id | uuid (PK) |
| nama | text |
| latitude | double precision |
| longitude | double precision |
| radius_meter | int |
| jam_masuk | time |
| jam_pulang | time |
| toleransi_menit | int |
| hari_kerja | int[] (1=Senin … 7=Minggu) |

**hari_libur**
| Kolom | Tipe |
|---|---|
| id | uuid (PK) |
| tanggal | date, unique |
| keterangan | text |

**absensi**
| Kolom | Tipe | Keterangan |
|---|---|---|
| id | uuid (PK) | |
| user_id | uuid (FK profiles) | |
| tanggal | date | |
| jam_masuk | timestamptz | |
| foto_masuk | text | path Storage |
| lat_masuk, lng_masuk | double precision | |
| jarak_masuk_m | numeric | |
| jam_pulang | timestamptz | nullable |
| foto_pulang | text | nullable |
| lat_pulang, lng_pulang | double precision | nullable |
| jarak_pulang_m | numeric | nullable |
| status | text | `hadir`, `terlambat`, `izin`, `sakit`, `alpha` |
| catatan | text | nullable |
| dikoreksi_oleh | uuid | nullable |
| created_at | timestamptz | |

Constraint: `unique (user_id, tanggal)`.

### 7.5 Row Level Security (RLS)
| Tabel | Karyawan | Admin |
|---|---|---|
| profiles | Baca profil sendiri | Baca/tulis semua |
| kantor_setting | Baca | Baca/tulis |
| hari_libur | Baca | Baca/tulis |
| absensi | Baca milik sendiri; **tanpa insert/update langsung** | Baca semua; update untuk koreksi |
| Storage `absensi-foto` | Upload ke folder sendiri; baca milik sendiri | Baca semua |

Foto ditampilkan melalui **signed URL** (bukan public).

### 7.6 Pembuatan Akun Karyawan
Operasi akun memerlukan service role key → lakukan lewat **Edge Function** (jangan simpan service key di Flutter). Semua function memeriksa bahwa pemanggil adalah admin.

| Edge Function | Fungsi |
|---|---|
| `create-employee` | Normalisasi nomor HP, buat user Auth (`62xxx@absen.local`, password `123456`, `email_confirm: true`), isi `profiles` dengan `wajib_ganti_password = true` |
| `reset-password` | Set password ke `123456` dan `wajib_ganti_password = true` |
| `update-phone` | Ubah nomor HP di `profiles` dan email internal di Auth |

**Alur ganti password (dari Profil)**: aplikasi memverifikasi password lama dengan `signInWithPassword` memakai email internal karyawan. Jika berhasil, panggil `updateUser(password: baru)`. Jika gagal, tampilkan "Password lama salah". Pada ganti password awal (`wajib_ganti_password = true`) langkah verifikasi ini dilewati.

**Alur login di Flutter**: karyawan mengetik nomor HP → aplikasi menormalisasi dan mengubahnya jadi `62xxx@absen.local` → `signInWithPassword`. Setelah login, aplikasi membaca `wajib_ganti_password`; jika `true`, arahkan ke halaman Ganti Password.

## 8. Anti-Kecurangan

| Risiko | Mitigasi |
|---|---|
| Ubah jam HP | Waktu memakai `now()` server |
| Fake GPS | Validasi radius di server, simpan akurasi GPS, tandai akurasi mencurigakan; admin bisa meninjau |
| Upload foto lama | Hanya kamera langsung; watermark waktu server; foto diunggah saat itu juga |
| Titip absen | Foto wajah wajib; admin bisa meninjau foto |
| Edit data lewat API | RLS + insert hanya via RPC |

> Catatan: di web, deteksi fake GPS tidak bisa 100% akurat. Mitigasi di atas mengurangi risiko, bukan menghilangkannya.

## 9. Kebutuhan Non-Fungsional

- **Keamanan**: HTTPS, RLS aktif di semua tabel, bucket foto privat.
- **Performa**: proses absen (setelah foto diambil) selesai < 5 detik pada koneksi 4G; foto dikompres (maks ± 500 KB, lebar ≤ 800 px) sebelum upload.
- **Kompatibilitas**: Chrome dan Safari versi terbaru (Android dan iOS); admin di Chrome/Edge desktop.
- **Zona waktu**: simpan UTC, tampilkan sesuai zona kantor (default WIB / Asia/Jakarta).
- **Privasi**: foto dan lokasi hanya diakses karyawan bersangkutan dan admin; kebijakan retensi foto ditentukan (usulan: hapus foto > 12 bulan, data teks tetap).
- **Bahasa UI**: Bahasa Indonesia.

## 10. Daftar Halaman

**Karyawan**
1. Login (nomor HP + password)
2. Ganti Password Pertama Kali (otomatis, hanya jika wajib)
3. Beranda (status absen hari ini, tombol Absen)
4. Absen (cek lokasi → kamera → konfirmasi)
5. Riwayat Absensi
6. Profil / Ganti Password

**Admin**
1. Login
2. Dashboard (ringkasan hari ini)
3. Absensi Hari Ini (tabel + foto)
4. Rekap dan Ekspor Excel
5. Data Karyawan (CRUD, ubah nomor HP, reset password)
6. Pengaturan Kantor (peta titik, radius, jam kerja, hari libur)

## 11. Kriteria Penerimaan (MVP)

- [ ] Karyawan di luar radius tidak bisa absen (UI dan server menolak).
- [ ] Karyawan di dalam radius dapat absen masuk dan pulang dengan foto kamera langsung.
- [ ] Jam absen berasal dari server dan tampil di riwayat.
- [ ] Status Hadir/Terlambat benar sesuai pengaturan jam dan toleransi.
- [ ] Karyawan tidak bisa melihat data karyawan lain.
- [ ] Admin dapat melihat semua absensi hari ini beserta foto.
- [ ] Admin dapat ekspor Excel dengan sheet Detail dan Ringkasan (Hadir, Terlambat, Alpha).
- [ ] Aplikasi dapat diinstal sebagai PWA di Android dan iOS.
- [ ] Alpha tercatat otomatis untuk hari kerja tanpa absen.
- [ ] Karyawan login dengan nomor HP + password (format `08...` dan `+62...` sama-sama diterima).
- [ ] Login pertama dengan password `123456` memaksa ganti password; `123456` ditolak sebagai password baru.
- [ ] Ganti password dari Profil hanya berhasil jika password lama benar.
- [ ] Admin dapat membuat karyawan, mengubah nomor HP, dan reset password.

## 12. Rencana Pengembangan

| Fase | Isi | Estimasi |
|---|---|---|
| **0 — Setup** | Proyek Supabase, skema DB, RLS, bucket, deploy PWA kosong | 2–3 hari |
| **1 — Karyawan** | Login, absen (GPS + kamera), riwayat | 1–1,5 minggu |
| **2 — Admin** | Dashboard, absensi hari ini, CRUD karyawan, pengaturan kantor | 1–1,5 minggu |
| **3 — Rekap** | Ekspor Excel, job alpha, hari libur | 3–5 hari |
| **4 — QA dan Rilis** | Uji di berbagai HP/browser, perbaikan, deploy produksi | 3–5 hari |

### Fase 2 (setelah MVP)
- Pengajuan izin/cuti oleh karyawan dengan persetujuan admin
- Notifikasi pengingat absen (Web Push)
- Multi-kantor
- Grafik statistik di dashboard
- Face matching

## 13. Risiko

| Risiko | Dampak | Penanganan |
|---|---|---|
| Kamera/GPS ditolak atau tidak didukung browser | Karyawan tidak bisa absen | Panduan izin di UI; uji Safari iOS sejak awal |
| Akurasi GPS dalam gedung rendah | Absen valid ditolak | Radius cukup longgar (mis. 50–100 m), tampilkan akurasi, ijinkan coba ulang |
| Kuota Supabase gratis (Storage/DB) habis | Layanan terhenti | Kompres foto, kebijakan retensi, pantau pemakaian |
| Fake GPS | Data tidak valid | Lihat bagian 8 |
| Password default `123456` + nomor HP mudah ditebak | Akun bisa dipakai orang lain sebelum password diganti | Wajib ganti saat login pertama; buat akun saat karyawan siap login; tinjau akun yang belum pernah ganti password |
| Karyawan ganti nomor HP | Tidak bisa login | Admin ubah lewat `update-phone` |

## 14. Pertanyaan Terbuka

1. Jumlah karyawan dan jumlah kantor (satu atau lebih)?
2. Berapa radius yang diinginkan dan jam kerja resmi?
3. Apakah shift atau jam kerja sama untuk semua karyawan?
4. Perlu absen pulang atau hanya absen masuk?
5. Izin/sakit/cuti: diinput admin saja, atau karyawan harus bisa mengajukan sendiri di v1?
6. Berapa lama foto absen disimpan?
