# Plan: Fitur Profil & Master Dosen

## 1. Tujuan
Membangun modul manajemen data dosen yang komprehensif, memungkinkan admin untuk melakukan pengelolaan data (CRUD) profil dosen secara terpusat, serta menyediakan informasi status akademik dan fungsional yang akurat bagi sivitas akademika.

## 2. Ruang Lingkup Fitur (CRUD)
- **Create (Tambah Dosen):** Input data pribadi, NIDN, gelar depan/belakang, status keaktifan, dan jabatan fungsional.
- **Read (Lihat/Daftar Dosen):** Menampilkan tabel daftar dosen dengan fitur *filtering* (berdasarkan status keaktifan & jabatan fungsional) dan *search* (berdasarkan NIDN/Nama).
- **Update (Ubah Dosen):** Memperbarui informasi profil, perubahan status keaktifan (aktif, cuti, pensiun, keluar), atau kenaikan jabatan fungsional.
- **Delete (Hapus Dosen):** Menghapus data dosen (implementasi *soft delete* disarankan untuk menjaga integritas data akademik/riwayat mengajar).

## 3. Struktur Atribut Data Dosen
- `id` (Primary Key, UUID/BigInt)
- `nidn` (Nomor Induk Dosen Nasional - Unique)
- `nip` (Nomor Induk Pegawai - Opsional/Unique)
- `nama_lengkap` (Nama lengkap tanpa gelar)
- `gelar_depan` (Contoh: Prof., Dr.)
- `gelar_belakang` (Contoh: S.Kom., M.T., Ph.D.)
- `email` (Email institusi/pribadi)
- `no_telepon` (Kontak aktif)
- `status_keaktifan` (Enum: `Aktif`, `Cuti`, `Studi Lanjut`, `Pensiun`, `Keluar`)
- `jabatan_fungsional` (Enum: `Tenaga Pengajar`, `Asisten Ahli`, `Lektor`, `Lektor Kepala`, `Profesor`)
- `foto_profil` (Path/URL file foto)

## 4. Rancangan Endpoints API (REST)
- `GET /api/v1/dosen` - Mendapatkan daftar dosen (dengan *pagination* dan *filter*).
- `GET /api/v1/dosen/{id}` - Mendapatkan detail profil dosen tertentu.
- `POST /api/v1/dosen` - Menambahkan data dosen baru.
- `PUT /api/v1/dosen/{id}` - Memperbarui data dosen.
- `DELETE /api/v1/dosen/{id}` - Menghapus data dosen (*soft delete*).