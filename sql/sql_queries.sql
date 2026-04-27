/* =========================================================
							SETUP 
========================================================= */
CREATE DATABASE IF NOT EXISTS credit_risk_analytics;
USE credit_risk_analytics;

DROP TABLE IF EXISTS loans;

CREATE TABLE loans (
    -- Identifiers
    id VARCHAR(50),
    member_id VARCHAR(50),
    
    -- Loan characteristics
    loan_amnt DECIMAL(10,2),
    funded_amnt DECIMAL(10,2),
    term VARCHAR(20),
    int_rate DECIMAL(5,2),
    installment DECIMAL(10,2),
    grade VARCHAR(5),
    sub_grade VARCHAR(10),
    issue_d VARCHAR(20),
    loan_status VARCHAR(100),
    purpose VARCHAR(50),
    
    -- Borrower demographics
    emp_length VARCHAR(30),
    home_ownership VARCHAR(20),
    annual_inc DECIMAL(12,2),
    verification_status VARCHAR(50),
    
    -- Credit behavior
    dti DECIMAL(6,2),
    delinq_2yrs INT,
    earliest_cr_line VARCHAR(20),
    fico_range_low INT,
    fico_range_high INT,
    inq_last_6mths INT,
    open_acc INT,
    pub_rec INT,
    revol_bal DECIMAL(12,2),
    revol_util DECIMAL(6,2),
    total_acc INT,
    
    -- Performance metrics
    out_prncp DECIMAL(12,2),
    total_pymnt DECIMAL(12,2),
    total_rec_prncp DECIMAL(12,2),
    total_rec_int DECIMAL(12,2),
    recoveries DECIMAL(12,2),
    last_pymnt_d VARCHAR(20),
    last_pymnt_amnt DECIMAL(10,2),
    
    -- Target variable
    default_flag INT,
    
    -- Date conversions
    issue_date DATE,
    earliest_cr_line_date DATE,
    last_pymnt_date DATE,
    term_months INT,
    
    -- Vintage variables
    issue_year INT,
    issue_month INT,
    issue_quarter INT,
    is_recession INT,
    
    -- Credit age
    credit_history_years DECIMAL(6,2),
    credit_age_bin VARCHAR(20),
    
    -- DTI bins
    dti_bin VARCHAR(20),
    
    -- Income brackets
    income_bracket VARCHAR(20),
    
    -- Loan amount bins
    loan_amnt_bin VARCHAR(20),
    
    -- Employment bins
    emp_length_years INT,
    emp_length_bin VARCHAR(20),
    
    -- Delinquency bins
    delinq_bin VARCHAR(10),
    has_delinquency INT,
    has_pub_rec INT,
    
    -- Utilization
    util_category VARCHAR(30),
    
    -- Binary flags
    owns_home INT,
    income_verified INT,
    
    -- Derived metrics
    fico_avg DECIMAL(6,2),
    monthly_income DECIMAL(12,2),
    loan_to_income DECIMAL(8,4),
    payment_to_income_pct DECIMAL(8,2),
    interest_income DECIMAL(12,2),
    lgd DECIMAL(8,4),
    expected_loss DECIMAL(12,2),
    risk_adjusted_return DECIMAL(10,6),
    months_since_issue DECIMAL(8,2),
    months_to_default DECIMAL(8,2)
);
SET sql_mode = '';
USE credit_risk_analytics;

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/loan_data_cleaned_sample.csv'
INTO TABLE loans
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;
SELECT COUNT(*) FROM loans;

/* =========================================================
Q1 — GRADE RISK VALIDATION
Objective:
- Validate risk hierarchy across grades
- Compare default rates vs Grade A benchmark
- Measure portfolio distribution
========================================================= */

WITH grade_stats AS (
    SELECT 
        grade,
        COUNT(*) AS total_loans,
        SUM(default_flag) AS total_defaults,
        ROUND(100.0 * SUM(default_flag) / COUNT(*), 2) AS default_rate_pct,
        ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM loans), 2) AS pct_of_portfolio
    FROM loans
    GROUP BY grade
), 
grade_a_baseline AS (
    SELECT default_rate_pct AS grade_a_rate
    FROM grade_stats
    WHERE grade = 'A'
)
SELECT 
    gs.grade,
    gs.total_loans,
    gs.pct_of_portfolio,
    gs.default_rate_pct,
    ROUND(gs.default_rate_pct / gab.grade_a_rate, 2) AS risk_multiplier_vs_a
FROM grade_stats gs
CROSS JOIN grade_a_baseline gab
ORDER BY gs.grade;

/* =========================================================
Q2 — DTI × INCOME INTERACTION
Objective:
- Identify highest-risk affordability segment
- Detect income-sensitive credit stress zones
========================================================= */

