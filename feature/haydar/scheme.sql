-- =====================================================================
-- scheme.sql  |  Web Perpustakaan & Bebas Pustaka
-- DBMS        : PostgreSQL 15+
-- Jalankan    : psql -d nama_db -f scheme.sql
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 0. EXTENSION & ENUM
-- ---------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "pgcrypto";   -- gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS "citext";     -- email case-insensitive
CREATE EXTENSION IF NOT EXISTS "pg_trgm";    -- pencarian judul/penulis

CREATE TYPE user_role        AS ENUM ('mahasiswa', 'pustakawan', 'admin');
CREATE TYPE member_status    AS ENUM ('aktif', 'nonaktif', 'diblokir', 'alumni');
CREATE TYPE item_status      AS ENUM ('tersedia', 'dipinjam', 'dipesan', 'rusak', 'hilang', 'dihapus');
CREATE TYPE item_condition   AS ENUM ('baik', 'cukup', 'rusak_ringan', 'rusak_berat');
CREATE TYPE loan_status      AS ENUM ('dipinjam', 'dikembalikan', 'hilang');
CREATE TYPE fine_type        AS ENUM ('terlambat', 'rusak', 'hilang', 'lainnya');
CREATE TYPE fine_status      AS ENUM ('belum_bayar', 'lunas', 'dibebaskan');
CREATE TYPE payment_method   AS ENUM ('tunai', 'transfer', 'qris', 'lainnya');
CREATE TYPE reservation_status AS ENUM ('menunggu', 'siap_diambil', 'selesai', 'dibatalkan', 'kedaluwarsa');
CREATE TYPE submission_status AS ENUM ('draft', 'diajukan', 'revisi', 'disetujui', 'ditolak');
CREATE TYPE clearance_status AS ENUM ('draft', 'diajukan', 'diverifikasi', 'ditolak', 'disetujui', 'diterbitkan', 'dibatalkan');
CREATE TYPE work_type        AS ENUM ('skripsi', 'tesis', 'disertasi', 'tugas_akhir', 'laporan_pkl', 'jurnal', 'lainnya');

