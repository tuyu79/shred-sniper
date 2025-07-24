-- 狗庄数据分析表结构
CREATE TABLE public.token_states
(
    token_creator          text,
    token_address          text,
    dev_initial_buy        bigint,
    dev_profit             double precision,
    dev_holding_start_time bigint,
    dev_holding_duration   bigint
);

CREATE TABLE public.token_trades
(
    id            integer NOT NULL,
    token_address text    NOT NULL,
    useraddr      text    NOT NULL,
    is_buy        boolean NOT NULL,
    sol_amount    bigint  NOT NULL,
    token_amount  bigint  NOT NULL,
    timestamp     bigint  NOT NULL,
    CONSTRAINT token_trades_pkey PRIMARY KEY (id)
);

CREATE INDEX idx_token_trades_token_address ON public.token_trades USING btree (token_address);
CREATE INDEX idx_token_trades_useraddr ON public.token_trades USING btree (useraddr);

-- 序列（用于 id 字段自增，若表创建时已自动关联序列，可根据实际情况确认是否需要单独创建）
CREATE SEQUENCE public.token_trades_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.token_trades_id_seq OWNED BY public.token_trades.id;

ALTER TABLE ONLY public.token_trades
    ALTER COLUMN id SET DEFAULT nextval('public.token_trades_id_seq'::regclass);


-- 狗庄数据分析 sql
SELECT COUNT(DISTINCT token_creator) AS total_creators
FROM token_states;

SELECT COUNT(DISTINCT token_address) AS total_tokens
FROM token_states;

WITH token_stats AS (SELECT token_creator,
                            COUNT(DISTINCT token_address)                                                      AS token_count,
                            CAST(AVG(dev_holding_duration) AS FLOAT8)                                          AS avg_holding_seconds,
                            CAST(SUM(dev_profit) AS FLOAT8)                                                    AS total_profit_sol,
                            SUM(CASE WHEN dev_holding_duration <= 5 THEN 1 ELSE 0 END)                         AS hold_less_5_sec_count,
                            SUM(CASE WHEN dev_holding_duration > 5 THEN 1 ELSE 0 END)                          AS hold_greater_5_sec_count,
                            SUM(CASE
                                    WHEN dev_holding_duration > 5 AND dev_holding_duration < 10 THEN 1
                                    ELSE 0 END)                                                                AS mid_hold_count,
                            MIN(dev_holding_duration)                                                          AS min_holding_seconds,
                            CAST(SUM(CASE WHEN dev_profit > 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS FLOAT8) AS win_rate,
                            MAX(dev_holding_start_time)                                                        AS latest_trade_time,
                            CAST(SUM(CASE WHEN dev_profit > 0 THEN dev_profit ELSE 0 END) AS FLOAT8)           AS positive_dev_profit,
                            CAST(SUM(CASE WHEN dev_initial_buy > 0 THEN dev_initial_buy ELSE 0 END) AS BIGINT) AS positive_dev_initial_buy
                     FROM token_states
                     WHERE dev_profit IS NOT NULL
                       AND dev_initial_buy IS NOT NULL
                     GROUP BY token_creator),
     user_counts AS (SELECT ts.token_creator,
                            CAST(AVG(uc.user_count) AS FLOAT8) AS avg_users_per_token
                     FROM token_states ts
                              JOIN (SELECT token_address,
                                           COUNT(DISTINCT useraddr) AS user_count
                                    FROM token_trades
                                    GROUP BY token_address) uc ON ts.token_address = uc.token_address
                     GROUP BY ts.token_creator),
     top3_buyers_avg AS (SELECT token_creator,
                                AVG(top3.sol_total / 1000000000.0) AS avg_top3_buy
                         FROM (SELECT ts.token_creator,
                                      ts.token_address,
                                      SUM(tr.sol_amount) AS sol_total
                               FROM token_states ts
                                        JOIN (SELECT token_address,
                                                     sol_amount,
                                                     ROW_NUMBER() OVER (PARTITION BY token_address ORDER BY timestamp ASC) AS rn
                                              FROM token_trades
                                              WHERE is_buy = TRUE) tr ON ts.token_address = tr.token_address
                               WHERE tr.rn <= 3
                               GROUP BY ts.token_creator, ts.token_address) top3
                         GROUP BY token_creator)
SELECT ts.*,
       CAST((ts.positive_dev_profit / (ts.positive_dev_initial_buy / 1000000000.0)) * 100 AS FLOAT8) AS profitability,
       COALESCE(uc.avg_users_per_token, 0)                                                           AS avg_users_per_token,
       CAST(COALESCE(tb.avg_top3_buy, 0) AS FLOAT8)                                                  AS avg_top3_buy_per_token
FROM token_stats ts
         LEFT JOIN user_counts uc ON ts.token_creator = uc.token_creator
         LEFT JOIN top3_buyers_avg tb ON ts.token_creator = tb.token_creator
WHERE avg_holding_seconds > 5
  AND total_profit_sol > 0.1
  AND token_count > 1
  AND mid_hold_count <= 5
  AND hold_less_5_sec_count <= 10
  AND min_holding_seconds >= 5
  AND avg_users_per_token >= 10
  AND COALESCE(tb.avg_top3_buy, 0) >= 1
ORDER BY total_profit_sol DESC;