SELECT 
    dti_bin,
    income_bracket,
    COUNT(*) AS loan_count,
    ROUND(100.0 * SUM(default_flag) / COUNT(*), 2) AS default_rate_pct
FROM loans
WHERE dti_bin IS NOT NULL 
  AND income_bracket IS NOT NULL
GROUP BY dti_bin, income_bracket
HAVING COUNT(*) >= 50
ORDER BY default_rate_pct DESC
LIMIT 1;

/* =========================================================
Q3 — VINTAGE PERFORMANCE
Objective:
- Track cohort deterioration over time
- Measure early vs late default cycles
========================================================= */

SELECT
    issue_year,
    COUNT(*) AS total_loans,
    ROUND(100.0 * SUM(CASE WHEN default_flag = 1 AND months_to_default <= 12 THEN 1 ELSE 0 END) / COUNT(*), 2) AS default_rate_12m,
    ROUND(100.0 * SUM(CASE WHEN default_flag = 1 AND months_to_default <= 24 THEN 1 ELSE 0 END) / COUNT(*), 2) AS default_rate_24m,
    ROUND(100.0 * SUM(CASE WHEN default_flag = 1 AND months_to_default <= 36 THEN 1 ELSE 0 END) / COUNT(*), 2) AS default_rate_36m
FROM loans
WHERE issue_year IS NOT NULL
GROUP BY issue_year
ORDER BY issue_year;

/* YoY change in default rate */

SELECT
    issue_year,
    ROUND(100.0 * SUM(default_flag) / COUNT(*), 2) AS default_rate_pct,
    ROUND(
        (100.0 * SUM(default_flag) / COUNT(*)) -
        LAG(100.0 * SUM(default_flag) / COUNT(*)) OVER (ORDER BY issue_year),
    2) AS yoy_change
FROM loans
WHERE issue_year IS NOT NULL
GROUP BY issue_year
ORDER BY issue_year;

/* Default rate by grade and term */

SELECT
    grade,
    term_months,
    COUNT(*) AS total_loans,
    ROUND(100.0 * SUM(default_flag) / COUNT(*), 2) AS default_rate_pct
FROM loans
GROUP BY grade, term_months
HAVING COUNT(*) >= 30
ORDER BY grade, term_months;

/* =========================================================
Q4 — CREDIT QUALITY DRIVERS
Objective:
- FICO segmentation as primary risk anchor
- Utilization penalty across credit maturity
========================================================= */

SELECT
    CASE 
        WHEN fico_avg < 600 THEN 'Poor'
        WHEN fico_avg < 650 THEN 'Fair'
        WHEN fico_avg < 700 THEN 'Good'
        WHEN fico_avg < 750 THEN 'Very Good'
        ELSE 'Excellent'
    END AS fico_tier,
    COUNT(*) AS total_loans,
    ROUND(100.0 * SUM(default_flag) / COUNT(*), 2) AS default_rate_pct
FROM loans
GROUP BY fico_tier
ORDER BY default_rate_pct DESC;

/* Utilization risk amplification across credit age */

SELECT
    credit_age_bin,
    ROUND(MAX(CASE WHEN util_category = 'Low(<30%)' THEN default_rate_pct END), 2) AS rate_low_util,
    ROUND(MAX(CASE WHEN util_category = 'VHigh(75-100%)' THEN default_rate_pct END), 2) AS rate_vhigh_util,
    ROUND(
        MAX(CASE WHEN util_category = 'VHigh(75-100%)' THEN default_rate_pct END) -
        MAX(CASE WHEN util_category = 'Low(<30%)' THEN default_rate_pct END),
    2) AS risk_jump
FROM (
    SELECT
        credit_age_bin,
        util_category,
        ROUND(100.0 * SUM(default_flag) / COUNT(*), 2) AS default_rate_pct
    FROM loans
    WHERE util_category IS NOT NULL AND credit_age_bin IS NOT NULL
    GROUP BY credit_age_bin, util_category
    HAVING COUNT(*) >= 30
) AS base
GROUP BY credit_age_bin
ORDER BY FIELD(credit_age_bin, '0-5y', '5-10y', '10-15y', '15+y');

/* =========================================================
Q5 — LOAN SIZE & PROFITABILITY
Objective:
- Identify size-based risk-return inefficiencies
- Combine EL, PD, LGD, RAR insights
========================================================= */

WITH rar_by_size AS (
    SELECT
        grade,
        loan_amnt_bin,
        ROUND(AVG(risk_adjusted_return) * 100, 2) AS avg_rar_pct,
        COUNT(*) AS total_loans
    FROM loans
    WHERE grade IS NOT NULL AND loan_amnt_bin IS NOT NULL
    GROUP BY grade, loan_amnt_bin
    HAVING COUNT(*) >= 30
)
SELECT
    grade,
    loan_amnt_bin,
    avg_rar_pct,
    ROUND(
        avg_rar_pct - LAG(avg_rar_pct) OVER (
            PARTITION BY grade 
            ORDER BY FIELD(loan_amnt_bin, '<5k', '5-10k', '15-20k', '20-25k', '25-30k', '>30k')
        ),
    2) AS rar_change_vs_prev_bin
