SELECT * FROM customers
LIMIT 100;

SELECT * from transactions
LIMIT 500;



    /* monthly MRR trend for the full period. Where are the biggest jumps or drops? */

WITH s as(
    SELECT
        DATE_TRUNC('MONTH',transaction_date)::date as transaction_month,
        COUNT(DISTINCT(customer_id)) as customers_count,
        ROUND(AVG(amount),2) as avg_amount
    FROM transactions 
    GROUP BY transaction_month
)
    SELECT *,
        ROUND((avg_amount * customers_count),2) as MRR
    FROM s;

    /* MRR Breakdown by plan tier, by month. Which tier drives most of current MRR? */


WITH r as(
    SELECT
        plan_tier,
        DATE_TRUNC('MONTH',transaction_date)::date as transaction_month,
        COUNT(DISTINCT(customer_id)) as customers_count,
        ROUND(AVG(amount),2) as avg_amount
    FROM transactions 
    GROUP BY plan_tier,transaction_month
    ORDER BY plan_tier, transaction_month
)
    SELECT *,
        ROUND((avg_amount * customers_count),2) as MRR
    FROM r;


    /* Standard "MRR waterfall" including the financial effect of 
            New, Expansion (upgrades), Contraction (downgrades), and Churned MRR for each month */


SELECT * FROM transactions;

CREATE OR REPLACE VIEW mrr_waterfall AS
WITH a AS (
    SELECT
        customer_id,
        transaction_date,
        transaction_type,
        amount,
        LAG(amount) OVER (
            PARTITION BY customer_id
            ORDER BY transaction_date
        ) AS prev_amount
    FROM transactions
)
SELECT
    DATE_TRUNC('month', transaction_date)::date AS transaction_month,
    CASE
        WHEN transaction_type IN ('New Subscription', 'Reactivation') THEN 'New MRR'
        WHEN transaction_type = 'Upgrade' THEN 'Expansion MRR'
        WHEN transaction_type = 'Downgrade' THEN 'Contraction MRR'
        WHEN transaction_type = 'Cancellation' THEN 'Churned MRR'
        ELSE 'Renewal'
    END AS mrr_category,
    CASE
        WHEN transaction_type IN ('New Subscription', 'Reactivation') THEN amount
        WHEN transaction_type = 'Upgrade' THEN amount - prev_amount
        WHEN transaction_type = 'Downgrade' THEN prev_amount - amount
        WHEN transaction_type = 'Cancellation' THEN prev_amount
        ELSE 0
    END AS revenue_effect
FROM a;

/********************************************************************************************************
********************************************************************************************************/


    /*4. Monthly customer churn rate (% of active customers at start of month who cancel that month).*/


WITH a as(
        SELECT
            Date_trunc('month', t.transaction_date::date)::date as transaction_month,
            CASE 
                WHEN c.final_status = 'Churned' THEN COUNT(c.customer_id)
                ELSE  0 
            END as count_churn,
            CASE 
                WHEN c.final_status = 'Active' THEN COUNT(c.customer_id)
                ELSE  0
            END as count_active
        FROM customers c
        LEFT JOIN transactions t ON c.customer_id = t.customer_id
        GROUP BY  transaction_month, c.final_status
        ORDER BY transaction_month
    ), b as(
    select
        transaction_month,
        SUM(count_churn) as churned,
        SUM(count_active) as active,
        LAG(SUM(count_active)) OVER(ORDER BY transaction_month) as prev_month_active_count
    FROM a
    GROUP BY transaction_month
)
SELECT 
    transaction_month,
    churned,
    prev_month_active_count,
    ROUND((churned / prev_month_active_count)*100,2) as churn_rate
FROM b;

    /*5. Is churn rate higher for Basic vs Pro vs Enterprise? Show it as a table.*/

WITH a as(
        SELECT
            Date_trunc('month', t.transaction_date::date)::date as transaction_month,
            c.initial_plan,
            CASE 
                WHEN c.final_status = 'Churned' THEN COUNT(c.customer_id)
                ELSE  0 
            END as count_churn,
            CASE 
                WHEN c.final_status = 'Active' THEN COUNT(c.customer_id)
                ELSE  0
            END as count_active
        FROM customers c
        LEFT JOIN transactions t ON c.customer_id = t.customer_id
        GROUP BY  c.initial_plan,transaction_month, c.final_status
        ORDER BY c.initial_plan
    ), b as(
    select
        transaction_month, initial_plan,
        SUM(count_churn) as churned,
        SUM(count_active) as active,
        LAG(SUM(count_active)) OVER(PARTITION BY initial_plan ORDER BY transaction_month) as prev_month_active_count
    FROM a
    GROUP BY transaction_month, initial_plan
)
SELECT 
    transaction_month, initial_plan,
    churned,
    prev_month_active_count,
    ROUND((churned / NULLIF(prev_month_active_count,0))*100,2) as churn_rate
