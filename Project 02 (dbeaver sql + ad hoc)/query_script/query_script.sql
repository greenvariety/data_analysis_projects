/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Пушков Никита Максимович
 * Дата: 20.02.2025
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
SELECT 
	COUNT(id) AS total_players,
	SUM(payer) AS paying_players,
	AVG(payer) AS avg_paying_players
FROM fantasy.users;

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
SELECT
	r.race,
	COUNT(u.id) AS total_players,
	SUM(u.payer) AS paying_players,
	AVG(u.payer) AS avg_paying_players
FROM fantasy.users AS u
JOIN fantasy.race AS r ON r.race_id = u.race_id
GROUP BY r.race
ORDER BY total_players DESC;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT 
    COUNT(*) AS total_events,
    SUM(amount) AS sum_amount,
    MIN(amount) AS min_amount,
    MAX(amount) AS max_amount,
    ROUND(CAST(AVG(amount) AS NUMERIC), 2) AS avg_amount,
    ROUND(CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY amount) AS NUMERIC), 2) AS median_amount,
    ROUND(CAST(STDDEV(amount) AS NUMERIC), 2) AS stddev_amount
FROM fantasy.events;


-- 2.2: Аномальные нулевые покупки:
SELECT 
    COUNT(*) AS null_events, 
    CAST(COUNT(*) AS float) / CAST((SELECT COUNT(*) FROM fantasy.events) 
    AS float) AS null_total_events
FROM fantasy.events
WHERE amount = 0;

-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:
WITH paying_players AS (
    SELECT
        u.id,
        COUNT(*) AS total_payers,
        SUM(e.amount) AS total_amount
    FROM fantasy.events AS e
    LEFT JOIN fantasy.users AS u ON e.id = u.id
    WHERE e.amount > 0 AND u.payer = 1
    GROUP BY u.id
),
not_paying_players AS (
    SELECT
        u.id,
        COUNT(*) AS total_npayers,
        SUM(e.amount) AS total_amount
    FROM fantasy.events AS e
    LEFT JOIN fantasy.users AS u ON e.id = u.id
    WHERE e.amount > 0 AND u.payer = 0
    GROUP BY u.id
)
SELECT
    1 AS payer,
    COUNT(*) AS total_players,
    ROUND(CAST(AVG(total_payers) AS NUMERIC), 2) AS avg_count,
    ROUND(CAST(AVG(total_amount) AS NUMERIC), 2) AS avg_sum
FROM paying_players
UNION ALL
SELECT
    0 AS payer,
    COUNT(*) AS total_players,
    ROUND(CAST(AVG(total_npayers) AS NUMERIC), 2) AS avg_count,
    ROUND(CAST(AVG(total_amount) AS NUMERIC), 2) AS avg_sum
FROM not_paying_players;


-- 2.4: Популярные эпические предметы:
WITH total AS (
    SELECT 
        COUNT(DISTINCT id) AS total_payers,
        COUNT(transaction_id) AS total_orders
    FROM fantasy.events
    WHERE amount > 0
)
SELECT 
    i.game_items AS game_items,
    COUNT(DISTINCT e.id) AS total_payers,
    COUNT(DISTINCT e.transaction_id) AS total_orders,
    (COUNT(e.transaction_id)::REAL / (SELECT total_orders FROM total) * 100)::NUMERIC AS total_sales,
    (COUNT(DISTINCT e.id)::REAL / (SELECT total_payers FROM total) * 100)::NUMERIC AS total_id_p
FROM fantasy.events AS e
LEFT JOIN fantasy.items AS i 
    ON e.item_code = i.item_code
WHERE e.amount > 0
GROUP BY i.game_items
ORDER BY total_payers DESC;

-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:
WITH race_players AS (
    SELECT
        u.race_id,
        COUNT(DISTINCT u.id) AS total_players
    FROM fantasy.users AS u
    GROUP BY u.race_id
),
race_payers AS (
    SELECT
        u.race_id,
        COUNT(DISTINCT u.id) AS players_purchases,
        SUM(CASE WHEN u.payer = 1 THEN 1 ELSE 0 END) AS payers
    FROM fantasy.users AS u
    JOIN fantasy.events AS e ON u.id = e.id
    WHERE e.amount > 0
    GROUP BY u.race_id
),
unique_payers AS (
    SELECT 
        u.race_id, 
        COUNT(DISTINCT e.id) AS unique_payers 
    FROM fantasy.events AS e
    JOIN fantasy.users AS u ON e.id = u.id  
    WHERE e.amount > 0 AND u.payer = 1
    GROUP BY u.race_id
),
race_activity AS (
    SELECT
        u.race_id,
        COUNT(e.transaction_id) AS total_purchases,
        SUM(e.amount) AS total_spent,
        CAST(COUNT(e.transaction_id) AS FLOAT) / NULLIF(COUNT(DISTINCT u.id), 0) AS avg_purchases,
        CAST(SUM(e.amount) AS FLOAT) / NULLIF(COUNT(DISTINCT u.id), 0) AS avg_cost_player,
        CAST(SUM(e.amount) AS FLOAT) / NULLIF(COUNT(DISTINCT e.transaction_id), 0) AS avg_cost_purchase
    FROM fantasy.users AS u
    JOIN fantasy.events AS e ON u.id = e.id
    GROUP BY u.race_id
)
SELECT 
    r.race, 
    rp1.total_players,
    rpay.players_purchases,
    CAST(rpay.players_purchases AS FLOAT) / NULLIF(rp1.total_players, 0) AS purchase_ratio,
    CAST(up.unique_payers AS FLOAT) / NULLIF(rpay.players_purchases, 0) AS payers_ratio,
    ra.total_spent,
    ra.avg_purchases,
    ra.avg_cost_player,
    ra.avg_cost_purchase
FROM race_players AS rp1
LEFT JOIN fantasy.race AS r ON rp1.race_id = r.race_id
LEFT JOIN race_payers AS rpay ON r.race_id = rpay.race_id
LEFT JOIN unique_payers AS up ON r.race_id = up.race_id
LEFT JOIN race_activity AS ra ON rp1.race_id = ra.race_id
ORDER BY ra.total_spent DESC, ra.avg_cost_player DESC, r.race;