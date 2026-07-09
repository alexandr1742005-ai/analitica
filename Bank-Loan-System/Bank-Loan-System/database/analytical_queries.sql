-- =========================================================
-- Bank Loan System — Analytical Queries
-- Совместимо с PostgreSQL 14+
-- =========================================================

-- ---------------------------------------------------------
-- 1. Количество выданных кредитов (по статусу заявки DISBURSED)
-- ---------------------------------------------------------
SELECT COUNT(*) AS total_disbursed_loans
FROM Loans
WHERE status IN ('ACTIVE', 'OVERDUE', 'CLOSED', 'DEFAULTED');

-- ---------------------------------------------------------
-- 2. Средний размер кредита
-- ---------------------------------------------------------
SELECT ROUND(AVG(principal_amount), 2) AS avg_loan_amount
FROM Loans;

-- ---------------------------------------------------------
-- 3. Процент отказов (доля заявок со статусом DECLINED от всех рассмотренных)
-- ---------------------------------------------------------
SELECT
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE status = 'DECLINED')
        / NULLIF(COUNT(*) FILTER (WHERE status NOT IN ('DRAFT', 'SUBMITTED', 'SCORING_IN_PROGRESS')), 0),
        2
    ) AS decline_rate_percent
FROM LoanApplications;

-- ---------------------------------------------------------
-- 4. Среднее время рассмотрения заявки (от подачи до решения), в часах
-- ---------------------------------------------------------
SELECT
    ROUND(AVG(EXTRACT(EPOCH FROM (decision_date - created_at)) / 3600.0), 2) AS avg_review_time_hours
FROM LoanApplications
WHERE decision_date IS NOT NULL;

-- ---------------------------------------------------------
-- 5. Клиенты с текущей просрочкой (по кредитам и платежам)
-- ---------------------------------------------------------
SELECT
    u.id AS user_id,
    u.full_name,
    l.id AS loan_id,
    l.contract_number,
    l.status AS loan_status,
    COUNT(p.id) FILTER (WHERE p.status = 'OVERDUE') AS overdue_payments_count,
    SUM(p.amount) FILTER (WHERE p.status = 'OVERDUE') AS overdue_amount
FROM Users u
JOIN Loans l ON l.user_id = u.id
JOIN Payments p ON p.loan_id = l.id
WHERE l.status = 'OVERDUE'
GROUP BY u.id, u.full_name, l.id, l.contract_number, l.status
ORDER BY overdue_amount DESC;

-- ---------------------------------------------------------
-- 6. Топ-10 клиентов по суммарному объёму выданных кредитов
-- ---------------------------------------------------------
SELECT
    u.id AS user_id,
    u.full_name,
    COUNT(l.id) AS loans_count,
    SUM(l.principal_amount) AS total_loan_amount
FROM Users u
JOIN Loans l ON l.user_id = u.id
GROUP BY u.id, u.full_name
ORDER BY total_loan_amount DESC
LIMIT 10;

-- ---------------------------------------------------------
-- 7. Количество и сумма выданных кредитов по месяцам
-- ---------------------------------------------------------
SELECT
    DATE_TRUNC('month', issue_date) AS month,
    COUNT(*) AS loans_count,
    SUM(principal_amount) AS total_amount
FROM Loans
GROUP BY DATE_TRUNC('month', issue_date)
ORDER BY month;

-- ---------------------------------------------------------
-- 8. Средний возраст заёмщиков (на момент подачи заявки)
-- ---------------------------------------------------------
SELECT
    ROUND(AVG(DATE_PART('year', AGE(la.created_at::date, u.birth_date))), 1) AS avg_borrower_age
FROM LoanApplications la
JOIN Users u ON u.id = la.user_id
WHERE la.status IN ('APPROVED', 'CONTRACT_SIGNED', 'DISBURSED', 'CLOSED');

-- ---------------------------------------------------------
-- Дополнительно: распределение решений скоринга
-- ---------------------------------------------------------
SELECT
    decision,
    COUNT(*) AS applications_count,
    ROUND(AVG(score), 1) AS avg_score
FROM ScoringResults
GROUP BY decision
ORDER BY decision;

-- ---------------------------------------------------------
-- Дополнительно: конверсия воронки (заявка → выдача)
-- ---------------------------------------------------------
SELECT
    COUNT(*) AS total_applications,
    COUNT(*) FILTER (WHERE status = 'DISBURSED') AS disbursed,
    ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'DISBURSED') / NULLIF(COUNT(*), 0), 2) AS conversion_percent
FROM LoanApplications;