FROM b;


    /* 6. Which acquisition channel has the worst churn rate? Does that change your view of which channel is "best"?*/

WITH a as(
        SELECT
            Date_trunc('month', t.transaction_date::date)::date as transaction_month,
            c.acquisition_channel,
            CASE 
                WHEN c.final_status = 'Churned' THEN COUNT(c.customer_id)
                ELSE  0 
            END as count_churn,
            CASE 
                WHEN c.final_status = 'Active' THEN COUNT(c.customer_id)
                ELSE  0
            END as count_active
        FROM customers c
        LEFT JOIN transactions t ON c.customer_id = t.customer_id
        GROUP BY  c.acquisition_channel,transaction_month, c.final_status
        ORDER BY c.acquisition_channel
    ), b as(
    select
        transaction_month, acquisition_channel,
        SUM(count_churn) as churned,
        SUM(count_active) as active,
        LAG(SUM(count_active)) OVER(PARTITION BY acquisition_channel ORDER BY transaction_month) as prev_month_active_count
    FROM a
    GROUP BY transaction_month, acquisition_channel
)
SELECT 
    transaction_month, acquisition_channel,
    churned,
    prev_month_active_count,
    ROUND((churned / NULLIF(prev_month_active_count,0))*100,2) as churn_rate
FROM b;



/*************************************************************************************************************************************
*************************************************************************************************************************************/

    /*7. Calculate CRR for each calendar year (2021–2025). Formula: customers at end of period who were also active at start, divided by customers active at start.*/

    /*CRR = (customers at the end - new customer acquired) / (customers at the beginning)*100 */
/*customers at the end*/

WITH a as(
    SELECT
        t.customer_id,
        TO_CHAR(t.transaction_date::date,'YYYY') as transaction_year,
        TO_CHAR(c.churn_date::date,'YYYY') as churn_year

    FROM transactions t 
    LEFT JOIN customers c ON t.customer_id = c.customer_id
)
, b as(
    SELECT
        transaction_year,
        COUNT(DISTINCT CASE 
        WHEN churn_year IS DISTINCT FROM transaction_year THEN customer_id
        END) as active_at_end
    FROM a
    GROUP BY transaction_year
    ORDER BY transaction_year
)
,c as(
    SELECT b.*,
        LAG(active_at_end) OVER(ORDER BY transaction_year) as active_at_began
    FROM b
)
,d as(
    SELECT
        TO_CHAR(signup_date::date, 'YYYY') as signup_year,
        COUNT(customer_id) as new_customers
    FROM customers
    GROUP BY signup_year
)
,e as(
    SELECT
        c.*,
        d.new_customers
    FROM d LEFT JOIN c ON signup_year = transaction_year
)
SELECT
    transaction_year as year,
    ROUND(((active_at_end - new_customers)::numeric / NULLIF(active_at_began,0)) * 100,2) as CRR
FROM e
ORDER BY year;


    /*8. Compare CRR across regions. Any region standing out?*/


WITH a as(
    SELECT
        c.region,
        t.customer_id,
        TO_CHAR(t.transaction_date::date,'YYYY') as transaction_year,
        TO_CHAR(c.churn_date::date,'YYYY') as churn_year

    FROM transactions t 
    LEFT JOIN customers c ON t.customer_id = c.customer_id
)
, b as(
    SELECT
        region,
        transaction_year,
        COUNT(DISTINCT CASE 
        WHEN churn_year IS DISTINCT FROM transaction_year THEN customer_id
        END) as active_at_end
    FROM a
    GROUP BY region, transaction_year
    ORDER BY transaction_year
)
,c as(
    SELECT b.*,
        LAG(active_at_end) OVER(PARTITION BY region ORDER BY transaction_year) as active_at_began
    FROM b
)
,d as(
    SELECT
        region,
        TO_CHAR(signup_date::date, 'YYYY') as signup_year,
        COUNT(customer_id) as new_customers
    FROM customers
    GROUP BY region, signup_year
)
,e as(
    SELECT
        c.*,
        d.new_customers
    FROM c LEFT JOIN d ON signup_year = transaction_year AND d.region = c.region
)
SELECT
    region,
    transaction_year as year,
    ROUND(((active_at_end - new_customers)::numeric / NULLIF(active_at_began,0)) * 100,2) as CRR
