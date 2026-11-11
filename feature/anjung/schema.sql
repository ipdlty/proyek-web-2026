-- Buat tipe ENUM untuk Status Keaktifan Dosen
CREATE TYPE status_keaktifan_enum AS ENUM (
    'Aktif', 
    'Cuti', 
    'Studi Lanjut', 
    'Pensiun', 
    'Keluar'
);

-- Buat tipe ENUM untuk Jabatan Fungsional Dosen (sesuai regulasidikti)
CREATE TYPE jabatan_fungsional_enum AS ENUM (
    'Tenaga Pengajar', 
    'Asisten Ahli', 
    'Lektor', 
    'Lektor Kepala', 
    'Profesor'
);

-- Tabel Utama Dosen
CREATE TABLE dosens (
    id SERIAL PRIMARY KEY,
    nidn VARCHAR(20) UNIQUE NOT NULL,
    nip VARCHAR(20) UNIQUE,
    nama_lengkap VARCHAR(150) NOT NULL,
    gelar_depan VARCHAR(50),
    gelar_belakang VARCHAR(100),
    email VARCHAR(100) UNIQUE NOT NULL,
    no_telepon VARCHAR(20),
    status_keaktifan status_keaktifan_enum DEFAULT 'Aktif' NOT NULL,
    jabatan_fungsional jabatan_fungsional_enum DEFAULT 'Tenaga Pengajar' NOT NULL,
    foto_profil VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE -- Digunakan untuk Soft Delete
);

-- Indeks untuk optimasi pencarian (Search & Filter)
CREATE INDEX idx_dosens_nidn ON dosens(nidn);
CREATE INDEX idx_dosens_nama ON dosens(nama_lengkap);
CREATE INDEX idx_dosens_status ON dosens(status_keaktifan);
CREATE INDEX idx_dosens_jabatan ON dosens(jabatan_fungsional);

-- Fungsi trigger otomatis untuk memperbarui kolom updated_at (Opsional untuk PostgreSQL)
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_dosens_modtime
    BEFORE UPDATE ON dosens
    FOR EACH ROW
    EXECUTE FUNCTION update_modified_column();