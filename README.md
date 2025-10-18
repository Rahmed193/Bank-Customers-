# Bank-Customers-
This project demonstrates a complete SQL-based data exploration and cleaning workflow using a customer churn dataset from a retail bank. The goal is to prepare raw customer data for analysis by ensuring data integrity, consistency, and accuracy.

#Customer Data Cleaning and Exploration (SQL Project)

**Database:** `CustomerData`

This project demonstrates a full **SQL workflow** for data exploration, cleaning, and validation of a **customer churn dataset**.  
The dataset includes key banking attributes such as customer demographics, account information, and churn status.

---

## 1. Database Setup

```sql
CREATE DATABASE CustomerData;
```

The dataset bank_churn is imported and renamed for clarity:

```sql
ALTER TABLE bank_churn RENAME TO customer_information;
```


🔍 2. Data Exploration
2.1 View Column Types
sql
Copy code
SELECT 
    column_name, 
    data_type
FROM information_schema.columns
WHERE table_name = 'Customer_information';
2.2 Data Completeness & Null Check
sql
Copy code
SELECT COUNT(*) AS total_rows, 
COUNT(DISTINCT CustomerId) AS unique_customers, 
SUM(CASE WHEN CustomerId IS NULL THEN 1 ELSE 0 END) AS null_customer_id, 
SUM(CASE WHEN CreditScore IS NULL THEN 1 ELSE 0 END) AS null_credit_score, 
SUM(CASE WHEN Geography IS NULL THEN 1 ELSE 0 END) AS null_geography, 
SUM(CASE WHEN Gender IS NULL THEN 1 ELSE 0 END) AS null_gender
FROM Customer_information;
2.3 Duplicate Detection
sql
Copy code
SELECT CustomerId, COUNT(*) AS count_duplicates 
FROM customer_information 
GROUP BY CustomerId
HAVING COUNT(*) > 1;
2.4 Summary Statistics for Numerical Columns
sql
Copy code
SELECT 
    MIN(CreditScore) AS min_credit, 
    MAX(CreditScore) AS max_credit,
    ROUND(AVG(CreditScore), 0) AS avg_credit, 
    MIN(Age) AS min_age, 
    MAX(Age) AS max_age, 
    ROUND(AVG(age), 0) AS avg_age, 
    MIN(Balance) AS min_balance, 
    CONCAT('£', MAX(Balance)) AS max_balance, 
    CONCAT('£', ROUND(AVG(Balance), 2)) AS avg_balance, 
    CONCAT('£', MAX(EstimatedSalary)) AS max_salary, 
    CONCAT('£', ROUND(AVG(EstimatedSalary), 2)) AS avg_salary
FROM customer_information;
2.5 Frequency Distributions for Categorical Columns
Geography Distribution

sql
Copy code
SELECT Geography, COUNT(*) AS count_geo
FROM customer_information
GROUP BY Geography
ORDER BY count_geo DESC;
Gender Distribution

sql
Copy code
SELECT Gender, COUNT(*) AS count_gender 
FROM customer_information 
GROUP BY gender;
Has Credit Card Distribution

sql
Copy code
SELECT 
CASE 
	WHEN HasCrCard = 1 THEN 'Yes'
    WHEN HasCrCard = 0 THEN 'No'
    ELSE 'Unknown' 
END AS HasCrCardStatus, 
COUNT(*) AS count_card
FROM customer_information
GROUP BY 
CASE 
	WHEN HasCrCard = 1 THEN 'Yes'
    WHEN HasCrCard = 0 THEN 'No'
    ELSE 'Unknown' 
END;
Active Member Distribution

sql
Copy code
SELECT 
CASE 
	WHEN IsActiveMember = 1 THEN 'Yes'
    WHEN IsActiveMember = 0 THEN 'No' 
    ELSE 'Unknown'
END AS Active_member_status, 
COUNT(*) AS count_active
FROM Customer_information
GROUP BY 
	CASE 
		WHEN IsActiveMember = 1 THEN 'Yes'
        WHEN IsActiveMember = 0 THEN 'No' 
    ELSE 'Unknown'
