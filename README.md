                                                      # Credit Risk Analytics — LendingClub Portfolio 2007–2018 #
A full-stack credit risk analysis project structured around 8 business questions — covering data engineering, SQL analytics, Power BI dashboarding, and predictive modeling.

# Tech Stack :Python MySQL Power BI scikit-learn

# Repository Structure
credit-risk-analytics/
├── dashboard/        # Power BI interactive dashboard
├── data/             # Cleaned analytical sample (30,329 records)
├── python/           # Feature engineering + logistic regression model
├── sql/              # All 8 business question queries & KPI computations
└── docs/             # Insights report (20 pages) + analytical framework (5 pages)

# 8 Business Questions

#      Question                                           Complexity
Q1     Loan Grade Distribution & Default Rates            Foundational
Q2     Default Risk by DTI × Income Level                 Foundational
Q3     Vintage Analysis & Loan Term Risk                  Intermediate
Q4     FICO Score, Credit Utilization × Credit Age        Intermediate
Q5     Loan Size Optimization, Expected Loss & RAR        Intermediate
Q6     Employment Length & Home Ownership                 Advanced
Q7     Delinquency, Public Records & Income Verification  Advanced
Q8     Loan Purpose Risk Anomalies Within Grades          Advanced

# Key Findings

+ Grade A is the only value-generating segment (+0.57% RAR) — Grades D–G produce losses between -13% and -22%
+ FICO score is the strongest default predictor (model coefficient: -0.221)
+ DTI >40% + income <$50K produces a 34.94% default rate — the portfolio's highest-risk intersection
+ 60-month loans carry a 10–15% default rate premium over 36-month equivalents
+ Small business loans default at 29.19% regardless of grade — standard scoring fails this segment
+ Verification paradox — verified borrowers default at higher rates due to adverse selection in the trigger


# Predictive Model
Logistic Regression trained on 9 origination-time features with balanced class weights.

Metric                                 Value
AUC-ROC                                0.6845
Default Recall                         60%
Default Precision                      33%

# Author
Menyare Zitouni — Finance Major, IT Minor @ Tunis Business School
menyare.zitouni12@gmail.com
