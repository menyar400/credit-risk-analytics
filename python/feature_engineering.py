import pandas as pd
import numpy as np

# STEP 1: LOAD AND SAMPLE DATA
print("Loading data...")

SAMPLE_SIZE = 50000 

df_full = pd.read_csv('accepted_2007_to_2018Q4.csv', low_memory=False)
df_sample = df_full.sample(n=SAMPLE_SIZE, random_state=42)
del df_full  

print(f"✓ Sampled {len(df_sample):,} loans from original dataset")

# STEP 2: SELECT REQUIRED COLUMNS ONLY

# Columns needed for the 8 questions
required_columns = [
    # Identifiers
    'id',
    'member_id',
    
    # Loan characteristics (Q1, Q5, Q8)
    'loan_amnt',
    'funded_amnt',
    'term',                    
    'int_rate',              
    'installment',
    'grade',                 
    'sub_grade',
    'issue_d',                
    'loan_status',            
    'purpose',                
    
    # Borrower demographics (Q2, Q6, Q7)
    'emp_length',             
    'home_ownership',
    'annual_inc',             
    'verification_status',    
    
    # Credit behavior (Q2, Q4, Q7)
    'dti',                    
    'delinq_2yrs',           
    'earliest_cr_line',       
    'fico_range_low',
    'fico_range_high',
    'inq_last_6mths',
    'open_acc',
    'pub_rec',
    'revol_bal',
    'revol_util',             
    'total_acc',
    
    # Performance metrics (for calculating KPIs)
    'out_prncp',
    'total_pymnt',
    'total_rec_prncp',
    'total_rec_int',
    'recoveries',            
    'last_pymnt_d',
    'last_pymnt_amnt'
]

required_columns = [col for col in required_columns if col in df_sample.columns]
df_clean = df_sample[required_columns].copy()

print(f" Reduced from {df_sample.shape[1]} to {len(required_columns)} columns")
del df_sample  

#STEP 3: CREATE TARGET VARIABLE (Binary: Default = 1)

def create_default_flag(status):
    """
    Convert loan status to binary outcome:
    1 = Default/Bad (Charged Off, Default, Late)
    0 = Good (Fully Paid)
    NaN = Exclude (Current, In Grace Period - not finalized)
    """
    if pd.isna(status):
        return np.nan
    
    # Good outcomes
    good_statuses = ['Fully Paid']
    
    # Bad outcomes (default)
    default_statuses = [
        'Charged Off',
        'Default',
        'Does not meet the credit policy. Status:Charged Off',
        'Late (31-120 days)',
        'Late (16-30 days)'
    ]
    
    if status in good_statuses:
        return 0
    elif status in default_statuses:
        return 1
    else:
        return np.nan  # Exclude ongoing loans

df_clean['default_flag'] = df_clean['loan_status'].apply(create_default_flag)

# Keep only finalized loans (exclude Current/In Grace Period)
df_clean = df_clean[df_clean['default_flag'].notna()].copy()
df_clean['default_flag'] = df_clean['default_flag'].astype(int)

# STEP 4: DATA TYPE CONVERSIONS

# Convert percentages to floats 
if df_clean['int_rate'].dtype == 'object':  # If it's text
    df_clean['int_rate'] = df_clean['int_rate'].str.replace('%', '').astype(float)
else:  # If it's already numeric
    df_clean['int_rate'] = df_clean['int_rate'].astype(float)

# Same for revol_util
if 'revol_util' in df_clean.columns:
    if df_clean['revol_util'].dtype == 'object':  # If it's text
        df_clean['revol_util'] = df_clean['revol_util'].str.replace('%', '')
        df_clean['revol_util'] = pd.to_numeric(df_clean['revol_util'], errors='coerce')
    else:  # Already numeric
        df_clean['revol_util'] = pd.to_numeric(df_clean['revol_util'], errors='coerce')

# Convert term to months (numeric) 
if df_clean['term'].dtype == 'object':
    df_clean['term_months'] = df_clean['term'].str.extract(r'(\d+)').astype(float)
