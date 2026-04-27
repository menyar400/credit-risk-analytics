import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import roc_auc_score, confusion_matrix, classification_report, RocCurveDisplay

# 1. Load your cleaned dataset
df = pd.read_csv('loan_data_cleaned_sample.csv')

# 2. Define Features and Target
features = [
    'fico_avg', 'dti', 'int_rate', 'loan_amnt', 
    'revol_util', 'annual_inc', 'inq_last_6mths', 
    'delinq_2yrs', 'open_acc'
]

# Ensure no NaNs remain for the model
X = df[features].dropna()
y = df.loc[X.index, 'default_flag']

# 3. Split the data (80% Train, 20% Test)
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y
)

# 4. Feature Scaling (Crucial for Logistic Regression)
# This centers data so large numbers (Income) don't drown out small ones (Inquiries)
scaler = StandardScaler()
X_train_scaled = scaler.fit_transform(X_train)
X_test_scaled = scaler.transform(X_test)

# 5. Build and Train Model
# class_weight='balanced' handles the fact that defaults are only ~21% of your data
model = LogisticRegression(max_iter=1000, class_weight='balanced', random_state=42)
model.fit(X_train_scaled, y_train)

# 6. Model Evaluation
y_pred = model.predict(X_test_scaled)
y_proba = model.predict_proba(X_test_scaled)[:, 1]

auc_score = roc_auc_score(y_test, y_proba)
print(f"--- Model Performance ---")
print(f"ROC-AUC Score: {auc_score:.4f}")
print("\nConfusion Matrix:")
print(confusion_matrix(y_test, y_pred))
print("\nClassification Report:")
print(classification_report(y_test, y_pred))

# 7. Feature Importance Analysis
# We look at the coefficients to see which features drive risk UP or DOWN
importance_df = pd.DataFrame({
    'Feature': features,
    'Coefficient': model.coef_[0]
}).sort_values(by='Coefficient', ascending=False)

print("\n--- Feature Coefficients ---")
print(importance_df)

# 8. Visualization for your Report: Feature Importance
plt.figure(figsize=(10, 6))
sns.barplot(x='Coefficient', y='Feature', data=importance_df, palette='RdYlGn_r')
plt.title('Predictors of Loan Default (Logistic Regression Coefficients)')
plt.axvline(0, color='black', lw=1)
plt.xlabel('Coefficient Value (Positive = Higher Risk, Negative = Lower Risk)')
plt.tight_layout()
plt.show()