FROM e
ORDER BY year;



/******************************************************************************************
******************************************************************************************/


      /* GRR Gross revenue retention for cohort "Customers Who Signed Up on Feb 2024" and
            Tracking their GRR within their first year and the second Year*/

/* GRR = (starting MRR - Churn - contraction) / starting MRR*/

/*building Cohort*/


WITH cohort as(
        SELECT 
            customer_id,
            Date_Trunc('month', signup_date)::DATE as cohort_month
        FROM customers
        WHERE Date_Trunc('month', signup_date)::DATE = '2024-02-01'
)
SELECT
        cohort.customer_id,
        cohort.cohort_month,
        t.transaction_date::DATE,
        t.transaction_type,
        t.amount
    FROM transactions t
    INNER JOIN cohort USING (customer_id);


/* Tracking GRR for the first year*/


WITH cohort as(
        SELECT 
            customer_id,
            Date_Trunc('month', signup_date)::DATE as cohort_month
        FROM customers
        WHERE Date_Trunc('month', signup_date)::DATE = '2024-02-01'
), b as(
SELECT
        cohort.customer_id,
        Date_Trunc('month', t.transaction_date)::DATE as transaction_month,
        t.transaction_type,
        t.amount,
        FIRST_VALUE(amount) OVER(PARTITION BY customer_id 
        ORDER BY Date_Trunc('month', t.transaction_date)::DATE) as starting_mrr,
        LAG(amount) OVER(PARTITION BY customer_id ORDER BY t.transaction_date) as prev_month
    FROM transactions t
    INNER JOIN cohort USING (customer_id)
    where Date_Trunc('month', t.transaction_date)::DATE <= cohort_month + INTERVAL '1year'
), c as(
    
    SELECT
        
        MAX(starting_mrr) as starting_mrr,
        SUM(CASE WHEN transaction_type = 'Cancellation' THEN prev_month ELSE 0 END) as churn_amount ,
        SUM(CASE WHEN transaction_type = 'Downgrade' THEN prev_month - amount ELSE 0 END) as contraction_amount
    from b
    GROUP BY customer_id
)
SELECT
    SUM(starting_mrr) as mrr,
     SUM(churn_amount) as churn,
     SUM(contraction_amount) as contraction,
    ROUND((SUM(starting_mrr) - SUM(churn_amount) - SUM(contraction_amount)):: NUMERIC / SUM(starting_mrr),2) as GRR
FROM c




/* Tracking GRR for the second year*/


WITH cohort as(
        SELECT 
            customer_id,
            Date_Trunc('month', signup_date)::DATE as cohort_month
        FROM customers
        WHERE Date_Trunc('month', signup_date)::DATE = '2024-02-01'
), b as(
SELECT
        cohort.customer_id,
        Date_Trunc('month', t.transaction_date)::DATE as transaction_month,
        t.transaction_type,
        t.amount,
        FIRST_VALUE(amount) OVER(PARTITION BY customer_id 
        ORDER BY Date_Trunc('month', t.transaction_date)::DATE) as starting_mrr,
        LAG(amount) OVER(PARTITION BY customer_id ORDER BY t.transaction_date) as prev_month
    FROM transactions t
    INNER JOIN cohort USING (customer_id)
    where Date_Trunc('month', t.transaction_date)::DATE >= cohort_month + INTERVAL '1year'
    AND Date_Trunc('month', t.transaction_date)::DATE <= cohort_month + INTERVAL '2year'
), c as(

    SELECT
        
        MAX(starting_mrr) as starting_mrr,
        SUM(CASE WHEN transaction_type = 'Cancellation' THEN prev_month ELSE 0 END) as churn_amount ,
        SUM(CASE WHEN transaction_type = 'Downgrade' THEN prev_month - amount ELSE 0 END) as contraction_amount
    from b
    GROUP BY customer_id
)
SELECT
    SUM(starting_mrr) as mrr,
     SUM(churn_amount) as churn,
     SUM(contraction_amount) as contraction,
    ROUND((SUM(starting_mrr) - SUM(churn_amount) - SUM(contraction_amount)):: NUMERIC / SUM(starting_mrr),2) as GRR
FROM c




