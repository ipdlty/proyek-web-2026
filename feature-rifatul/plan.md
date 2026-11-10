Rencana Pengembangan Sistem Kartu Rencana Studi (KRS)

1. Ringkasan Sistem

Fitur KRS dirancang untuk mengelola siklus perencanaan akademik mahasiswa, mulai dari pemilihan mata kuliah, persetujuan oleh Dosen Wali, hingga mekanisme drop/pembatalan mata kuliah selama periode revisi KRS.

2. Aktor & Hak Akses (User Roles)

Mahasiswa:

Melihat daftar mata kuliah & kuota kelas yang dibuka pada semester aktif.

Mengisi / menambah daftar mata kuliah ke draft KRS.

Mengajukan (submit) KRS ke Dosen Wali.

Melakukan Drop Matkul (sesuai periode yang diizinkan).

Melihat status persetujuan KRS.

Dosen Wali (Academic Advisor):

Melihat daftar pengajuan KRS dari mahasiswa bimbingan.

Menyetujui (Approve) atau Menolak (Reject) KRS beserta memberikan catatan/alasan.

Admin / Akademik:

Membuka/menutup periode KRS dan periode Drop Matkul.

Mengelola jadwal, kuota kelas, dan penugasan Dosen Wali.

3. Alur Kerja (Workflow) & Aturan Bisnis

A. Alur Pengisian KRS

Pengecekan Syarat:

Periode pengisian KRS harus berstatus ACTIVE.

Beban SKS maksimal mahasiswa ditentukan berdasarkan IPK semester sebelumnya (misal: IPK ≥ 3.00 max 24 SKS).

Drafting:

Mahasiswa memilih kelas mata kuliah.

Sistem memvalidasi:

Bentrok jadwal (hari & jam).

Prasyarat mata kuliah (prerequisites).

Sisa kuota kelas.

Batas maksimal SKS.

Pengajuan (Submit):

Status KRS berubah dari DRAFT menjadi SUBMITTED.

Data KRS terkunci dari perubahan mahasiswa hingga diproses Dosen Wali.

B. Alur Persetujuan Dosen Wali

Dosen Wali menerima notifikasi/daftar pengajuan.

Dosen Wali meninjau kesesuaian matkul dan IPK.

Keputusan:

APPROVED: Status menjadi APPROVED. SKS terkunci resmi, kuota kelas terpotong permanen.

REJECTED: Status kembali ke REJECTED / DRAFT dengan catatan perbaikan dari dosen. Mahasiswa harus revisi dan resubmit.

C. Alur Drop Mata Kuliah

Mahasiswa mengajukan drop mata kuliah yang telah disetujui selama periode DROP_PERIOD aktif.

Status item KRS berubah menjadi DROPPED.

Kuota kelas dikembalikan (+1) dan total SKS mahasiswa disesuaikan.

4. Status Siklus KRS (State Machine)

DRAFT: Mahasiswa sedang memilih mata kuliah.

SUBMITTED: Menunggu persetujuan Dosen Wali.

APPROVED: Disetujui oleh Dosen Wali.

REJECTED: Ditolak oleh Dosen Wali, butuh revisi.

Status pada Detail Item Mata Kuliah:

TAKEN: Diambil/Aktif.

DROPPED: Dibatalkan/Drop.