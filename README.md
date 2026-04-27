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

# Key Steps
1- Data cleaning and preprocessing in Python (handling missing values, formatting, and structure correction)
2- Feature engineering in Python to create meaningful variables for analysis and modeling
3- Data querying and validation using SQL for structured analysis and checks
4- Power BI dashboard creation for visualization and business insights
5- Regression model development to analyze credit risk patterns


# 8 Business Questions are ordered by complexity — from foundational risk validation through interaction effects to profitability optimization — mirroring real-world credit risk workflows used by banks and fintech lenders

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
