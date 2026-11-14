set -euo pipefail
{
  sudo apt-get -o Acquire::Retries=2 update -qq &&
  sudo apt-get -o Acquire::Retries=2 install -y xvfb libgl1-mesa-dri libglx-mesa0 python3-venv &&
  curl -fL --retry 3 -o "$LUMO_DISCOVERY_ROOT/engine/godot.zip" \
    https://github.com/godotengine/godot/releases/download/4.6.3-stable/Godot_v4.6.3-stable_linux.x86_64.zip &&
  printf '%s  %s\n' d0bc2113065e481c9c2c2b2c37daa4e8be3fe9e27f0ab9ab0b6096e9a37907f3 \
    "$LUMO_DISCOVERY_ROOT/engine/godot.zip" | sha256sum -c - &&
  unzip -q "$LUMO_DISCOVERY_ROOT/engine/godot.zip" -d "$LUMO_DISCOVERY_ROOT/engine/bin" &&
  ln -s "$LUMO_DISCOVERY_ROOT/engine/bin/Godot_v4.6.3-stable_linux.x86_64" "$GODOT_BIN" &&
  "$GODOT_BIN" --version > "$LUMO_DISCOVERY_EVIDENCE_DIR/source/engine.txt" &&
  cat "$LUMO_DISCOVERY_EVIDENCE_DIR/source/engine.txt" &&
  test "$(cat "$LUMO_DISCOVERY_EVIDENCE_DIR/source/engine.txt")" = 4.6.3.stable.official.7d41c59c4 &&
  python3 -m venv "$LUMO_DISCOVERY_ROOT/venv" &&
  "$LUMO_DISCOVERY_PYTHON" -m pip install --disable-pip-version-check --no-cache-dir Pillow==12.3.0 &&
  "$LUMO_DISCOVERY_PYTHON" --version &&
  "$LUMO_DISCOVERY_PYTHON" -c 'import PIL; print("Pillow " + PIL.__version__); assert PIL.__version__ == "12.3.0"' &&
  command -v xvfb-run &&
  printf '%s\n' "$LUMO_DISCOVERY_ROOT/engine/bin" "$LUMO_DISCOVERY_ROOT/venv/bin" >> "$GITHUB_PATH"
} 2>&1 | tee "$LUMO_DISCOVERY_EVIDENCE_DIR/setup.log"