-- ---------------------------------------------------------------------
-- 1. FUNGSI UTILITAS
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------
-- 2. MASTER DATA: FAKULTAS & PRODI
-- ---------------------------------------------------------------------
CREATE TABLE faculties (
  id          SMALLSERIAL PRIMARY KEY,
  code        VARCHAR(10)  NOT NULL UNIQUE,
  name        VARCHAR(150) NOT NULL,
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE study_programs (
  id          SMALLSERIAL PRIMARY KEY,
  faculty_id  SMALLINT     NOT NULL REFERENCES faculties(id) ON DELETE RESTRICT,
  code        VARCHAR(10)  NOT NULL UNIQUE,
  name        VARCHAR(150) NOT NULL,
  degree      VARCHAR(10)  NOT NULL DEFAULT 'S1',   -- D3, S1, S2, S3
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX idx_study_programs_faculty ON study_programs(faculty_id);

-- ---------------------------------------------------------------------
-- 3. USER & ANGGOTA
-- ---------------------------------------------------------------------
CREATE TABLE users (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email          CITEXT       NOT NULL UNIQUE,
  password_hash  TEXT         NOT NULL,
  full_name      VARCHAR(150) NOT NULL,
  role           user_role    NOT NULL DEFAULT 'mahasiswa',
  phone          VARCHAR(20),
  is_active      BOOLEAN      NOT NULL DEFAULT TRUE,
  last_login_at  TIMESTAMPTZ,
  created_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE TRIGGER trg_users_updated BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Anggota perpustakaan (1 user mahasiswa = 1 member)
CREATE TABLE members (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID         NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  member_code       VARCHAR(30)  NOT NULL UNIQUE,          -- barcode kartu anggota
  nim               VARCHAR(30)  NOT NULL UNIQUE,
  study_program_id  SMALLINT     NOT NULL REFERENCES study_programs(id),
  entry_year        SMALLINT     NOT NULL CHECK (entry_year BETWEEN 1990 AND 2100),
  status            member_status NOT NULL DEFAULT 'aktif',
  max_loans         SMALLINT     NOT NULL DEFAULT 3 CHECK (max_loans >= 0),
  registered_at     DATE         NOT NULL DEFAULT CURRENT_DATE,
  expired_at        DATE,
  deactivated_at    TIMESTAMPTZ,                           -- diisi saat bebas pustaka terbit
  created_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX idx_members_prodi  ON members(study_program_id);
CREATE INDEX idx_members_status ON members(status);
CREATE TRIGGER trg_members_updated BEFORE UPDATE ON members
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------
-- 4. KOLEKSI: KATEGORI, JUDUL (BIBLIO), EKSEMPLAR (ITEM)
-- ---------------------------------------------------------------------
CREATE TABLE categories (
  id         SMALLSERIAL PRIMARY KEY,
  name       VARCHAR(100) NOT NULL UNIQUE,
  ddc_code   VARCHAR(20)                                  -- klasifikasi Dewey (opsional)
);

CREATE TABLE books (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  isbn           VARCHAR(20) UNIQUE,
  title          VARCHAR(300) NOT NULL,
  authors        TEXT         NOT NULL,
  publisher      VARCHAR(150),
  publish_year   SMALLINT CHECK (publish_year BETWEEN 1400 AND 2100),
  edition        VARCHAR(50),
  language       VARCHAR(30) DEFAULT 'Indonesia',
  category_id    SMALLINT REFERENCES categories(id) ON DELETE SET NULL,
  call_number    VARCHAR(50),                              -- nomor panggil rak
  description    TEXT,
  cover_url      TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_books_title_trgm   ON books USING gin (title gin_trgm_ops);
CREATE INDEX idx_books_authors_trgm ON books USING gin (authors gin_trgm_ops);
CREATE INDEX idx_books_category     ON books(category_id);
CREATE TRIGGER trg_books_updated BEFORE UPDATE ON books
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE book_items (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  book_id       UUID         NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  barcode       VARCHAR(40)  NOT NULL UNIQUE,              -- label barcode per eksemplar
  status        item_status    NOT NULL DEFAULT 'tersedia',
  condition     item_condition NOT NULL DEFAULT 'baik',
  location      VARCHAR(80),                               -- rak / lantai
  price         NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (price >= 0),  -- dasar denda hilang
  acquired_at   DATE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_book_items_book   ON book_items(book_id);
CREATE INDEX idx_book_items_status ON book_items(status);
CREATE TRIGGER trg_book_items_updated BEFORE UPDATE ON book_items
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------
-- 5. PENGATURAN SISTEM (aturan pinjam, denda, syarat bebas pustaka)
-- ---------------------------------------------------------------------
CREATE TABLE settings (
  key         VARCHAR(60) PRIMARY KEY,
  value       TEXT        NOT NULL,
  description TEXT,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO settings (key, value, description) VALUES
  ('loan_days',                 '7',     'Lama pinjam default (hari)'),
  ('max_renewals',              '2',     'Maksimal perpanjangan per peminjaman'),
  ('fine_per_day',              '1000',  'Denda keterlambatan per hari per buku (Rp)'),
  ('fine_max_multiplier',       '1',     'Batas denda terlambat = harga buku x nilai ini'),
  ('lost_fine_multiplier',      '2',     'Denda buku hilang = harga buku x nilai ini'),
  ('reservation_hold_days',     '2',     'Lama buku pesanan ditahan (hari)'),
  ('clearance_require_thesis',  'true',  'Bebas pustaka wajib unggah karya akhir ke repositori'),
  ('clearance_letter_prefix',   'BP',    'Prefix nomor surat bebas pustaka'),
  ('clearance_validity_days',   '180',   'Masa berlaku surat bebas pustaka (hari)');

-- ---------------------------------------------------------------------
-- 6. SIRKULASI: PEMINJAMAN & RESERVASI
-- ---------------------------------------------------------------------
CREATE TABLE loans (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id       UUID        NOT NULL REFERENCES members(id)    ON DELETE RESTRICT,
  item_id         UUID        NOT NULL REFERENCES book_items(id) ON DELETE RESTRICT,
  loaned_by       UUID        REFERENCES users(id),             -- petugas
  returned_to     UUID        REFERENCES users(id),
  loan_date       DATE        NOT NULL DEFAULT CURRENT_DATE,
  due_date        DATE        NOT NULL,
  return_date     DATE,
  renew_count     SMALLINT    NOT NULL DEFAULT 0 CHECK (renew_count >= 0),
  status          loan_status NOT NULL DEFAULT 'dipinjam',
  notes           TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (due_date >= loan_date),
  CHECK (return_date IS NULL OR return_date >= loan_date)
);
CREATE INDEX idx_loans_member ON loans(member_id);
CREATE INDEX idx_loans_item   ON loans(item_id);
CREATE INDEX idx_loans_status ON loans(status);
CREATE INDEX idx_loans_due    ON loans(due_date) WHERE status = 'dipinjam';
-- 1 eksemplar hanya boleh punya 1 peminjaman aktif
CREATE UNIQUE INDEX uq_loans_item_active ON loans(item_id) WHERE status = 'dipinjam';
CREATE TRIGGER trg_loans_updated BEFORE UPDATE ON loans
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE reservations (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id    UUID        NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  book_id      UUID        NOT NULL REFERENCES books(id)   ON DELETE CASCADE,
  item_id      UUID        REFERENCES book_items(id),        -- terisi saat siap diambil
  status       reservation_status NOT NULL DEFAULT 'menunggu',
  reserved_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  ready_at     TIMESTAMPTZ,
  expires_at   TIMESTAMPTZ,
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_reservations_member ON reservations(member_id);
CREATE INDEX idx_reservations_book   ON reservations(book_id, status);
CREATE UNIQUE INDEX uq_reservation_active ON reservations(member_id, book_id)
  WHERE status IN ('menunggu', 'siap_diambil');
CREATE TRIGGER trg_reservations_updated BEFORE UPDATE ON reservations
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------
-- 7. DENDA & PEMBAYARAN
-- ---------------------------------------------------------------------
CREATE TABLE fines (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id     UUID        NOT NULL REFERENCES members(id) ON DELETE RESTRICT,
  loan_id       UUID        REFERENCES loans(id) ON DELETE SET NULL,
  type          fine_type   NOT NULL,
  amount        NUMERIC(12,2) NOT NULL CHECK (amount >= 0),
  paid_amount   NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (paid_amount >= 0),
  status        fine_status NOT NULL DEFAULT 'belum_bayar',
  reason        TEXT,
  waived_by     UUID        REFERENCES users(id),             -- admin yang membebaskan
  waived_reason TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (paid_amount <= amount)
);
CREATE INDEX idx_fines_member ON fines(member_id);
CREATE INDEX idx_fines_status ON fines(status);
CREATE TRIGGER trg_fines_updated BEFORE UPDATE ON fines
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE fine_payments (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fine_id     UUID           NOT NULL REFERENCES fines(id) ON DELETE RESTRICT,
  amount      NUMERIC(12,2)  NOT NULL CHECK (amount > 0),
  method      payment_method NOT NULL DEFAULT 'tunai',
  reference   VARCHAR(100),                                  -- no. transfer / bukti
  received_by UUID           REFERENCES users(id),
  paid_at     TIMESTAMPTZ    NOT NULL DEFAULT now()
);
CREATE INDEX idx_fine_payments_fine ON fine_payments(fine_id);

-- Trigger: update paid_amount & status denda setelah pembayaran
CREATE OR REPLACE FUNCTION trg_after_fine_payment() RETURNS trigger AS $$
DECLARE
  v_total NUMERIC(12,2);
  v_amount NUMERIC(12,2);
BEGIN
  SELECT COALESCE(SUM(amount), 0) INTO v_total FROM fine_payments WHERE fine_id = NEW.fine_id;
  SELECT amount INTO v_amount FROM fines WHERE id = NEW.fine_id;

  IF v_total > v_amount THEN
    RAISE EXCEPTION 'Total pembayaran (%) melebihi nominal denda (%)', v_total, v_amount;
  END IF;

  UPDATE fines
     SET paid_amount = v_total,
         status = CASE WHEN v_total >= v_amount THEN 'lunas'::fine_status ELSE status END
   WHERE id = NEW.fine_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_fine_payments_after AFTER INSERT ON fine_payments
  FOR EACH ROW EXECUTE FUNCTION trg_after_fine_payment();

-- ---------------------------------------------------------------------
-- 8. LOGIKA SIRKULASI (validasi pinjam, sinkron status item, hitung denda)
-- ---------------------------------------------------------------------

-- 8a. Validasi sebelum pinjam
CREATE OR REPLACE FUNCTION trg_before_loan_insert() RETURNS trigger AS $$
DECLARE
  v_status      member_status;
  v_max         SMALLINT;
  v_active      INT;
  v_unpaid      NUMERIC(12,2);
  v_item_status item_status;
BEGIN
  SELECT status, max_loans INTO v_status, v_max FROM members WHERE id = NEW.member_id;
  IF v_status <> 'aktif' THEN
    RAISE EXCEPTION 'Anggota tidak aktif (status: %)', v_status;
  END IF;

  SELECT COUNT(*) INTO v_active FROM loans
   WHERE member_id = NEW.member_id AND status = 'dipinjam';
  IF v_active >= v_max THEN
    RAISE EXCEPTION 'Batas pinjam tercapai (% buku)', v_max;
  END IF;

  SELECT COALESCE(SUM(amount - paid_amount), 0) INTO v_unpaid FROM fines
   WHERE member_id = NEW.member_id AND status = 'belum_bayar';
  IF v_unpaid > 0 THEN
    RAISE EXCEPTION 'Masih ada denda belum dibayar: Rp%', v_unpaid;
  END IF;

  SELECT status INTO v_item_status FROM book_items WHERE id = NEW.item_id;
  IF v_item_status NOT IN ('tersedia', 'dipesan') THEN
    RAISE EXCEPTION 'Eksemplar tidak tersedia (status: %)', v_item_status;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_loans_before_insert BEFORE INSERT ON loans
  FOR EACH ROW EXECUTE FUNCTION trg_before_loan_insert();

-- 8b. Sinkron status eksemplar setelah pinjam / kembali / hilang
CREATE OR REPLACE FUNCTION trg_after_loan_change() RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE book_items SET status = 'dipinjam' WHERE id = NEW.item_id;
  ELSIF TG_OP = 'UPDATE' AND OLD.status = 'dipinjam' THEN
    IF NEW.status = 'dikembalikan' THEN
      UPDATE book_items SET status = 'tersedia' WHERE id = NEW.item_id AND status = 'dipinjam';
    ELSIF NEW.status = 'hilang' THEN
      UPDATE book_items SET status = 'hilang' WHERE id = NEW.item_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_loans_after_change AFTER INSERT OR UPDATE ON loans
  FOR EACH ROW EXECUTE FUNCTION trg_after_loan_change();

-- 8c. Hitung denda otomatis saat buku dikembalikan / dinyatakan hilang
CREATE OR REPLACE FUNCTION trg_loan_generate_fine() RETURNS trigger AS $$
DECLARE
  v_per_day   NUMERIC := (SELECT value::NUMERIC FROM settings WHERE key = 'fine_per_day');
  v_cap_mult  NUMERIC := (SELECT value::NUMERIC FROM settings WHERE key = 'fine_max_multiplier');
  v_lost_mult NUMERIC := (SELECT value::NUMERIC FROM settings WHERE key = 'lost_fine_multiplier');
  v_price     NUMERIC(12,2);
  v_late_days INT;
  v_amount    NUMERIC(12,2);
BEGIN
  IF OLD.status = 'dipinjam' AND NEW.status = 'dikembalikan' THEN
    NEW.return_date := COALESCE(NEW.return_date, CURRENT_DATE);
    v_late_days := GREATEST(NEW.return_date - NEW.due_date, 0);
    IF v_late_days > 0 THEN
      SELECT price INTO v_price FROM book_items WHERE id = NEW.item_id;
      v_amount := v_late_days * v_per_day;
      IF v_price > 0 THEN
        v_amount := LEAST(v_amount, v_price * v_cap_mult);   -- plafon denda
      END IF;
      INSERT INTO fines (member_id, loan_id, type, amount, reason)
      VALUES (NEW.member_id, NEW.id, 'terlambat', v_amount,
              format('Terlambat %s hari', v_late_days));
    END IF;

  ELSIF OLD.status = 'dipinjam' AND NEW.status = 'hilang' THEN
    SELECT price INTO v_price FROM book_items WHERE id = NEW.item_id;
    IF v_price > 0 THEN
      INSERT INTO fines (member_id, loan_id, type, amount, reason)
      VALUES (NEW.member_id, NEW.id, 'hilang', v_price * v_lost_mult, 'Buku dinyatakan hilang');
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_loans_generate_fine BEFORE UPDATE ON loans
  FOR EACH ROW EXECUTE FUNCTION trg_loan_generate_fine();

-- ---------------------------------------------------------------------
-- 9. REPOSITORI KARYA AKHIR (syarat umum bebas pustaka)
-- ---------------------------------------------------------------------
CREATE TABLE thesis_submissions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id       UUID        NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  work_type       work_type   NOT NULL DEFAULT 'skripsi',
  title           VARCHAR(400) NOT NULL,
  abstract        TEXT,
  advisor_1       VARCHAR(150),
  advisor_2       VARCHAR(150),
  defense_year    SMALLINT,
  file_full_url   TEXT,                                      -- PDF lengkap
  file_cover_url  TEXT,
  similarity_pct  NUMERIC(5,2) CHECK (similarity_pct BETWEEN 0 AND 100),
  similarity_url  TEXT,                                      -- bukti uji kemiripan
  status          submission_status NOT NULL DEFAULT 'draft',
  reviewed_by     UUID        REFERENCES users(id),
  review_notes    TEXT,
  submitted_at    TIMESTAMPTZ,
  reviewed_at     TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_thesis_member ON thesis_submissions(member_id);
CREATE INDEX idx_thesis_status ON thesis_submissions(status);
CREATE TRIGGER trg_thesis_updated BEFORE UPDATE ON thesis_submissions
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------
-- 10. BEBAS PUSTAKA
-- ---------------------------------------------------------------------
CREATE SEQUENCE clearance_letter_seq START 1;

CREATE TABLE clearance_requests (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id       UUID             NOT NULL REFERENCES members(id) ON DELETE RESTRICT,
  purpose         VARCHAR(60)      NOT NULL DEFAULT 'yudisium',  -- yudisium / wisuda / cuti / pindah / lainnya
  thesis_id       UUID             REFERENCES thesis_submissions(id),
  status          clearance_status NOT NULL DEFAULT 'draft',
  -- snapshot hasil pengecekan otomatis saat diajukan
  chk_no_loans    BOOLEAN,
  chk_no_fines    BOOLEAN,
  chk_thesis_ok   BOOLEAN,
  verified_by     UUID             REFERENCES users(id),
  verified_at     TIMESTAMPTZ,
  reject_reason   TEXT,
  submitted_at    TIMESTAMPTZ,
  created_at      TIMESTAMPTZ      NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ      NOT NULL DEFAULT now()
);
CREATE INDEX idx_clearance_member ON clearance_requests(member_id);
CREATE INDEX idx_clearance_status ON clearance_requests(status);
-- 1 anggota hanya boleh punya 1 pengajuan yang masih berjalan
CREATE UNIQUE INDEX uq_clearance_active ON clearance_requests(member_id)
  WHERE status IN ('draft', 'diajukan', 'diverifikasi', 'disetujui');
CREATE TRIGGER trg_clearance_updated BEFORE UPDATE ON clearance_requests
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Riwayat perubahan status pengajuan
CREATE TABLE clearance_status_history (
  id          BIGSERIAL PRIMARY KEY,
  request_id  UUID             NOT NULL REFERENCES clearance_requests(id) ON DELETE CASCADE,
  from_status clearance_status,
  to_status   clearance_status NOT NULL,
  changed_by  UUID             REFERENCES users(id),
  note        TEXT,
  changed_at  TIMESTAMPTZ      NOT NULL DEFAULT now()
);
CREATE INDEX idx_clearance_history_req ON clearance_status_history(request_id);

CREATE OR REPLACE FUNCTION trg_clearance_log_status() RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'INSERT' OR NEW.status IS DISTINCT FROM OLD.status THEN
    INSERT INTO clearance_status_history (request_id, from_status, to_status, changed_by)
    VALUES (NEW.id,
            CASE WHEN TG_OP = 'UPDATE' THEN OLD.status END,
            NEW.status,
            NEW.verified_by);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_clearance_history AFTER INSERT OR UPDATE ON clearance_requests
  FOR EACH ROW EXECUTE FUNCTION trg_clearance_log_status();

-- Surat bebas pustaka yang diterbitkan
CREATE TABLE clearance_letters (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id    UUID        NOT NULL UNIQUE REFERENCES clearance_requests(id) ON DELETE RESTRICT,
  letter_number VARCHAR(60) NOT NULL UNIQUE,
  issued_at     DATE        NOT NULL DEFAULT CURRENT_DATE,
  valid_until   DATE,
  signed_by     UUID        REFERENCES users(id),
  verify_token  VARCHAR(64) NOT NULL UNIQUE DEFAULT encode(gen_random_bytes(24), 'hex'),  -- untuk QR cek keaslian
  pdf_url       TEXT,
  is_revoked    BOOLEAN     NOT NULL DEFAULT FALSE,
  revoked_reason TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 10a. Cek kelayakan bebas pustaka (dipakai backend sebelum pengajuan / verifikasi)
CREATE OR REPLACE FUNCTION fn_clearance_eligibility(p_member UUID)
RETURNS TABLE (
  active_loans  INT,
  unpaid_fines  NUMERIC(12,2),
  thesis_ok     BOOLEAN,
  is_eligible   BOOLEAN
) AS $$
DECLARE
  v_need_thesis BOOLEAN := (SELECT value::BOOLEAN FROM settings WHERE key = 'clearance_require_thesis');
BEGIN
  RETURN QUERY
  WITH l AS (
    SELECT COUNT(*)::INT AS n FROM loans
     WHERE member_id = p_member AND status = 'dipinjam'
  ), f AS (
    SELECT COALESCE(SUM(amount - paid_amount), 0)::NUMERIC(12,2) AS s FROM fines
     WHERE member_id = p_member AND status = 'belum_bayar'
  ), t AS (
    SELECT EXISTS (SELECT 1 FROM thesis_submissions
                    WHERE member_id = p_member AND status = 'disetujui') AS ok
  )
  SELECT l.n, f.s,
         (NOT v_need_thesis) OR t.ok,
         (l.n = 0 AND f.s = 0 AND ((NOT v_need_thesis) OR t.ok))
  FROM l, f, t;
END;
$$ LANGUAGE plpgsql STABLE;

-- 10b. Terbitkan surat: validasi ulang, buat nomor, nonaktifkan keanggotaan
CREATE OR REPLACE FUNCTION fn_issue_clearance_letter(p_request UUID, p_signer UUID)
RETURNS UUID AS $$
DECLARE
  v_member   UUID;
  v_status   clearance_status;
  v_ok       BOOLEAN;
  v_prefix   TEXT := (SELECT value FROM settings WHERE key = 'clearance_letter_prefix');
  v_valid    INT  := (SELECT value::INT FROM settings WHERE key = 'clearance_validity_days');
  v_number   TEXT;
  v_letter   UUID;
BEGIN
  SELECT member_id, status INTO v_member, v_status
    FROM clearance_requests WHERE id = p_request FOR UPDATE;

  IF v_status IS NULL THEN
    RAISE EXCEPTION 'Pengajuan tidak ditemukan';
  END IF;
  IF v_status <> 'disetujui' THEN
    RAISE EXCEPTION 'Pengajuan belum disetujui (status: %)', v_status;
  END IF;

  SELECT is_eligible INTO v_ok FROM fn_clearance_eligibility(v_member);
  IF NOT v_ok THEN
    RAISE EXCEPTION 'Anggota belum memenuhi syarat bebas pustaka';
  END IF;

  v_number := format('%s/%s/PERPUS/%s/%s',
                     lpad(nextval('clearance_letter_seq')::TEXT, 4, '0'),
                     v_prefix,
                     to_char(CURRENT_DATE, 'MM'),
                     to_char(CURRENT_DATE, 'YYYY'));

  INSERT INTO clearance_letters (request_id, letter_number, valid_until, signed_by)
  VALUES (p_request, v_number, CURRENT_DATE + v_valid, p_signer)
  RETURNING id INTO v_letter;

  UPDATE clearance_requests SET status = 'diterbitkan', verified_by = p_signer WHERE id = p_request;
  UPDATE members SET status = 'alumni', deactivated_at = now() WHERE id = v_member;

  RETURN v_letter;
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------
-- 11. NOTIFIKASI & AUDIT
-- ---------------------------------------------------------------------
CREATE TABLE notifications (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title       VARCHAR(150) NOT NULL,
  body        TEXT,
  link        TEXT,
  is_read     BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_notifications_user ON notifications(user_id, is_read);

CREATE TABLE audit_logs (
  id          BIGSERIAL PRIMARY KEY,
  user_id     UUID        REFERENCES users(id) ON DELETE SET NULL,
  action      VARCHAR(60) NOT NULL,                          -- contoh: LOAN_CREATE, FINE_WAIVE
  entity      VARCHAR(60) NOT NULL,
  entity_id   TEXT,
  detail      JSONB,
  ip_address  INET,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_audit_entity ON audit_logs(entity, entity_id);
CREATE INDEX idx_audit_user   ON audit_logs(user_id);

-- ---------------------------------------------------------------------
-- 12. VIEW
-- ---------------------------------------------------------------------
-- Peminjaman aktif + status keterlambatan
CREATE OR REPLACE VIEW v_active_loans AS
SELECT l.id, l.member_id, m.nim, u.full_name, b.title, bi.barcode,
       l.loan_date, l.due_date,
       GREATEST(CURRENT_DATE - l.due_date, 0) AS days_late,
       (CURRENT_DATE > l.due_date)            AS is_overdue
FROM loans l
JOIN members    m  ON m.id  = l.member_id
JOIN users      u  ON u.id  = m.user_id
JOIN book_items bi ON bi.id = l.item_id
JOIN books      b  ON b.id  = bi.book_id
WHERE l.status = 'dipinjam';

-- Ringkasan tanggungan per anggota (dipakai halaman bebas pustaka)
CREATE OR REPLACE VIEW v_member_obligations AS
SELECT m.id AS member_id, m.nim, u.full_name,
       COALESCE(l.n, 0)  AS active_loans,
       COALESCE(f.s, 0)  AS unpaid_fines
FROM members m
JOIN users u ON u.id = m.user_id
LEFT JOIN (SELECT member_id, COUNT(*) n FROM loans WHERE status = 'dipinjam' GROUP BY member_id) l
       ON l.member_id = m.id
LEFT JOIN (SELECT member_id, SUM(amount - paid_amount) s FROM fines WHERE status = 'belum_bayar' GROUP BY member_id) f
       ON f.member_id = m.id;

-- Ketersediaan buku
CREATE OR REPLACE VIEW v_book_availability AS
SELECT b.id AS book_id, b.title, b.authors,
       COUNT(bi.id)                                          AS total_items,
       COUNT(bi.id) FILTER (WHERE bi.status = 'tersedia')    AS available_items
FROM books b
LEFT JOIN book_items bi ON bi.book_id = b.id AND bi.status <> 'dihapus'
GROUP BY b.id, b.title, b.authors;

-- ---------------------------------------------------------------------
-- 13. SEED MINIMAL
-- ---------------------------------------------------------------------
INSERT INTO categories (name, ddc_code) VALUES
  ('Karya Umum', '000'), ('Teknologi & Komputer', '004'),
  ('Ilmu Sosial', '300'), ('Sains', '500'), ('Teknik', '600'), ('Bahasa', '400');

COMMIT;