FROM rar_by_size
ORDER BY grade;

/* Credit risk components by grade */

SELECT
    grade,
    COUNT(*) AS total_loans,
    ROUND(AVG(default_flag) * 100, 2) AS pd_pct,
    ROUND(AVG(lgd) * 100, 2) AS avg_lgd_pct,
    ROUND(AVG(expected_loss), 2) AS avg_el
FROM loans
GROUP BY grade
ORDER BY grade;

/* =========================================================
Q6 — BORROWER STABILITY FACTORS
Objective:
- Assess employment tenure stability
- Compare ownership vs rental risk
========================================================= */

SELECT
    emp_length_bin,
    COUNT(*) AS total_loans,
    ROUND(100.0 * SUM(default_flag) / COUNT(*), 2) AS default_rate_pct
FROM loans
WHERE emp_length_bin IS NOT NULL
GROUP BY emp_length_bin
ORDER BY FIELD(emp_length_bin, '<2y', '2-5y', '5-10y', '10+y');

SELECT
    home_ownership,
    COUNT(*) AS total_loans,
    ROUND(100.0 * SUM(default_flag) / COUNT(*), 2) AS default_rate_pct
FROM loans
GROUP BY home_ownership;

/* =========================================================
Q7 — CREDIT BEHAVIOR RED FLAGS
Objective:
- Identify behavioral risk signals
- Measure verification effectiveness
========================================================= */

SELECT
    delinq_bin,
    COUNT(*) AS total_loans,
    ROUND(100.0 * SUM(default_flag) / COUNT(*), 2) AS default_rate_pct
FROM loans
WHERE delinq_bin IS NOT NULL
GROUP BY delinq_bin
ORDER BY FIELD(delinq_bin, '0', '1', '2', '3+');

SELECT
    has_pub_rec,
    COUNT(*) AS total_loans,
    ROUND(100.0 * SUM(default_flag) / COUNT(*), 2) AS default_rate_pct
FROM loans
GROUP BY has_pub_rec;

SELECT
    delinq_bin,
    income_verified,
    COUNT(*) AS total_loans,
    ROUND(100.0 * SUM(default_flag) / COUNT(*), 2) AS default_rate_pct
FROM loans
WHERE delinq_bin IS NOT NULL
GROUP BY delinq_bin, income_verified
ORDER BY delinq_bin, income_verified;

SELECT 
    verification_status,
    COUNT(*) AS total,
    ROUND(100.0 * SUM(default_flag) / COUNT(*), 2) AS default_rate
FROM loans
GROUP BY verification_status;

/* =========================================================
Q8 — PURPOSE-BASED RISK DEVIATION
Objective:
- Detect risky vs safe loan purposes per grade
- Compare against expected grade baseline
========================================================= */

WITH purpose_stats AS (
    SELECT
        l.grade,
        l.purpose,
        COUNT(*) AS total_loans,
        ROUND(100.0 * SUM(l.default_flag) / COUNT(*), 2) AS actual_default_rate,
        gb.expected_default_rate,
        ROUND((100.0 * SUM(l.default_flag) / COUNT(*)) - gb.expected_default_rate, 2) AS deviation
    FROM loans l
    JOIN (
        SELECT grade, ROUND(100.0 * SUM(default_flag) / COUNT(*), 2) AS expected_default_rate
        FROM loans
        WHERE grade IS NOT NULL
        GROUP BY grade
    ) gb ON l.grade = gb.grade
    WHERE l.grade IS NOT NULL AND l.purpose IS NOT NULL
    GROUP BY l.grade, l.purpose, gb.expected_default_rate
    HAVING COUNT(*) >= 30
),
ranked AS (
    SELECT *,
        RANK() OVER (PARTITION BY grade ORDER BY deviation DESC) AS risk_rank_high,
        RANK() OVER (PARTITION BY grade ORDER BY deviation ASC) AS risk_rank_low
    FROM purpose_stats
)
SELECT
    grade,
    MAX(CASE WHEN risk_rank_high = 1 THEN purpose END) AS riskiest_purpose,
    MAX(CASE WHEN risk_rank_high = 1 THEN actual_default_rate END) AS riskiest_rate,
    MAX(CASE WHEN risk_rank_low = 1 THEN purpose END) AS safest_purpose,
    MAX(CASE WHEN risk_rank_low = 1 THEN actual_default_rate END) AS safest_rate,
    MAX(expected_default_rate) AS grade_expected_rate
FROM ranked
GROUP BY grade
ORDER BY grade;








