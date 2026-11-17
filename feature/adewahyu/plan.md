# Implementation Plan: Modul Profil & Master Mahasiswa

## 1. Gambaran Umum
Dokumen ini berisi rencana pengembangan teknis (*implementation plan*) untuk modul **Profil & Master Mahasiswa** pada Sistem Informasi Akademik (SIAKAD). Modul ini mengelola data pokok mahasiswa, relasi program studi dan dosen pembimbing akademik (wali), serta layanan mandiri (*self-service*) pembaruan biodata oleh mahasiswa.

### Tujuan Utama
* Menyediakan sumber kebenaran tunggal (*Single Source of Truth*) untuk data akademik dan demografi mahasiswa.
* Memisahkan data transaksional akademik (`mahasiswa`) dengan data profil statis (`profil_mahasiswa`) untuk menjaga performa *query*.
* Memberikan akses mandiri bagi mahasiswa untuk memperbarui biodata tanpa mengubah data akademik yang dikunci sistem.

---

## 2. Arsitektur Database

Modul ini terdiri dari empat entitas utama:
1. **`program_studi`**: Data master program studi, jenjang, fakultas, dan status akreditasi.
2. **`dosen`**: Data master dosen untuk penugasan Dosen Pembimbing Akademik / Wali.
3. **`mahasiswa`**: Data inti akademik (NIM, email kampus, angkatan, jalur masuk, status akademik, IPK, total SKS).
4. **`profil_mahasiswa`**: Data personal, domisili, dan keluarga dengan relasi *One-to-One* (`1:1`) ke tabel `mahasiswa`.

### Kebijakan Integritas Data (*Foreign Key Constraints*)
* `mahasiswa.prodi_id` $\rightarrow$ `ON DELETE RESTRICT` (Mencegah penghapusan prodi yang masih memiliki mahasiswa).
* `mahasiswa.dosen_wali_id` $\rightarrow$ `ON DELETE SET NULL` (Menjaga data mahasiswa tetap aman jika data dosen dinonaktifkan/dihapus).
* `profil_mahasiswa.mahasiswa_id` $\rightarrow$ `ON DELETE CASCADE` (Menghapus profil secara otomatis jika record induk mahasiswa dihapus).

---

## 3. Tahapan Pengembangan (4 Fase)

### Fase 1: Database & Core Setup
* **Target:** Fondasi skema database dan data awal siap digunakan.
* **Tasks:**
  * [ ] Eksekusi skrip DDL pembuatan tabel (`program_studi`, `dosen`, `mahasiswa`, `profil_mahasiswa`).
  * [ ] Pembuatan *index* pada kolom pencarian utama (`nama_lengkap`, `angkatan`, `status_akademik`).
  * [ ] Eksekusi *database seeder* untuk data referensi awal dan data dummy pengujian.
  * [ ] Konfigurasi model ORM dan relasi antar entitas di backend.

### Fase 2: Backend API & Validasi
* **Target:** Seluruh *endpoint* API berfungsi dengan validasi ketat dan kontrol akses berbasis peran (RBAC).
* **Tasks:**
  * [ ] Implementasi autentikasi dan *middleware* RBAC (`Admin Akademik` vs `Mahasiswa`).
  * [ ] Pembuatan *endpoint* CRUD Master Mahasiswa, Program Studi, dan Dosen Wali.
  * [ ] Pembuatan *endpoint* *self-service* profil mahasiswa (membatasi pembaruan hanya pada field biodata).
  * [ ] Integrasi *Object Storage* (S3 / MinIO / Local Storage) untuk unggah dan kompresi foto profil.
  * [ ] Implementasi fitur *Bulk Import* mahasiswa baru via file CSV/Excel menggunakan transaksi database atomik.
  * [ ] Pencatatan *Audit Log* untuk perubahan data sensitif (NIK, NIM, Status Akademik, dan IPK).

### Fase 3: Frontend UI/UX
* **Target:** Antarmuka portal yang responsif dan intuitif untuk admin maupun mahasiswa.
* **Tasks:**
  * [ ] **Portal Admin:** Tabel daftar mahasiswa dengan *server-side pagination*, pencarian cepat (NIM/Nama), dan multi-filter (Prodi, Angkatan, Status).
  * [ ] **Portal Admin:** Form tambah/ubah data mahasiswa dan modal *bulk import* dengan pratinjau validasi.
  * [ ] **Portal Mahasiswa:** Halaman ringkasan status akademik (*read-only* untuk NIM, Prodi, Dosen Wali, IPK, SKS).
  * [ ] **Portal Mahasiswa:** Form pembaruan biodata (alamat, kontak, orang tua) beserta fitur *crop & preview* foto profil.

### Fase 4: Testing & Deployment
* **Target:** Kualitas kode terverifikasi dan aplikasi siap dirilis ke lingkungan produksi.
* **Tasks:**
  * [ ] *Unit Testing* untuk seluruh aturan validasi input.
  * [ ] *Integration Testing* untuk memastikan mahasiswa tidak dapat memodifikasi data milik mahasiswa lain (IDOR prevention) maupun field akademik terkunci.
  * [ ] *Load Testing* pada *endpoint* pencarian dan ekspor data master mahasiswa.
  * [ ] *Deployment* migrasi database dan aplikasi ke *staging* serta *production*.

---

## 4. Spesifikasi API Endpoint

### A. Portal Mahasiswa (*Self-Service*)
| Method | Endpoint | Deskripsi | Hak Akses |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/v1/me/profile` | Mengambil gabungan data akademik dan profil mahasiswa yang sedang login. | Mahasiswa |
| `PUT` | `/api/v1/me/profile` | Memperbarui data domisili, kontak pribadi, dan informasi orang tua. | Mahasiswa |
| `POST` | `/api/v1/me/avatar` | Mengunggah foto profil baru (`multipart/form-data`). | Mahasiswa |

### B. Portal Admin Akademik
| Method | Endpoint | Deskripsi | Hak Akses |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/v1/students` | Mengambil daftar mahasiswa dengan filter (`prodi_id`, `angkatan`, `status`) & *pagination*. | Admin |
| `GET` | `/api/v1/students/{id}` | Mengambil detail lengkap satu mahasiswa beserta profilnya. | Admin |
| `POST` | `/api/v1/students` | Menambahkan data mahasiswa baru beserta profil awalnya secara atomik. | Admin |
| `PUT` | `/api/v1/students/{id}` | Memperbarui seluruh data akademik maupun profil mahasiswa. | Admin |
| `PATCH` | `/api/v1/students/{id}/status` | Mengubah status akademik (`Aktif`, `Cuti`, `Lulus`, `Drop Out`, dll). | Admin |
| `POST` | `/api/v1/students/import` | Impor massal data mahasiswa baru dari template Excel/CSV. | Admin |

---

## 5. Aturan Validasi & Keamanan

1. **Validasi Identitas:**
   * `nik`: Wajib 16 digit numerik dan unik di seluruh sistem.
   * `nim`: Unik, mengikuti format kode tahun masuk + kode prodi + nomor urut.
   * `email_kampus` & `email_pribadi`: Format email valid dan unik.
2. **Validasi Berkas Foto Profil:**
   * Format yang diizinkan: `JPG`, `JPEG`, `PNG`, `WEBP`.
   * Ukuran maksimal file: `2 MB`.
3. **Pencegahan IDOR (*Insecure Direct Object Reference*):**
   * *Endpoint* `/api/v1/me/*` wajib mengambil `mahasiswa_id` langsung dari token sesi/JWT pengguna yang terautentikasi, bukan dari parameter URL atau *request body*.