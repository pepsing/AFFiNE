set -e
apt-get update && apt-get install -y curl build-essential ca-certificates git pkg-config
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
. "$HOME/.cargo/env"
rustup install 1.87.0
rustup default 1.87.0
npm -v
npm i -g @napi-rs/cli@3.0.0-alpha.89
napi -v
napi build --release --strip --no-const-enum