else:
    df_clean['term_months'] = df_clean['term']

# Convert dates 
df_clean['issue_date'] = pd.to_datetime(df_clean['issue_d'], format='%b-%Y', errors='coerce')
df_clean['earliest_cr_line_date'] = pd.to_datetime(df_clean['earliest_cr_line'], format='%b-%Y', errors='coerce')
df_clean['last_pymnt_date'] = pd.to_datetime(df_clean['last_pymnt_d'], format='%b-%Y', errors='coerce')

print("✓ Data types converted")

# STEP 5: CREATE BINARY & CATEGORICAL VARIABLES

# --- Q3: Vintage Year ---
df_clean['issue_year'] = df_clean['issue_date'].dt.year
df_clean['issue_month'] = df_clean['issue_date'].dt.month
df_clean['issue_quarter'] = df_clean['issue_date'].dt.quarter

# Recession period flag (for Q6)
df_clean['is_recession'] = df_clean['issue_year'].isin([2008, 2009, 2020]).astype(int)

# --- Q4: Credit History Length (years) ---
df_clean['credit_history_years'] = (
    (df_clean['issue_date'] - df_clean['earliest_cr_line_date']).dt.days / 365.25
)

# Credit age bins for Q4
df_clean['credit_age_bin'] = pd.cut(
    df_clean['credit_history_years'],
    bins=[0, 5, 10, 15, 100],
    labels=['0-5y', '5-10y', '10-15y', '15+y']
)

# --- Q2: DTI Bins ---
df_clean['dti_bin'] = pd.cut(
    df_clean['dti'],
    bins=[0, 20, 30, 40, 100],
    labels=['<20%', '20-30%', '30-40%', '>40%']
)

# --- Q2: Income Brackets ---
df_clean['income_bracket'] = pd.cut(
    df_clean['annual_inc'],
    bins=[0, 50000, 100000, 150000, np.inf],
    labels=['<50k', '50-100k', '100-150k', '>150k']
)

# --- Q5: Loan Amount Bins (by $5k increments) ---
df_clean['loan_amnt_bin'] = pd.cut(
    df_clean['loan_amnt'],
    bins=[0, 5000, 10000, 15000, 20000, 25000, 30000, np.inf],
    labels=['<5k', '5-10k', '10-15k', '15-20k', '20-25k', '25-30k', '>30k']
)

# --- Q6: Employment Length Bins ---
def parse_emp_length(emp):
    if pd.isna(emp):
        return np.nan
    emp = str(emp).lower()
    if '< 1' in emp:
        return 0
    if '10+' in emp:
        return 10
    import re
    match = re.search(r'(\d+)', emp)
    if match:
        return int(match.group(1))
    return np.nan

df_clean['emp_length_years'] = df_clean['emp_length'].apply(parse_emp_length)

# Fill missing emp_length_years 
df_clean['emp_length_years'] = df_clean['emp_length_years'].fillna(
    df_clean['emp_length_years'].median()
)

df_clean['emp_length_bin'] = pd.cut(
    df_clean['emp_length_years'],
    bins=[-1, 2, 5, 10, 100],
    labels=['<2y', '2-5y', '5-10y', '10+y']
)

# --- Q7: Delinquency Bins ---
df_clean['delinq_bin'] = pd.cut(
    df_clean['delinq_2yrs'],
    bins=[-1, 0, 1, 2, 100],
    labels=['0', '1', '2', '3+'],
    right=True
)

# Binary: Has delinquency
df_clean['has_delinquency'] = (df_clean['delinq_2yrs'] > 0).astype(int)

# Binary: Has public records
df_clean['has_pub_rec'] = (df_clean['pub_rec'] > 0).astype(int)

# --- Q4: Utilization Category ---
df_clean['util_category'] = pd.cut(
    df_clean['revol_util'],
    bins=[0, 30, 50, 75, 100, np.inf],
    labels=['Low(<30%)', 'Med(30-50%)', 'High(50-75%)', 'VHigh(75-100%)', 'Maxed(>100%)']
)

