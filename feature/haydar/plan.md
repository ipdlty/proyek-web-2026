# PLAN — Web Perpustakaan & Bebas Pustaka

## 1. Tujuan

Membangun web untuk dua hal:

1. **Perpustakaan**: katalog buku, peminjaman, pengembalian, reservasi, denda.
2. **Bebas Pustaka**: mahasiswa mengajukan surat bebas pustaka secara online. Sistem mengecek tanggungan secara otomatis, petugas memverifikasi, lalu surat terbit sebagai PDF dengan QR cek keaslian.

Bebas pustaka itu syarat yudisium/wisuda di banyak kampus. Referensi riset: Universitas Andalas (kliring mandiri, panduan update 14 Januari 2026), UGM (bebas pustaka lewat portal, menonaktifkan keanggotaan), Bina Darma, Telkom University, ITS (e-Bebas Pustaka, sosialisasi Juli 2026). Pola umumnya sama: **tidak ada pinjaman + tidak ada denda + karya akhir terunggah**. Aturan ini sudah dijadikan setting di `scheme.sql` supaya bisa diubah per kampus.

> Catatan: aturan final harus dicocokkan dengan perpustakaan kampus yang jadi target (misalnya UNIM). Jangan kunci syarat di kode, ambil dari tabel `settings`.

## 2. Aktor & Hak Akses

| Role | Bisa apa |
|---|---|
| `mahasiswa` | Cari buku, reservasi, lihat pinjaman & denda, unggah karya akhir, ajukan bebas pustaka, unduh surat |
| `pustakawan` | Kelola koleksi, proses pinjam/kembali, catat pembayaran denda, review karya akhir, verifikasi pengajuan, terbitkan surat |
| `admin` | Semua hak pustakawan + kelola user, setting aturan, bebaskan denda, lihat audit log |

## 3. Fitur

### 3.1 MVP (kerjakan dulu, urut)
1. Auth (login, role, ganti password)
2. CRUD buku + eksemplar (barcode)
3. Katalog + pencarian judul/penulis
4. Peminjaman & pengembalian (scan barcode anggota + barcode buku)
5. Denda otomatis + pencatatan pembayaran
6. Unggah karya akhir + review pustakawan
7. **Pengajuan bebas pustaka** + cek otomatis + verifikasi + terbit PDF
8. Halaman publik verifikasi surat (`/verifikasi/:token`)

### 3.2 Tahap 2
- Reservasi buku, perpanjangan pinjam
- Notifikasi jatuh tempo (email/WhatsApp)
- Dashboard statistik, laporan Excel/PDF
- Import anggota & buku dari CSV
- SSO kampus (kalau ada)

### 3.3 Alur Bebas Pustaka

```
Mahasiswa klik "Ajukan"
      │
      ▼
fn_clearance_eligibility(member)
  ├─ ada pinjaman aktif?   → tolak, tampilkan daftar buku
  ├─ ada denda?            → tolak, tampilkan nominal
  └─ karya akhir belum disetujui? → arahkan ke unggah
      │ semua lolos
      ▼
status: diajukan ──► pustakawan verifikasi
      │                   ├─ ditolak (isi reject_reason)
      │                   ▼
      │               disetujui
      ▼
fn_issue_clearance_letter()
  ├─ validasi ulang syarat (anti race condition)
  ├─ buat nomor surat + token QR
  ├─ status: diterbitkan
  └─ keanggotaan jadi alumni/nonaktif
      ▼
PDF surat bisa diunduh
```

## 4. Tech Stack (usulan)

Ini usulan, bukan keharusan. Sesuaikan dengan yang kamu kuasai.

| Lapisan | Pilihan | Alasan |
|---|---|---|
| DB | PostgreSQL 15+ | Skema sudah ditulis untuk ini (enum, partial index, trigger) |
| Backend | Node.js + Express/NestJS **atau** Laravel | Pilih yang paling kamu kuasai |
| Frontend | React/Next.js + Tailwind | |
| Auth | JWT/session + bcrypt/argon2 | |
| PDF | Puppeteer / pdf-lib | Surat + QR |
| Storage | Local/S3/Supabase Storage | File karya akhir |
| Deploy | VPS + Nginx, atau Railway/Render | |

## 5. Struktur Database

Detail lengkap ada di `scheme.sql`. Ringkasan:

- **Master**: `faculties`, `study_programs`, `categories`, `settings`
- **User**: `users`, `members`
- **Koleksi**: `books` (judul), `book_items` (eksemplar fisik + barcode)
- **Sirkulasi**: `loans`, `reservations`
- **Denda**: `fines`, `fine_payments`
- **Repositori**: `thesis_submissions`
- **Bebas pustaka**: `clearance_requests`, `clearance_status_history`, `clearance_letters`
- **Sistem**: `notifications`, `audit_logs`

