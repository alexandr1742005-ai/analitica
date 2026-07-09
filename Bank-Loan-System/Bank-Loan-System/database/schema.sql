-- =========================================================
-- Bank Loan System — Database Schema (PostgreSQL 14+)
-- Согласовано с: docs/ER Diagram, docs/Glossary.md (статусные модели)
-- =========================================================

CREATE TYPE user_status AS ENUM ('active', 'blocked', 'pending_verification');

CREATE TYPE application_status AS ENUM (
    'DRAFT',
    'SUBMITTED',
    'IDENTITY_VERIFIED',
    'SCORING_IN_PROGRESS',
    'MANUAL_REVIEW',
    'APPROVED',
    'DECLINED',
    'CONTRACT_SIGNED',
    'DISBURSED',
    'CLOSED'
);

CREATE TYPE loan_status AS ENUM ('ACTIVE', 'OVERDUE', 'CLOSED', 'DEFAULTED');

CREATE TYPE payment_status AS ENUM ('PLANNED', 'PAID', 'OVERDUE', 'DEFAULTED');

CREATE TYPE scoring_decision AS ENUM ('APPROVE', 'DECLINE', 'MANUAL_REVIEW');

CREATE TYPE document_type AS ENUM ('passport_scan', 'income_certificate', 'employment_certificate', 'other');

-- =========================================================
-- Users
-- =========================================================
CREATE TABLE Users (
    id              BIGSERIAL PRIMARY KEY,
    email           VARCHAR(255) NOT NULL UNIQUE,
    phone           VARCHAR(20)  NOT NULL UNIQUE,
    password_hash   VARCHAR(255) NOT NULL,
    full_name       VARCHAR(255) NOT NULL,
    birth_date      DATE NOT NULL,
    status          user_status NOT NULL DEFAULT 'pending_verification',
    created_at      TIMESTAMP NOT NULL DEFAULT now(),
    updated_at      TIMESTAMP NOT NULL DEFAULT now(),

    CONSTRAINT chk_users_birth_date CHECK (birth_date <= now() - INTERVAL '18 years')
);

CREATE INDEX idx_users_email ON Users(email);
CREATE INDEX idx_users_phone ON Users(phone);

-- =========================================================
-- Passports (идентификация клиента, 1:1 с Users в рамках MVP)
-- =========================================================
CREATE TABLE Passports (
    id              BIGSERIAL PRIMARY KEY,
    user_id         BIGINT NOT NULL REFERENCES Users(id) ON DELETE CASCADE,
    series          VARCHAR(10) NOT NULL,
    number          VARCHAR(10) NOT NULL,
    issued_by       VARCHAR(255) NOT NULL,
    issued_date     DATE NOT NULL,
    birth_place     VARCHAR(255) NOT NULL,
    verified        BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMP NOT NULL DEFAULT now(),

    CONSTRAINT uq_passport_series_number UNIQUE (series, number)
);

CREATE INDEX idx_passports_user_id ON Passports(user_id);

-- =========================================================
-- LoanApplications
-- =========================================================
CREATE TABLE LoanApplications (
    id                  BIGSERIAL PRIMARY KEY,
    user_id             BIGINT NOT NULL REFERENCES Users(id) ON DELETE RESTRICT,
    requested_amount    NUMERIC(14,2) NOT NULL,
    term_months         SMALLINT NOT NULL,
    purpose             VARCHAR(500),
    status              application_status NOT NULL DEFAULT 'DRAFT',
    created_at          TIMESTAMP NOT NULL DEFAULT now(),
    updated_at          TIMESTAMP NOT NULL DEFAULT now(),
    decision_date       TIMESTAMP,

    CONSTRAINT chk_loan_amount CHECK (requested_amount BETWEEN 10000 AND 3000000),
    CONSTRAINT chk_loan_term CHECK (term_months BETWEEN 6 AND 60)
);

CREATE INDEX idx_loanapps_user_id ON LoanApplications(user_id);
CREATE INDEX idx_loanapps_status ON LoanApplications(status);
CREATE INDEX idx_loanapps_created_at ON LoanApplications(created_at);