END;
🧼 3. Data Cleaning
3.1 Remove Duplicate Records
sql
Copy code
WITH duplicates AS (
    SELECT 
        CustomerId,
        ROW_NUMBER() OVER (PARTITION BY CustomerId ORDER BY CustomerId) AS rn
    FROM customer_information
)
DELETE FROM customer_information
WHERE CustomerId IN (
    SELECT CustomerId
    FROM duplicates
    WHERE rn > 1
);
3.2 Standardize Categorical Columns
sql
Copy code
UPDATE Customer_information
SET Gender = CONCAT(UCASE(LEFT(TRIM(Gender), 1)), LCASE(SUBSTRING(TRIM(Gender), 2)));

UPDATE Customer_information
SET Geography = CONCAT(UPPER(LEFT(TRIM(Geography), 1)), LOWER(SUBSTRING(TRIM(Geography), 2)));
Normalize Binary Fields

sql
Copy code
UPDATE Customer_information
SET HasCrCard = CASE 
                    WHEN HasCrCard IN ('1', 'Yes', 'Y') THEN 'Yes'
                    WHEN HasCrCard IN ('0', 'No', 'N') THEN 'No'
                    ELSE NULL
                END;

UPDATE Customer_information
SET IsActiveMember = CASE 
                        WHEN IsActiveMember IN ('1', 'Yes', 'Y') THEN 'Yes'
                        WHEN IsActiveMember IN ('0', 'No', 'N') THEN 'No'
                        ELSE NULL
                     END;
3.3 Handle Missing Values
Option 1: Remove rows with critical nulls

sql
Copy code
DELETE FROM Customer_information 
WHERE CustomerId IS NULL
   OR CreditScore IS NULL
   OR Geography IS NULL;
Option 2: Median Imputation (PostgreSQL/MySQL 8+)

sql
Copy code
WITH medians AS (
    SELECT 
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY CreditScore) AS median_credit,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY Age) AS median_age,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY Balance) AS median_balance
    FROM Customer_information
);
3.4 Logical Consistency Checks
sql
Copy code
UPDATE Customer_information
SET Age = 18
WHERE Age < 18;

UPDATE Customer_information
SET Balance = 0
WHERE Balance < 0;

UPDATE Customer_information
SET NumOfProducts = 1
WHERE NumOfProducts <= 0;

4. Advanced Data Checks
4.1 Outlier Detection (Z-score Method)
sql
Copy code
SELECT *
FROM Customer_information
WHERE ABS((CreditScore - (SELECT AVG(CreditScore) FROM Customer_information)) / (SELECT STDDEV(CreditScore) FROM Customer_information)) > 3
   OR ABS((Balance - (SELECT AVG(Balance) FROM Customer_information)) / (SELECT STDDEV(Balance) FROM Customer_information)) > 3
   OR ABS((EstimatedSalary - (SELECT AVG(EstimatedSalary) FROM Customer_information)) / (SELECT STDDEV(EstimatedSalary) FROM Customer_information)) > 3;
4.2 Cross-Field Consistency
sql
Copy code
SELECT *
FROM Customer_information
WHERE Exited = 1 AND IsActiveMember = 'Yes';
🧾 5. Final Clean Dataset
After cleaning and validation, the refined dataset is stored in a new table:

sql
Copy code
CREATE TABLE Customers_Clean AS
SELECT CustomerId,
       Surname,
       CreditScore,
       Geography,
       Gender,
       Age,
       Tenure,
       Balance,
       NumOfProducts,
       HasCrCard,
       IsActiveMember,
       EstimatedSalary,
       Exited
FROM Customer_information;

Summary of Process
Step	Description
1	Created database and imported customer churn data
2	Performed data profiling (types, nulls, duplicates, distributions)
3	Standardized and cleaned categorical and numerical fields
4	Handled missing values and logical inconsistencies
5	Identified outliers and inconsistencies
6	Created a clean final dataset ready for analysis

Insights
Cleaned and standardized over 12 columns for consistent data quality

Removed duplicates and invalid entries to ensure one record per customer

Standardized categorical values such as Gender, Geography, and HasCrCard

Identified potential data quality issues such as outliers in salary and balance

Tools Used
	MySQL Workbench for SQL scripting
 	SQL Window Functions for deduplication
	Conditional CASE logic for categorical normalization
	Aggregate and analytical queries for data profiling and validation
