CREATE DATABASE CustomerData; 
-- Import bank_churn Data 
 
-- Change table name 
ALTER TABLE bank_churn RENAME TO customer_information; 

-- View column types and null counts 

SELECT 
    column_name, 
    data_type
FROM information_schema.columns
WHERE table_name = 'Customers';

SELECT COUNT(*) AS total_rows, 
COUNT(DISTINCT CustomerId) AS unique_customers, 
SUM(CASE WHEN CustomerId IS NULL THEN 1 ELSE 0 END) AS null_customer_id, 
SUM(CASE WHEN CreditScore IS NULL THEN 1 ELSE 0 END) AS null_credit_score, 
SUM(CASE WHEN Geography IS NULL THEN 1 ELSE 0 END) AS null_geography, 
SUM(CASE WHEN Gender IS NULL THEN 1 ELSE 0 END) AS null_gender
FROM Customer_information;

-- Check for Duplicates 

SELECT CustomerId, COUNT(*) AS count_duplicates 
FROM customer_information 
GROUP BY CustomerId
HAVING COUNT(*) > 1; 

-- Basic Stats for numerical columns 
SELECT MIN(CreditScore) AS min_credit, 
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

-- Frequency Distributions for categorical columns 

SELECT Geography, COUNT(*) AS count_geo
FROM customer_information
GROUP BY Geography
ORDER BY count_geo DESC; 

SELECT Gender, COUNT(*) AS count_gender 
FROM customer_information 
GROUP BY gender; 

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

-- Remove duplicates keep the first occurence 
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

-- ==========================
-- 2. DATA CLEANING
-- ==========================

-- 2.1 Remove duplicates (keeping the first occurrence)
DELETE FROM Customers c
USING (
    SELECT CustomerId, MIN(ctid) AS first_ctid
    FROM Customers
    GROUP BY CustomerId
    HAVING COUNT(*) > 1
) dup
WHERE c.CustomerId = dup.CustomerId AND c.ctid <> dup.first_ctid;

-- 2.2 Standardize categorical data
UPDATE Customer_information
SET Gender = CONCAT(UCASE(LEFT(TRIM(Gender), 1)), LCASE(SUBSTRING(TRIM(Gender), 2)));

UPDATE Customer_information
SET Geography = CONCAT(
    UPPER(LEFT(TRIM(Geography), 1)),
    LOWER(SUBSTRING(TRIM(Geography), 2))
);


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

-- 2.3 Handle missing values
-- Option 1: Remove rows with critical nulls
DELETE FROM Customer_information 
WHERE CustomerId IS NULL
   OR CreditScore IS NULL
   OR Geography IS NULL;

-- Option 2: Impute numeric nulls with median
WITH medians AS (
    SELECT 
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY CreditScore) AS median_credit,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY Age) AS median_age,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY Balance) AS median_balance
    FROM Customer_information
);


-- 2.4 Fix logical inconsistencies
-- Age should be >=18
UPDATE Customer_information
SET Age = 18
WHERE Age < 18;

-- Balance cannot be negative
UPDATE Customer_information
SET Balance = 0
WHERE Balance < 0;

-- NumOfProducts cannot be negative or zero (replace with 1 as default)
UPDATE Customer_information
SET NumOfProducts = 1
WHERE NumOfProducts <= 0;

-- ==========================
-- 3. ADVANCED DATA CHECKS
-- ==========================

-- 3.1 Outliers detection for numeric columns (Z-score)
SELECT *
FROM Customer_information
WHERE ABS((CreditScore - (SELECT AVG(CreditScore) FROM Customer_information)) / (SELECT STDDEV(CreditScore) FROM Customer_information)) > 3
   OR ABS((Balance - (SELECT AVG(Balance) FROM Customer_information)) / (SELECT STDDEV(Balance) FROM Customer_information)) > 3
   OR ABS((EstimatedSalary - (SELECT AVG(EstimatedSalary) FROM Customer_information)) / (SELECT STDDEV(EstimatedSalary) FROM Customer_information)) > 3;

-- 3.2 Cross-field consistency
-- Check if Exited = 1 while IsActiveMember = 'Yes'
SELECT *
FROM Customer_information
WHERE Exited = 1 AND IsActiveMember = 'Yes';

-- 3.3 Summary table for final clean dataset
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