-- =========================================================
-- ScoringResults
-- =========================================================
CREATE TABLE ScoringResults (
    id              BIGSERIAL PRIMARY KEY,
    application_id  BIGINT NOT NULL REFERENCES LoanApplications(id) ON DELETE CASCADE,
    score           SMALLINT NOT NULL,
    decision        scoring_decision NOT NULL,
    model_version   VARCHAR(20) NOT NULL DEFAULT 'v1.0',
    reason_code     VARCHAR(50),
    created_at      TIMESTAMP NOT NULL DEFAULT now(),

    CONSTRAINT chk_score_range CHECK (score BETWEEN 0 AND 999)
);

CREATE INDEX idx_scoring_application_id ON ScoringResults(application_id);

-- =========================================================
-- CreditHistory (эмуляция условного БКИ)
-- =========================================================
CREATE TABLE CreditHistory (
    id              BIGSERIAL PRIMARY KEY,
    user_id         BIGINT NOT NULL REFERENCES Users(id) ON DELETE CASCADE,
    source          VARCHAR(50) NOT NULL DEFAULT 'internal',
    total_loans     INT NOT NULL DEFAULT 0,
    active_loans    INT NOT NULL DEFAULT 0,
    overdue_count   INT NOT NULL DEFAULT 0,
    last_updated    TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_credithistory_user_id ON CreditHistory(user_id);

-- =========================================================
-- Loans
-- =========================================================
CREATE TABLE Loans (
    id                  BIGSERIAL PRIMARY KEY,
    application_id      BIGINT NOT NULL UNIQUE REFERENCES LoanApplications(id) ON DELETE RESTRICT,
    user_id             BIGINT NOT NULL REFERENCES Users(id) ON DELETE RESTRICT,
    principal_amount    NUMERIC(14,2) NOT NULL,
    interest_rate       NUMERIC(5,2) NOT NULL,
    term_months         SMALLINT NOT NULL,
    monthly_payment     NUMERIC(14,2) NOT NULL,
    status              loan_status NOT NULL DEFAULT 'ACTIVE',
    issue_date          DATE NOT NULL DEFAULT CURRENT_DATE,
    contract_number     VARCHAR(50) NOT NULL UNIQUE,

    CONSTRAINT chk_loans_amount CHECK (principal_amount > 0),
    CONSTRAINT chk_loans_rate CHECK (interest_rate > 0)
);

CREATE INDEX idx_loans_user_id ON Loans(user_id);
CREATE INDEX idx_loans_status ON Loans(status);

-- =========================================================
-- Payments
-- =========================================================
CREATE TABLE Payments (
    id              BIGSERIAL PRIMARY KEY,
    loan_id         BIGINT NOT NULL REFERENCES Loans(id) ON DELETE CASCADE,
    due_date        DATE NOT NULL,
    amount          NUMERIC(14,2) NOT NULL,
    paid_date       DATE,
    paid_amount     NUMERIC(14,2),
    status          payment_status NOT NULL DEFAULT 'PLANNED'
);

CREATE INDEX idx_payments_loan_id ON Payments(loan_id);
CREATE INDEX idx_payments_due_date ON Payments(due_date);
CREATE INDEX idx_payments_status ON Payments(status);

-- =========================================================
-- Documents
-- =========================================================
CREATE TABLE Documents (
    id              BIGSERIAL PRIMARY KEY,
    user_id         BIGINT NOT NULL REFERENCES Users(id) ON DELETE CASCADE,
    application_id  BIGINT REFERENCES LoanApplications(id) ON DELETE SET NULL,
    doc_type        document_type NOT NULL,
    file_url        VARCHAR(500) NOT NULL,
    uploaded_at     TIMESTAMP NOT NULL DEFAULT now(),
    verified        BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX idx_documents_user_id ON Documents(user_id);
CREATE INDEX idx_documents_application_id ON Documents(application_id);

-- =========================================================
-- Триггер: автообновление updated_at
-- =========================================================
CREATE OR REPLACE FUNCTION trg_set_updated_at() RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_updated_at_users
    BEFORE UPDATE ON Users
    FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();

CREATE TRIGGER set_updated_at_loanapplications
    BEFORE UPDATE ON LoanApplications
    FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();
