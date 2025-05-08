/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 * 
 * Автор: Пушков Никита
 * Дата: 12.03.2025
*/

-- Задача 1: Время активности объявлений
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY floors_total) AS floors_total_limit,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
filtered_id AS (
    SELECT * 
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
        AND floors_total < (SELECT floors_total_limit FROM limits)
),
category AS (
    SELECT 
        CASE  
            WHEN city.city = 'Санкт-Петербург' THEN 'Санкт-Петербург' 
            ELSE 'ЛенОбл' 
        END AS region,
        CASE  
            WHEN advertisement.days_exposition IS NULL THEN 'неопределено'
            WHEN advertisement.days_exposition BETWEEN 1 AND 30 THEN 'до месяца'
            WHEN advertisement.days_exposition BETWEEN 31 AND 90 THEN 'до трех месяцев'
            WHEN advertisement.days_exposition BETWEEN 91 AND 180 THEN 'до полугода'
            WHEN advertisement.days_exposition > 180 THEN 'более полугода'
        END AS activity_segment,
        COUNT(*) AS count_ads,
        ROUND(AVG(advertisement.last_price::numeric / flats.total_area::numeric)) AS avg_price_square_meter,
        ROUND(AVG(flats.total_area::numeric), 1) AS avg_area,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY flats.rooms) AS median_quantity_room,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY flats.balcony) AS median_quantity_balcony,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY flats.floors_total) AS median_quantity_floor,
        ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY 
            CASE  
                WHEN city.city = 'Санкт-Петербург' THEN 'Санкт-Петербург' 
                ELSE 'ЛенОбл' 
            END)::numeric, 2) AS ads_percentage
    FROM real_estate.advertisement
    JOIN real_estate.flats ON advertisement.id = flats.id
    JOIN real_estate.city ON flats.city_id = city.city_id
    JOIN real_estate.type ON flats.type_id = type.type_id
    WHERE type.type = 'город'
      AND advertisement.first_day_exposition BETWEEN '2015-01-01' AND '2018-12-31'
      AND advertisement.id IN (SELECT id FROM filtered_id)
    GROUP BY region, activity_segment
)
SELECT * 
FROM category 
ORDER BY 
    CASE region 
        WHEN 'Санкт-Петербург' THEN 1 
        WHEN 'ЛенОбл' THEN 2 
    END,
    CASE activity_segment
        WHEN 'до месяца' THEN 1
        WHEN 'до трех месяцев' THEN 2
        WHEN 'до полугода' THEN 3
        WHEN 'более полугода' THEN 4
        WHEN 'неопределено' THEN 5
    END;

-- Задача 2: Сезонность объявлений
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits) 
              AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) 
             OR ceiling_height IS NULL)
),
first_month AS (
    SELECT 
        'Публикация' AS type_action,
        EXTRACT('month' FROM first_day_exposition) AS month_action,
        COUNT(advertisement.id) AS count_action,
        ROUND(AVG(advertisement.last_price / flats.total_area)::numeric, 2) AS avg_metr_price,
        ROUND(AVG(flats.total_area)::numeric, 2) AS avg_area_price,
        RANK() OVER (ORDER BY COUNT(advertisement.id) DESC) AS top_month
    FROM real_estate.advertisement
    LEFT JOIN real_estate.flats ON flats.id = advertisement.id
    LEFT JOIN real_estate.city ON city.city_id = flats.city_id
    WHERE flats.id IN (SELECT * FROM filtered_id)
      AND type_id = 'F8EM'
      AND first_day_exposition BETWEEN '2015-01-01' AND '2018-12-31'
    GROUP BY EXTRACT('month' FROM first_day_exposition)
),
last_month AS (
    SELECT 
        'Снятие' AS type_action,
        EXTRACT('month' FROM (first_day_exposition::date + days_exposition::integer)) AS month_action,
        COUNT(advertisement.id) AS count_action,
        ROUND(AVG(advertisement.last_price / flats.total_area)::numeric, 2) AS avg_metr_price,
        ROUND(AVG(flats.total_area)::numeric, 2) AS avg_area_price,
        RANK() OVER (ORDER BY COUNT(advertisement.id) DESC) AS top_month
    FROM real_estate.advertisement
    LEFT JOIN real_estate.flats ON flats.id = advertisement.id
    LEFT JOIN real_estate.city ON city.city_id = flats.city_id
    WHERE days_exposition IS NOT NULL
      AND flats.id IN (SELECT * FROM filtered_id)
      AND type_id = 'F8EM'
      AND first_day_exposition BETWEEN '2015-01-01' AND '2018-12-31'
    GROUP BY EXTRACT('month' FROM (first_day_exposition::date + days_exposition::integer))
)
SELECT * FROM first_month
UNION ALL
SELECT * FROM last_month
ORDER BY type_action, count_action DESC;


-- Задача 3: Анализ рынка недвижимости Ленобласти
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS max_total_area,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS max_rooms,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS max_balcony,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS max_ceiling_height,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS min_ceiling_height
    FROM real_estate.flats
),
filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT max_total_area FROM limits)
        AND (rooms < (SELECT max_rooms FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT max_balcony FROM limits) OR balcony IS NULL)
        AND (
            (ceiling_height < (SELECT max_ceiling_height FROM limits) 
             AND ceiling_height > (SELECT min_ceiling_height FROM limits)) 
            OR ceiling_height IS NULL
        )
),
base AS (
    SELECT 
        city.city,
        COUNT(advertisement.id) AS total_ads,
        ROUND(COUNT(advertisement.days_exposition) / COUNT(advertisement.id)::numeric, 2) AS sale_ratio,
        ROUND(AVG(advertisement.last_price / flats.total_area)::numeric, 2) AS avg_metr_price,
        ROUND(AVG(flats.total_area)::numeric, 2) AS avg_area_price,
        COUNT(advertisement.days_exposition) AS total_sales,
        ROUND(AVG(advertisement.days_exposition)::numeric, 1) AS avg_days_exposition
    FROM real_estate.advertisement
    JOIN real_estate.flats ON flats.id = advertisement.id
    JOIN real_estate.city ON city.city_id = flats.city_id
    WHERE flats.id IN (SELECT id FROM filtered_id)
      AND city.city <> 'Санкт-Петербург'
    GROUP BY city.city
    HAVING COUNT(advertisement.id) > 50
),
base_quartiles AS (
    SELECT 
        base.*,
        NTILE(4) OVER (ORDER BY avg_days_exposition) AS quartile
    FROM base
)
SELECT 
    city,
    total_ads,
    sale_ratio,
    avg_metr_price,
    avg_area_price,
    total_sales,
    avg_days_exposition,
    quartile,
    CASE quartile
        WHEN 1 THEN 'Быстро продаются'
        WHEN 2 THEN 'Ниже среднего'
        WHEN 3 THEN 'Выше среднего'
        WHEN 4 THEN 'Медленно продаются'
    END AS days_exposition_category
FROM base_quartiles
ORDER BY city;
