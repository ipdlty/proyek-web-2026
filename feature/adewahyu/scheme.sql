-- Hapus tabel jika sudah ada (urutan dibalik karena Foreign Key)
DROP TABLE IF EXISTS profil_mahasiswa;
DROP TABLE IF EXISTS mahasiswa;
DROP TABLE IF EXISTS dosen;
DROP TABLE IF EXISTS program_studi;

-- 1. Tabel Master Program Studi
CREATE TABLE program_studi (
    id INT AUTO_INCREMENT PRIMARY KEY,
    kode_prodi VARCHAR(10) NOT NULL UNIQUE,
    nama_prodi VARCHAR(100) NOT NULL,
    jenjang ENUM('D3', 'D4', 'S1', 'S2', 'S3') NOT NULL DEFAULT 'S1',
    fakultas VARCHAR(100) NOT NULL,
    akreditasi ENUM('Unggul', 'A', 'Baik Sekali', 'B', 'Baik', 'C') DEFAULT 'Baik',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- 2. Tabel Master Dosen (untuk relasi Dosen Pembimbing Akademik / Wali)
CREATE TABLE dosen (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nidn VARCHAR(15) NOT NULL UNIQUE,
    nama_lengkap VARCHAR(150) NOT NULL,
    gelar_depan VARCHAR(20) NULL,
    gelar_belakang VARCHAR(30) NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    no_hp VARCHAR(20) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. Tabel Master Mahasiswa (Data Inti Akademik)
CREATE TABLE mahasiswa (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nim VARCHAR(20) NOT NULL UNIQUE,
    nama_lengkap VARCHAR(150) NOT NULL,
    email_kampus VARCHAR(100) NOT NULL UNIQUE,
    prodi_id INT NOT NULL,
    dosen_wali_id INT NULL,
    angkatan YEAR NOT NULL,
    jalur_masuk ENUM('SNBP', 'SNBT', 'Mandiri', 'Beasiswa', 'Pindahan') NOT NULL DEFAULT 'SNBT',
    status_akademik ENUM('Aktif', 'Cuti', 'Lulus', 'Drop Out', 'Mengundurkan Diri', 'Non-Aktif') NOT NULL DEFAULT 'Aktif',
    ipk DECIMAL(3, 2) DEFAULT 0.00,
    total_sks INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_mhs_prodi FOREIGN KEY (prodi_id) REFERENCES program_studi(id) ON DELETE RESTRICT,
    CONSTRAINT fk_mhs_dosen FOREIGN KEY (dosen_wali_id) REFERENCES dosen(id) ON DELETE SET NULL
);

-- 4. Tabel Profil Mahasiswa (Data Pribadi, Demografi, & Keluarga - Relasi 1-to-1)
CREATE TABLE profil_mahasiswa (
    id INT AUTO_INCREMENT PRIMARY KEY,
    mahasiswa_id INT NOT NULL UNIQUE,
    nik VARCHAR(16) NOT NULL UNIQUE,
    tempat_lahir VARCHAR(50) NOT NULL,
    tanggal_lahir DATE NOT NULL,
    jenis_kelamin ENUM('L', 'P') NOT NULL,
    agama ENUM('Islam', 'Kristen', 'Katolik', 'Hindu', 'Buddha', 'Konghucu', 'Lainnya') NOT NULL,
    golongan_darah ENUM('A', 'B', 'AB', 'O', '-') DEFAULT '-',
    no_hp VARCHAR(20) NOT NULL,
    email_pribadi VARCHAR(100) NULL,
    
    -- Data Alamat Domisili
    alamat_jalan TEXT NOT NULL,
    rt_rw VARCHAR(10) NULL,
    kelurahan VARCHAR(50) NOT NULL,
    kecamatan VARCHAR(50) NOT NULL,
    kota_kabupaten VARCHAR(50) NOT NULL,
    provinsi VARCHAR(50) NOT NULL,
    kode_pos VARCHAR(10) NULL,
    
    -- Data Orang Tua / Wali
    nama_ayah VARCHAR(150) NULL,
    pekerjaan_ayah VARCHAR(100) NULL,
    nama_ibu VARCHAR(150) NOT NULL,
    pekerjaan_ibu VARCHAR(100) NULL,
    no_hp_ortu VARCHAR(20) NULL,
    
    foto_profil_url VARCHAR(255) NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_profil_mhs FOREIGN KEY (mahasiswa_id) REFERENCES mahasiswa(id) ON DELETE CASCADE
);

-- Index untuk mempercepat pencarian umum
CREATE INDEX idx_mhs_nama ON mahasiswa(nama_lengkap);
CREATE INDEX idx_mhs_angkatan ON mahasiswa(angkatan);
CREATE INDEX idx_mhs_status ON mahasiswa(status_akademik);