/******************************************************************************************
******************************************************************************************/

        /* (Net Revenue Retention)
                 for the cohort of fisrt Quarter in 2024. Now include upgrade revenue. What's the NRR?*/


    /* COmparing NRR for the fisrt Year and Second Year of Signing up */ 


WITH cohort as(
        SELECT 
            customer_id,
            Date_Trunc('quarter', signup_date)::DATE as cohort_quarter
        FROM customers
        WHERE Date_Trunc('quarter', signup_date)::DATE = '2024-01-01'
), b as ( /*for first year*/
    SELECT
        cohort.customer_id,
        cohort_quarter,
        Date_Trunc('quarter', t.transaction_date)::DATE as transaction_quarter,
        t.transaction_type,
        t.amount,
        FIRST_VALUE(amount) OVER(PARTITION BY customer_id 
        ORDER BY Date_Trunc('quarter', t.transaction_date)::DATE) as starting_mrr,
        LAG(amount) OVER(PARTITION BY customer_id ORDER BY t.transaction_date) as prev_quarter
    FROM transactions t
    INNER JOIN cohort USING (customer_id)
    where Date_Trunc('quarter', t.transaction_date)::DATE BETWEEN '2024-01-01' AND '2024-10-01'
), c
as( /*for first year*/
    SELECT
        cohort_quarter,
        Date_Trunc('year',transaction_quarter)::DATE as year,
        MAX(starting_mrr) as starting_mrr,
        SUM(CASE WHEN transaction_type = 'Cancellation' THEN prev_quarter ELSE 0 END) as churn_amount ,
        SUM(CASE WHEN transaction_type = 'Downgrade' THEN prev_quarter - amount ELSE 0 END) as contraction_amount,
        SUM(CASE WHEN transaction_type = 'Upgrade' THEN amount - prev_quarter ELSE 0 END) as expanion_amount
    from b
    GROUP BY customer_id,cohort_quarter,year
), d as( /*for second year*/
    SELECT
        cohort_quarter,
        cohort.customer_id,
        Date_Trunc('quarter', t.transaction_date)::DATE as transaction_quarter,
        t.transaction_type,
        t.amount,
        FIRST_VALUE(amount) OVER(PARTITION BY customer_id 
        ORDER BY Date_Trunc('quarter', t.transaction_date)::DATE) as starting_mrr,
        LAG(amount) OVER(PARTITION BY customer_id ORDER BY t.transaction_date) as prev_quarter
    FROM transactions t
    INNER JOIN cohort USING (customer_id)
    where Date_Trunc('quarter', t.transaction_date)::DATE BETWEEN '2025-01-01' AND '2025-10-01'
), e as( /*for second year*/
    SELECT
        cohort_quarter,
        customer_id,
        Date_Trunc('year',transaction_quarter)::DATE as year,
        MAX(starting_mrr) as starting_mrr,
        SUM(CASE WHEN transaction_type = 'Cancellation' THEN prev_quarter ELSE 0 END) as churn_amount ,
        SUM(CASE WHEN transaction_type = 'Downgrade' THEN prev_quarter - amount ELSE 0 END) as contraction_amount,
        SUM(CASE WHEN transaction_type = 'Upgrade' THEN amount - prev_quarter ELSE 0 END) as expanion_amount
    from d
    GROUP BY cohort_quarter,customer_id,year
), f as(
    /*for_first_year*/
SELECT
    
    MAX(year) as year,
    SUM(starting_mrr) as mrr,
     SUM(churn_amount) as churn,
     SUM(contraction_amount) as contraction,
     SUM(expanion_amount) as expansion,
    ROUND((SUM(starting_mrr) - SUM(churn_amount) - SUM(contraction_amount) + SUM(expanion_amount)):: NUMERIC / SUM(starting_mrr),2) as NRR
FROM c
), g as(
    /*for second year*/
SELECT
    
    MAX(year) as year,
    SUM(starting_mrr) as mrr,
     SUM(churn_amount) as churn,
     SUM(contraction_amount) as contraction,
     SUM(expanion_amount) as expansion,
    ROUND((SUM(starting_mrr) - SUM(churn_amount) - SUM(contraction_amount) + SUM(expanion_amount)):: NUMERIC / SUM(starting_mrr),2) as NRR
FROM e
)

SELECT
    'Year 1' as period,
    f.mrr, f.churn, f.contraction, f.expansion, f.NRR
FROM f

UNION ALL

SELECT
    'Year 2' as period,
    g.mrr, g.churn, g.contraction, g.expansion, g.NRR
FROM g




