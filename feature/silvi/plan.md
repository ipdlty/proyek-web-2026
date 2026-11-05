# Modul Manajemen Pengguna & Peran - Sistem Informasi Penelitian Kampus

## 1. Deskripsi Modul
Modul ini bertanggung jawab untuk mengelola seluruh akun pengguna yang terlibat dalam ekosistem penelitian kampus, meliputi Administrator, Dosen (Peneliti/Reviewer), dan Mahasiswa (Anggota Peneliti). Modul ini juga mengatur hak akses (role-based access control) serta status keaktifan akun.

## 2. Entitas Utama & Peran (Roles)
- **Admin Penelitian**: Mengelola sistem secara keseluruhan, memverifikasi akun dosen/mahasiswa, dan menetapkan peran.
- **Dosen**: Mengajukan usulan penelitian, bertindak sebagai ketua peneliti, atau menjadi reviewer proposal.
- **Mahasiswa**: Terdaftar sebagai anggota tim peneliti mendampingi dosen.

## 3. Fitur Utama
### A. Manajemen Pengguna (User Management)
- **Tambah/Daftar Pengguna**: Admin dapat menambahkan pengguna baru atau pengguna melakukan registrasi mandiri dengan validasi email institusi.
- **Daftar & Filter Pengguna**: Menampilkan tabel data pengguna dengan fitur pencarian berdasarkan nama, NIM/NIP, email, dan filter berdasarkan *Role* serta *Status Akun*.
- **Edit & Hapus Pengguna**: Mengubah informasi profil pengguna atau menghapus/menonaktifkan akun.

### B. Manajemen Peran & Hak Akses (Role Assignment)
- **Assign Role**: Admin dapat mengubah atau menetapkan peran pengguna (Admin, Dosen, Mahasiswa, Reviewer).
- **Multi-Role Support (Opsional)**: Memungkinkan seorang Dosen memiliki peran tambahan sebagai Reviewer.

### C. Keamanan & Status Akun (Security & Account Status)
- **Status Akun**: Pengaturan status akun (`active`, `inactive`, `suspended`, `pending_verification`).
- **Reset Password**: 
  - Fitur *Forgot Password* via email untuk pengguna.
  - Admin dapat melakukan *Force Reset Password* secara manual dari panel admin.