set -e
apt-get update && apt-get install -y curl build-essential ca-certificates git pkg-config
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
. "$HOME/.cargo/env"
rustup install 1.87.0
rustup default 1.87.0
cd /workspace
cargo build --release -p affine_server_native
# copy artifact to expected path
ART=$(find target/release -maxdepth 1 -type f -name "libaffine_server_native*.so" | head -n1)
if [ -z "$ART" ]; then
  echo "Artifact not found" >&2
  exit 1
fi
cp "$ART" packages/backend/native/server-native.arm64.node
