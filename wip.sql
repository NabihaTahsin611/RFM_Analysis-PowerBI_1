-- Step 1: Append all monthly sales tables together

SELECT table_name, count(column_name) as column_count
FROM `rfmproject59.sales.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name LIKE 'sales2025%'
GROUP BY 1;

CREATE OR REPLACE TABLE `rfmproject59.sales.sales_2025` AS
SELECT * FROM `rfmproject59.sales.sales202501`
UNION ALL SELECT * FROM `rfmproject59.sales.sales202502`
UNION ALL SELECT * FROM `rfmproject59.sales.sales202503`
UNION ALL SELECT * FROM `rfmproject59.sales.sales202504`
UNION ALL SELECT * FROM `rfmproject59.sales.sales202505`
UNION ALL SELECT * FROM `rfmproject59.sales.sales202506`
UNION ALL SELECT * FROM `rfmproject59.sales.sales202507`
UNION ALL SELECT * FROM `rfmproject59.sales.sales202508`
UNION ALL SELECT * FROM `rfmproject59.sales.sales202509`
UNION ALL SELECT * FROM `rfmproject59.sales.sales202510`
UNION ALL SELECT * FROM `rfmproject59.sales.sales202511`
UNION ALL SELECT * FROM `rfmproject59.sales.sales202512`;


-- Step 2: Calculate recency, frequency, monetary, rfm ranks
-- Combine views with CTEs

CREATE OR REPLACE VIEW `rfmproject59.sales.rfm_metrics` AS
WITH current_date AS (
  SELECT DATE('2026-04-23') AS analysis_date --today's date
), 
rfm AS (
  SELECT CustomerID, MAX(OrderDate) AS last_order_date,
  date_diff((SELECT analysis_date FROM current_date), MAX(OrderDate), DAY) AS recency,
  COUNT(*) AS frequency,
  SUM(OrderValue) AS monetary
  FROM `rfmproject59.sales.sales_2025`
  GROUP BY CustomerID
)
SELECT rfm.*,ROW_NUMBER() OVER(ORDER BY recency ASC) AS r_rank,
row_number() OVER(ORDER BY frequency DESC) AS f_rank,
row_number() OVER(ORDER BY monetary DESC) AS m_rank
FROM rfm;


-- Step 3: Assign Deciles (10=best, 1=worst)
CREATE OR REPLACE VIEW `rfmproject59.sales.rfm_scores`
AS SELECT*, 
NTILE(10) OVER(order by r_rank DESC) as r_score,
NTILE(10) OVER(order by f_rank DESC) as f_score,
NTILE(10) OVER(order by m_rank DESC) as m_score 
FROM `rfmproject59.sales.rfm_metrics`;


-- Step 4: Total Score
CREATE OR REPLACE VIEW `rfmproject59.sales.rfm_total_scores` AS SELECT CustomerID, recency, frequency, monetary, r_score, f_score, m_score, (r_score+f_score+m_score) AS rfm_total_score FROM `rfmproject59.sales.rfm_scores` ORDER BY rfm_total_score DESC;


-- Step 5: BI Ready rfm Segments Table
CREATE OR REPLACE TABLE `rfmproject59.sales.rfm_segments_final` AS SELECT CustomerID, recency, frequency, monetary, r_score, f_score, m_score, rfm_total_score,
CASE WHEN rfm_total_score >= 28 THEN 'Champions' -- 20-30
WHEN rfm_total_score >= 24 THEN 'Loyal VIPs' 
WHEN rfm_total_score >= 20 THEN 'Potential Loyalists' 
WHEN rfm_total_score >= 16 THEN 'Promising' 
WHEN rfm_total_score >= 12 THEN 'Engaged' 
WHEN rfm_total_score >= 8 THEN 'Required Attention'
WHEN rfm_total_score >= 4 THEN 'At Risk'
ELSE 'Lost/Inactive'
END AS rfm_segment
FROM `rfmproject59.sales.rfm_total_scores` ORDER BY rfm_total_score DESC;

SELECT rfm_segment, count(*) FROM `rfmproject59.sales.rfm_segments_final` GROUP BY rfm_segment;
