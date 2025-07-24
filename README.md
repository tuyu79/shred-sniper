# 依赖
sniper 应用需要连接 shredstream-proxy, 安装参考 : https://github.com/jito-labs/shredstream-proxy


# 安装 rust 和 node
```shell
# rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash

#注意 nvm 安装后要重新连接会话
nvm install 24.3.0
npm install -g pnpm
npm install -g pm2
```

# 下载仓库
```shell
git clone --recursive https://github.com/tuyu79/shred-sniper.git
cd shred-sniper
```

# 安装 rust build 需要的依赖
```shell
sudo apt-get -y install libssl-dev pkg-config libudev-dev libusb-1.0-0-dev build-essential libhidapi-dev 
```

# 安装 postgres 数据库
```shell
# 安装 postgres
sudo apt install -y postgresql postgresql-contrib
sudo systemctl start postgresql
sudo systemctl enable postgresql
sudo systemctl status postgresql

sudo -i -u postgres
psql
CREATE USER pump WITH PASSWORD 'your password';
GRANT ALL PRIVILEGES ON DATABASE postgres TO pump;
GRANT ALL ON SCHEMA public TO pump;
\q

# 退出当前账户

# 修改 listen_addresses = '*'
sudo vi /etc/postgresql/16/main/postgresql.conf

# 添加 host    all             all             0.0.0.0/0               md5
sudo vi /etc/postgresql/16/main/pg_hba.conf

sudo systemctl restart postgresql
```

# 初始化数据分析表结构

一定要用程序连接时的账号创建,否则会报没有权限

```sql
-- 数据分析表结构
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
```

# 修改 .env 文件
1. shred-sniper-server/analyzer 目录下
   1. 创建 .env 文件,并复制 shred-sniper-server/analyzer/README.md 里面的 env 模板内容
   2. 修改 .env 里面的 username 和 password 为 postgres 的 username 和 password
   3. (可选) 如果有私有 grpc 地址, 可以替换为自己的地址
2. shred-sniper-server/sniper 目录下
   1. 创建 .env 文件,并复制 shred-sniper-server/sniper/README.md 里面的 env 模板内容
   2. 修改一下内容为自己的信息 
      - NONCE_PUBKEY : 钱包的 nonce 账户
      - PRIVATE_KEY : 钱包私钥
      - PUBLIC_KEY : 钱包公钥
      - RPC_ENDPOINTS : solana api rpc 地址
      - YELLOWSTONE_GRPC_URL : grpc 地址
      - JITO_RPC_ENDPOINTS : jito rpc 地址, 用于提交 transaction
      - ZERO_SLOT_RPC_ENDPOINTS : 0slot rpc 地址, 用于提交 transaction
      - JITO_SHRED_URL : jito shredstream proxy 地址
   3. 其他信息后续可以通过 UI 页面调整

# 打包
```shell
cd shred-sniper-server
cargo build --release
cd -

cd shred-sniper-ui
pnpm install
pnpm build
cd -
```

# 启动 analyzer
```shell
cd analyzer
nohup ../target/release/analyzer 2>&1 & disown
cd -
```

# 启动 sniper
```shell
cd sniper 
nohup ../target/release/sniper 2>&1 & disown
cd -
```

# 启动 ui
```shell
cd shred-sniper-ui
pm2 start .output/server/index.mjs --name "sniper-ui"
```