Logika yang sudah ditanam di DB:
- Validasi pinjam: anggota aktif, batas pinjam, tidak ada denda, eksemplar tersedia
- Status eksemplar sinkron otomatis saat pinjam/kembali/hilang
- Denda terlambat/hilang dihitung otomatis saat status loan berubah
- Pembayaran denda otomatis mengubah status ke `lunas`
- Satu pengajuan bebas pustaka aktif per anggota (unique partial index)
- `fn_clearance_eligibility()` dan `fn_issue_clearance_letter()`

## 6. Endpoint API (draft)

```
POST   /auth/login
GET    /me

GET    /books?q=&category=&page=
GET    /books/:id
POST   /books                      [pustakawan]
POST   /books/:id/items            [pustakawan]

POST   /loans                      [pustakawan]  { member_code, item_barcode }
POST   /loans/:id/return           [pustakawan]
POST   /loans/:id/lost             [pustakawan]
GET    /me/loans
GET    /me/fines
POST   /fines/:id/pay              [pustakawan]
POST   /fines/:id/waive            [admin]

POST   /thesis                     [mahasiswa]   upload
PATCH  /thesis/:id/review          [pustakawan]

GET    /clearance/eligibility      [mahasiswa]
POST   /clearance                  [mahasiswa]   ajukan
GET    /clearance/me
GET    /clearance                  [pustakawan]  daftar antrian
PATCH  /clearance/:id/verify       [pustakawan]  setuju/tolak
POST   /clearance/:id/issue        [pustakawan]  panggil fn_issue_clearance_letter
GET    /clearance/:id/letter.pdf

GET    /public/verify/:token       tanpa login
```

## 7. Halaman Frontend

**Mahasiswa**: Beranda, Katalog, Detail buku, Pinjaman saya, Denda saya, Unggah karya akhir, **Status Bebas Pustaka** (checklist 3 syarat + tombol ajukan + unduh surat)

**Pustakawan**: Dashboard, Sirkulasi (scan), Kelola buku, Kelola denda, Review karya akhir, Antrian bebas pustaka

**Admin**: Kelola user/anggota, Setting aturan, Audit log

**Publik**: Cek keaslian surat

## 8. Keamanan (wajib, bukan opsional)

- Hash password dengan argon2/bcrypt. Jangan simpan plaintext.
- Semua query pakai parameter (anti SQL injection).
- Cek role di backend untuk setiap endpoint. Menyembunyikan tombol di frontend tidak cukup.
- Validasi file upload: tipe PDF, ukuran maksimal, nama file di-generate ulang.
- Token QR 24 byte random, bukan ID berurutan.
- Catat aksi sensitif ke `audit_logs` (bebaskan denda, terbitkan/cabut surat, ubah setting).
- Rate limit di login.
- Data pribadi mahasiswa hanya bisa diakses oleh pemiliknya dan petugas.

## 9. Roadmap

| Fase | Isi | Estimasi |
|---|---|---|
| 0 | Setup repo, DB, migrasi `scheme.sql`, seed | 1–2 hari |
| 1 | Auth + CRUD buku/eksemplar + katalog | 1 minggu |
| 2 | Sirkulasi + denda | 1 minggu |
| 3 | Karya akhir + bebas pustaka + PDF/QR | 1–1,5 minggu |
| 4 | Dashboard, laporan, notifikasi | 1 minggu |
| 5 | Testing, perbaikan, deploy | 1 minggu |

Estimasi untuk pengerjaan solo paruh waktu. Perkiraan ini bisa meleset kalau tabrakan dengan jadwal kuliah, jadi jangan dijadikan janji ke klien.

## 10. Testing yang harus ada

- Pinjam saat punya denda → harus ditolak
- Pinjam melebihi `max_loans` → ditolak
- Satu eksemplar dipinjam dua orang bersamaan → hanya satu berhasil (cek unique index)
- Kembali telat 5 hari → denda = 5 × `fine_per_day`, tidak melebihi plafon
- Pembayaran melebihi nominal denda → ditolak
- Ajukan bebas pustaka dengan pinjaman aktif → ditolak
- Terbitkan surat dua kali untuk pengajuan sama → gagal
- Token QR salah → 404, bukan error server

## 11. Risiko & Keputusan Terbuka

- **Aturan tiap kampus beda**: ada yang wajib unggah repositori, ada yang wajib survei, ada yang butuh surat bebas keuangan. Buat syarat bisa dikonfigurasi.
- **Data awal**: anggota dan koleksi lama harus diimpor. Siapkan format CSV sejak awal.
- **Integrasi SIAKAD**: kalau kampus punya, sinkron data mahasiswa lewat API/CSV. Kalau tidak ada, input manual.
- **Tanda tangan surat**: tanda tangan digital/basah dan kebijakan kampus tentang keabsahannya harus ditanyakan ke pihak perpustakaan.

## 12. Cara Mulai

```bash
createdb perpus
psql -d perpus -f scheme.sql
```

Lalu mulai dari Fase 1. Jangan loncat ke fitur bebas pustaka sebelum sirkulasi dan denda jalan, karena bebas pustaka bergantung penuh pada data dua modul itu.