/******************************************************************************************
******************************************************************************************/

        /*Calculate ARPU by month for the whole customer base "Average Revenue Per User"*/


SELECT * FROM customers;
SELECT * from transactions;


WITH a as(
    SELECT 
        
        CAST(DATE_TRUNC('quarter', CAST(transaction_date AS date)) AS date) AS quarter,
        COUNT(DISTINCT customer_id) AS num_customers,
        ROUND(SUM(amount), 2) AS total_amount
    FROM transactions
    WHERE amount > 0
    GROUP BY quarter
)
    SELECT
        quarter,
        ROUND(total_amount::numeric /num_customers,2) as ARPU
    FROM a

    /*Calculate ARPU by Plan Tier */


WITH a as(
    SELECT 
        plan_tier,
        CAST(DATE_TRUNC('quarter', CAST(transaction_date AS date)) AS date) AS quarter,
        COUNT(DISTINCT customer_id) AS num_customers,
        ROUND(SUM(amount), 2) AS total_amount
    FROM transactions
    WHERE amount > 0
    GROUP BY quarter, plan_tier
),b as(
    SELECT
        plan_tier,
        quarter,
        ROUND(total_amount::numeric /num_customers,2) as ARPU
    FROM a
    ORDER BY plan_tier, quarter
)
SELECT
    ROUND(AVG(total_amount::numeric /num_customers),2) as ARPU
    FROM a

    /*Calculate ARPU by Region */

WITH a as(
    SELECT 
        c.region,
        CAST(DATE_TRUNC('quarter', CAST(t.transaction_date AS date)) AS date) AS quarter,
        COUNT(DISTINCT t.customer_id) AS num_customers,
        ROUND(SUM(t.amount), 2) AS total_amount
    FROM transactions t 
    LEFT JOIN customers c 
    ON t.customer_id = c.customer_id
    WHERE t.amount > 0
    GROUP BY quarter, region
)
    SELECT
        region,
        quarter,
        ROUND(total_amount::numeric /num_customers,2) as ARPU
    FROM a
    ORDER BY region, quarter



/******************************************************************************************
******************************************************************************************/



            /*CAC (Customer Acquisition Cost)*/

    /*checking Acquisition Details*/

SELECT
    customer_id,
    signup_date::date,
    acquisition_channel,
    acquisition_cost::Numeric,
    first_churn_date::date,
    (first_churn_date::date - signup_date::date) as time_before_churn
FROM customers
ORDER BY acquisition_cost DESC



    /*15. Calculate blended CAC by year for each channel. Is CAC trending up or down?
*/

WITH a as(
    SELECT 
        acquisition_channel,
        Date_Trunc('year', signup_date::date)::date as year,
        COUNT(customer_id) as new_customers,
        ROUND(SUM(acquisition_cost)::numeric,2) as total_spent
    FROM customers
    GROUP BY year, acquisition_channel
    ORDER BY acquisition_channel, year
)
SELECT 
    acquisition_channel,
    year,
    ROUND((total_spent / new_customers),2) as CAC
FROM a




/******************************************************************************************
******************************************************************************************/


        /* CLTV (Customer Lifetime Value) */

    /*For churned customers only, calculate actual realized lifetime value (sum of all their payments). What's the average?*/


WITH a as(
    SELECT
        t.customer_id,
        c.signup_date::date as join_date,
        ROUND(AVG(t.amount)FILTER (WHERE t.amount > 0),2) as avg_order_value,
        c.first_churn_date::date,
    (c.first_churn_date::date - c.signup_date::date)::numeric as lifespan_days,
    COUNT(t.transaction_id) as freq_count
    FROM customers c LEFT JOIN transactions t
    ON t.customer_id = c.customer_id
    WHERE c.final_status = 'Churned'
    GROUP BY t.customer_id, c.signup_date, c.first_churn_date
    ORDER BY join_date
), b as(
    SELECT
        customer_id,join_date,avg_order_value,lifespan_days,freq_count,
        (avg_order_value * freq_count) as CLTV
    FROM a
)
SELECT 
    ROUND(AVG(CLTV),2) as average_ltv,
    ROUND((SUM(lifespan_days) / COUNT(customer_id)),2) as avg_lifespan_days,
    ROUND((SUM(lifespan_days) / COUNT(customer_id)) / 30.0, 2) as avg_lifespan_months,
    ROUND(202.49 * ((SUM(lifespan_days) / COUNT(customer_id)) / 30.0), 2) as estimate_ltv
FROM b