# --- Additional Binary Flags ---
# Home ownership binary (own vs rent)
df_clean['owns_home'] = df_clean['home_ownership'].isin(['OWN', 'MORTGAGE']).astype(int)

# Income verified binary
df_clean['income_verified'] = df_clean['verification_status'].isin(
    ['Verified', 'Source Verified']
).astype(int)

# STEP 6: CALCULATE DERIVED METRICS

# Average FICO score
df_clean['fico_avg'] = (df_clean['fico_range_low'] + df_clean['fico_range_high']) / 2

# Monthly income
df_clean['monthly_income'] = df_clean['annual_inc'] / 12

# Loan-to-income ratio
df_clean['loan_to_income'] = df_clean['loan_amnt'] / df_clean['annual_inc']

# Payment-to-income ratio
df_clean['payment_to_income_pct'] = (df_clean['installment'] / df_clean['monthly_income']) * 100

# Q5: Risk-Adjusted Return calculation
# Interest income from loan
df_clean['interest_income'] = df_clean['loan_amnt'] * (df_clean['int_rate'] / 100)

# Loss Given Default (for defaulted loans)
df_clean['lgd'] = np.where(
    df_clean['default_flag'] == 1,
    (df_clean['loan_amnt'] - df_clean['recoveries']) / df_clean['loan_amnt'],
    0
)

# Expected loss
df_clean['expected_loss'] = df_clean['loan_amnt'] * df_clean['default_flag'] * df_clean['lgd']

# Risk-adjusted return
df_clean['risk_adjusted_return'] = (df_clean['interest_income'] - df_clean['expected_loss']) / df_clean['loan_amnt']

# Q3: Months since issuance (for vintage analysis)
df_clean['months_since_issue'] = (
    (pd.Timestamp.now() - df_clean['issue_date']).dt.days / 30.44
)

# Q3: Months to default (for defaulted loans)
df_clean['months_to_default'] = np.where(
    df_clean['default_flag'] == 1,
    (df_clean['last_pymnt_date'] - df_clean['issue_date']).dt.days / 30.44,
    np.nan
)

print("\n Created all binary flags and derived metrics")

# STEP 7: HANDLE MISSING VALUES

# For numeric: fill with median
numeric_cols = df_clean.select_dtypes(include=[np.number]).columns
for col in numeric_cols:
    if df_clean[col].isnull().sum() > 0:
        median_val = df_clean[col].median()
        df_clean[col] = df_clean[col].fillna(median_val)

# For categorical: fill with mode or 'Unknown'
categorical_cols = df_clean.select_dtypes(include=['object', 'category', 'str']).columns
for col in categorical_cols:
    if df_clean[col].isnull().sum() > 0:
        mode_val = df_clean[col].mode()[0] if len(df_clean[col].mode()) > 0 else 'Unknown'
        df_clean[col] = df_clean[col].fillna(mode_val)

print("Missing values handled")

# STEP 8: REMOVE OUTLIERS

initial_count = len(df_clean)

# Remove unrealistic values
df_clean = df_clean[df_clean['annual_inc'] <= 500000]  # Income > $500k likely error
df_clean = df_clean[df_clean['annual_inc'] > 1000]      # Income < $1k likely error
df_clean = df_clean[df_clean['dti'] <= 60]              # DTI > 60% unrealistic
df_clean = df_clean[(df_clean['revol_util'] >= 0) & (df_clean['revol_util'] <= 150)]

removed = initial_count - len(df_clean)
print(f" Removed {removed:,} outliers ({removed/initial_count*100:.1f}%)")

# STEP 9: SAVE CLEANED DATA

df_clean.to_csv('loan_data_cleaned_sample.csv', index=False)
print(f"\n DONE! Saved {len(df_clean):,} clean records to 'loan_data_cleaned_sample.csv'")

