-- C. Ingredient Optimisation
-- 1. What are the standard ingredients for each pizza?
SELECT 
T.TOPPING_NAME,
COUNT(DISTINCT pizza_id) as appears_on_x_many_pizzas
FROM pizza_recipes as R
LEFT JOIN LATERAL SPLIT_TO_TABLE(toppings,', ') as S
INNER JOIN pizza_toppings as T ON T.topping_id=S.value
GROUP BY T.TOPPING_NAME
HAVING COUNT(DISTINCT pizza_id)=2;

-- 2. What was the most commonly added extra?
SELECT 
T.TOPPING_NAME,
COUNT(order_id) as extras
FROM customer_orders as co
LEFT JOIN LATERAL SPLIT_TO_TABLE(extras,', ') as S
INNER JOIN pizza_toppings as T ON T.topping_id=S.value
WHERE LENGTH(value)>0 AND value<>'null'
GROUP BY T.TOPPING_NAME
ORDER BY COUNT(order_id) DESC
LIMIT 1;

-- 3. What was the most common exclusion?
SELECT 
T.TOPPING_NAME,
COUNT(order_id) as exclusions
FROM customer_orders as co
LEFT JOIN LATERAL SPLIT_TO_TABLE(exclusions,', ') as S
INNER JOIN pizza_toppings as T ON T.topping_id=S.value
WHERE LENGTH(value)>0 AND value<>'null'
GROUP BY T.TOPPING_NAME
ORDER BY COUNT(order_id) DESC
LIMIT 1;

-- 4. Generate an order item for each record in the customers_orders table in the format of one of the following:
    -- Meat Lovers
    -- Meat Lovers - Exclude Beef
    -- Meat Lovers - Extra Bacon
    -- Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers

WITH EXCLUSIONS AS (
    SELECT 
    order_id,
    pizza_id,
    S.value as topping_id,
    T.topping_name
    FROM customer_orders as co
    LEFT JOIN LATERAL SPLIT_TO_TABLE(exclusions,', ') as S
    INNER JOIN pizza_toppings as T on t.topping_id = S.value
    WHERE LENGTH(value)>0 AND value<>'null'
)
,EXTRAS AS (
    SELECT 
    order_id,
    pizza_id,
    S.value as topping_id,
    T.topping_name
    FROM customer_orders as co
    LEFT JOIN LATERAL SPLIT_TO_TABLE(extras,', ') as S
    INNER JOIN pizza_toppings as T on t.topping_id = S.value
    WHERE LENGTH(value)>0 AND value<>'null'
)
,ORDERS AS (
    SELECT DISTINCT
    CO.order_id,
    CO.pizza_id,
    S.value as topping_id
    FROM customer_orders as CO
    INNER JOIN pizza_recipes as PR on CO.pizza_id = PR.pizza_id
    LEFT JOIN LATERAL SPLIT_TO_TABLE(toppings,', ') as S
)
,ORDERS_WITH_EXTRAS_AND_EXCLUSIONS AS (
    SELECT
    O.order_id,
    O.pizza_id,
    CASE 
    WHEN O.pizza_id = 1 THEN 'Meat Lovers'
    WHEN O.pizza_id = 2 THEN pizza_name
    END as pizza, 
    LISTAGG(DISTINCT EXT.topping_name, ', ') as extras,
    LISTAGG(DISTINCT EXC.topping_name, ', ') as exclusions
    FROM ORDERS AS O
    LEFT JOIN EXTRAS AS EXT ON EXT.order_id=O.order_id AND EXT.pizza_id=O.pizza_id
    LEFT JOIN EXCLUSIONS AS EXC ON EXC.order_id=O.order_id AND EXC.pizza_id=O.pizza_id AND EXC.topping_id=O.topping_id 
    INNER JOIN pizza_names as PN on O.pizza_id = PN.pizza_id
    GROUP BY O.order_id,
    O.pizza_id,
    CASE 
    WHEN O.pizza_id = 1 THEN 'Meat Lovers'
    WHEN O.pizza_id = 2 THEN pizza_name
    END
)

SELECT 
order_id,
pizza_id,
CONCAT(pizza, 
CASE WHEN exclusions = '' THEN '' ELSE ' - Exclude ' || exclusions END,
CASE WHEN extras = '' THEN '' ELSE ' - Extra ' || extras END) as order_item
FROM ORDERS_WITH_EXTRAS_AND_EXCLUSIONS
ORDER BY order_id; 
