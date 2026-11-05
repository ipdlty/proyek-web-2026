-- --------------------------------------------------------
-- 1. Tabel Peran (Roles)
-- --------------------------------------------------------
CREATE TABLE roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL, -- contoh: 'admin', 'dosen', 'mahasiswa', 'reviewer'
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- --------------------------------------------------------
-- 2. Tabel Pengguna (Users)
-- --------------------------------------------------------
CREATE TYPE account_status AS ENUM ('active', 'inactive', 'suspended', 'pending_verification');

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    uuid UUID DEFAULT gen_random_uuid() UNIQUE NOT NULL,
    nomor_induk VARCHAR(50) UNIQUE NOT NULL, -- NIP untuk Dosen/Admin, NIM untuk Mahasiswa
    name VARCHAR(150) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL, -- hashed password
    status account_status DEFAULT 'pending_verification',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- --------------------------------------------------------
-- 3. Tabel Penghubung Pengguna & Peran (User Roles / Assign Role)
-- --------------------------------------------------------
CREATE TABLE user_roles (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    role_id INT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE,
    UNIQUE (user_id, role_id) -- Mencegah duplikasi role pada user yang sama
);

-- --------------------------------------------------------
-- 4. Tabel Reset Token (Untuk Fitur Lupa Password)
-- --------------------------------------------------------
CREATE TABLE password_resets (
    id SERIAL PRIMARY KEY,
    email VARCHAR(150) NOT NULL,
    token VARCHAR(255) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indeks untuk optimalisasi pencarian
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_nomor_induk ON users(nomor_induk);
CREATE INDEX idx_users_status ON users(status);