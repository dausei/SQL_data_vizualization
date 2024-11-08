-- Assignment 1: Clients with continuous history and their transaction statistics

WITH transactions AS (
    SELECT
        t.ID_client,
        t.Sum_payment,
        t.date_new::DATE AS transaction_date
    FROM
        transactions_info t
    WHERE
        t.date_new::DATE >= '2015-06-01'::DATE
        AND t.date_new::DATE < '2016-06-01'::DATE
),
clients_with_full_history AS (
    SELECT
        t.ID_client
    FROM
        transactions t
    GROUP BY
        t.ID_client
    HAVING
        COUNT(DISTINCT DATE_TRUNC('month', t.transaction_date)) = 12
),
client_stats AS (
    SELECT
        t.ID_client,
        COUNT(*) AS total_transactions,
        AVG(t.Sum_payment) AS average_receipt,
        SUM(t.Sum_payment) / 12 AS average_purchase_per_month
    FROM
        transactions t
    INNER JOIN
        clients_with_full_history cfh ON t.ID_client = cfh.ID_client
    GROUP BY
        t.ID_client
)
SELECT
    ID_client,
    average_receipt,
    average_purchase_per_month,
    total_transactions
FROM
    client_stats
ORDER BY
    ID_client;

-- Assignment 2a-d: Monthly transaction statistics

WITH transactions AS (
    SELECT
        t.ID_client,
        t.Sum_payment,
        DATE_TRUNC('month', t.date_new::DATE) AS month_start
    FROM
        transactions_info t
    WHERE
        t.date_new::DATE >= '2015-06-01'::DATE
        AND t.date_new::DATE < '2016-06-01'::DATE
),
monthly_stats AS (
    SELECT
        month_start,
        AVG(t.Sum_payment) AS average_check_amount,
        COUNT(*) AS total_transactions,
        COUNT(DISTINCT t.ID_client) AS clients_in_month,
        SUM(t.Sum_payment) AS total_sum_payment
    FROM
        transactions t
    GROUP BY
        month_start
),
total_stats AS (
    SELECT
        SUM(total_transactions) AS total_transactions_year,
        SUM(total_sum_payment) AS total_sum_payment_year
    FROM
        monthly_stats
)
SELECT
    ms.month_start,
    ms.average_check_amount,
    ms.total_transactions,
    ms.clients_in_month,
    (ms.total_transactions::DECIMAL / 12) AS average_operations_per_month,
    (ms.clients_in_month::DECIMAL / 12) AS average_clients_per_month,
    (ms.total_transactions::DECIMAL / ts.total_transactions_year) * 100 AS transaction_share_percentage,
    (ms.total_sum_payment::DECIMAL / ts.total_sum_payment_year) * 100 AS sum_payment_share_percentage
FROM
    monthly_stats ms,
    total_stats ts
ORDER BY
    ms.month_start;


-- Assignment 2e: Gender ratio and spending per month

WITH transactions AS (
    SELECT
        t.ID_client,
        t.Sum_payment,
        DATE_TRUNC('month', t.date_new::DATE) AS month_start
    FROM
        transactions_info t
    WHERE
        t.date_new::DATE >= '2015-06-01'::DATE
        AND t.date_new::DATE < '2016-06-01'::DATE
),
trans_with_gender AS (
    SELECT
        t.ID_client,
        t.Sum_payment,
        t.month_start,
        COALESCE(c.Gender, 'NA') AS Gender
    FROM
        transactions t
    LEFT JOIN
        customer_info c ON t.ID_client = c.ID_client
),
gender_monthly_stats AS (
    SELECT
        month_start,
        Gender,
        COUNT(*) AS transactions_count,
        SUM(Sum_payment) AS total_sum_payment
    FROM
        trans_with_gender
    GROUP BY
        month_start,
        Gender
),
monthly_totals AS (
    SELECT
        month_start,
        COUNT(*) AS total_transactions,
        SUM(Sum_payment) AS total_sum_payment
    FROM
        trans_with_gender
    GROUP BY
        month_start
)
SELECT
    gms.month_start,
    gms.Gender,
    gms.transactions_count,
    gms.total_sum_payment,
    ROUND((gms.transactions_count::DECIMAL / mt.total_transactions) * 100, 2) AS transactions_percentage,
    ROUND((gms.total_sum_payment::DECIMAL / mt.total_sum_payment) * 100, 2) AS sum_payment_percentage
FROM
    gender_monthly_stats gms
JOIN
    monthly_totals mt ON gms.month_start = mt.month_start
ORDER BY
    gms.month_start, gms.Gender;


-- Assignment 3: Age group transaction statistics

WITH transactions AS (
    SELECT
        t.ID_client,
        t.Sum_payment,
        t.date_new::DATE AS transaction_date,
        EXTRACT(QUARTER FROM t.date_new::DATE) AS transaction_quarter,
        EXTRACT(YEAR FROM t.date_new::DATE) AS transaction_year
    FROM
        transactions_info t
    WHERE
        t.date_new::DATE >= '2015-06-01'::DATE
        AND t.date_new::DATE < '2016-06-01'::DATE
),
trans_with_age AS (
    SELECT
        t.ID_client,
        t.Sum_payment,
        t.transaction_date,
        t.transaction_quarter,
        t.transaction_year,
        c.Age
    FROM
        transactions t
    LEFT JOIN
        customer_info c ON t.ID_client = c.ID_client
),
age_groups AS (
    SELECT
        ID_client,
        Sum_payment,
        transaction_date,
        transaction_quarter,
        transaction_year,
        CASE
            WHEN Age IS NULL THEN 'No Age Info'
            ELSE CONCAT(
                FLOOR(Age / 10) * 10,
                '-',
                FLOOR(Age / 10) * 10 + 9
            )
        END AS age_group
    FROM
        trans_with_age
),
total_per_age_group AS (
    SELECT
        age_group,
        COUNT(*) AS total_transactions,
        SUM(Sum_payment) AS total_sum_payment
    FROM
        age_groups
    GROUP BY
        age_group
),
quarterly_stats AS (
    SELECT
        transaction_year,
        transaction_quarter,
        age_group,
        COUNT(*) AS transactions_count,
        SUM(Sum_payment) AS total_sum_payment
    FROM
        age_groups
    GROUP BY
        transaction_year,
        transaction_quarter,
        age_group
),
quarterly_totals AS (
    SELECT
        transaction_year,
        transaction_quarter,
        COUNT(*) AS total_transactions,
        SUM(Sum_payment) AS total_sum_payment
    FROM
        age_groups
    GROUP BY
        transaction_year,
        transaction_quarter
)
SELECT
    qs.transaction_year,
    qs.transaction_quarter,
    qs.age_group,
    qs.transactions_count AS transactions_in_quarter,
    qs.total_sum_payment AS sum_payment_in_quarter,
    ROUND((qs.transactions_count::DECIMAL / qt.total_transactions) * 100, 2) AS transactions_percentage,
    ROUND((qs.total_sum_payment::DECIMAL / qt.total_sum_payment) * 100, 2) AS sum_payment_percentage,
    tpag.total_transactions AS total_transactions_period,
    tpag.total_sum_payment AS total_sum_payment_period
FROM
    quarterly_stats qs
JOIN
    quarterly_totals qt ON qs.transaction_year = qt.transaction_year AND qs.transaction_quarter = qt.transaction_quarter
JOIN
    total_per_age_group tpag ON qs.age_group = tpag.age_group
ORDER BY
    qs.transaction_year, qs.transaction_quarter, qs.age_group;
