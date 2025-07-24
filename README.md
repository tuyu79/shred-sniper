# 打包
```shell
cd shred-sniper-server
cargo build --release
cd -

cd shred-sniper-ui
pnpm build
cd -
```

# 启动 analyzer
```shell
cd analyzer
nohup node ../target/release/analyzer 2>&1 & disown
cd -
```

# 启动 sniper
```shell
cd sniper 
nohup node ../target/release/sniper 2>&1 & disown
cd -
```