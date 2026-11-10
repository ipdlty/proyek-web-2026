-- =========================================================
-- DATABASE SCHEMA: KARTU RENCANA STUDI (KRS)
-- Compatible with PostgreSQL / MySQL
-- =========================================================

-- 1. TABEL PROGRAM STUDI & DOSEN
CREATE TABLE dosen (
    id_dosen VARCHAR(20) PRIMARY KEY,
    nip VARCHAR(30) UNIQUE NOT NULL,
    nama VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. TABEL MAHASISWA
CREATE TABLE mahasiswa (
    nim VARCHAR(20) PRIMARY KEY,
    nama VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    id_dosen_wali VARCHAR(20) REFERENCES dosen(id_dosen),
    ipk_terakhir DECIMAL(3,2) DEFAULT 0.00,
    max_sks INT DEFAULT 24,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. TABEL PERIODE AKADEMIK
CREATE TABLE periode_akademik (
    id_periode VARCHAR(10) PRIMARY KEY, -- Contoh: '20261' (2026 Ganjil)
    nama_periode VARCHAR(50) NOT NULL,
    is_krs_active BOOLEAN DEFAULT FALSE,
    is_drop_active BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. TABEL MATA KULIAH & PRASYARAT
CREATE TABLE mata_kuliah (
    kode_mk VARCHAR(15) PRIMARY KEY,
    nama_mk VARCHAR(100) NOT NULL,
    sks INT NOT NULL,
    semester_paket INT NOT NULL
);

CREATE TABLE prasyarat_mk (
    kode_mk VARCHAR(15) REFERENCES mata_kuliah(kode_mk) ON DELETE CASCADE,
    kode_mk_syarat VARCHAR(15) REFERENCES mata_kuliah(kode_mk) ON DELETE CASCADE,
    PRIMARY KEY (kode_mk, kode_mk_syarat)
);

-- 5. TABEL KELAS MATA KULIAH (OFFERING)
CREATE TABLE kelas_kuliah (
    id_kelas INT AUTO_INCREMENT PRIMARY KEY,
    kode_mk VARCHAR(15) REFERENCES mata_kuliah(kode_mk),
    id_periode VARCHAR(10) REFERENCES periode_akademik(id_periode),
    nama_kelas VARCHAR(5) NOT NULL, -- Contoh: 'A', 'B', 'NR'
    kuota INT NOT NULL,
    sisa_kuota INT NOT NULL,
    hari VARCHAR(10) NOT NULL, -- Contoh: 'Senin'
    jam_mulai TIME NOT NULL,
    jam_selesai TIME NOT NULL,
    ruangan VARCHAR(20),
    id_dosen_pengampu VARCHAR(20) REFERENCES dosen(id_dosen)
);

-- 6. TABEL HEADER KRS
CREATE TABLE krs_header (
    id_krs INT AUTO_INCREMENT PRIMARY KEY,
    nim VARCHAR(20) REFERENCES mahasiswa(nim),
    id_periode VARCHAR(10) REFERENCES periode_akademik(id_periode),
    status_krs ENUM('DRAFT', 'SUBMITTED', 'APPROVED', 'REJECTED') DEFAULT 'DRAFT',
    total_sks INT DEFAULT 0,
    catatan_dosen TEXT,
    tanggal_submit TIMESTAMP NULL,
    tanggal_approval TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_krs_mahasiswa_periode UNIQUE (nim, id_periode)
);

-- 7. TABEL DETAIL KRS (ITEM MATKUL YANG DIAMBIL)
CREATE TABLE krs_detail (
    id_krs_detail INT AUTO_INCREMENT PRIMARY KEY,
    id_krs INT REFERENCES krs_header(id_krs) ON DELETE CASCADE,
    id_kelas INT REFERENCES kelas_kuliah(id_kelas),
    status_item ENUM('TAKEN', 'DROPPED') DEFAULT 'TAKEN',
    dropped_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_kelas_krs UNIQUE (id_krs, id_kelas)
);

-- INDEXING UNTUK OPTIMASI PERFORMA
CREATE INDEX idx_krs_mahasiswa ON krs_header(nim);
CREATE INDEX idx_krs_periode ON krs_header(id_periode);
CREATE INDEX idx_kelas_periode ON kelas_kuliah(id_periode);