APP_DIR="$HOME/.local/share/USKMaker"
REPO_DIR="$APP_DIR/repo"
VENV_DIR="$APP_DIR/venv"
mkdir -p "$APP_DIR"

export CUDA_VISIBLE_DEVICES=0
export CUDA_DEVICE_ORDER=PCI_BUS_ID
export PYTORCH_CUDA_ALLOC_CONF="expandable_segments:True,garbage_collection_threshold:0.8"
export LD_LIBRARY_PATH="/run/opengl-driver/lib:/run/opengl-driver-32/lib:/usr/lib64:/usr/lib:${LD_LIBRARY_PATH:-}"

if [ -f "/etc/ssl/certs/ca-certificates.crt" ]; then
  export SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt"
elif [ -f "/etc/ssl/certs/ca-bundle.crt" ]; then
  export SSL_CERT_FILE="/etc/ssl/certs/ca-bundle.crt"
fi
export REQUESTS_CA_BUNDLE="${SSL_CERT_FILE:-}"

# Keep Tauri / WebKitGTK on Intel iGPU to reserve full 6GB VRAM for PyTorch AI models
export GDK_BACKEND="wayland,x11"
export QT_QPA_PLATFORM="wayland;xcb"
export WEBKIT_DISABLE_DMABUF_RENDERER=1

configure_sidecar_rescue() {
  find /tmp/audio-separator-models -type f -name "*.ckpt" -size -500M -delete 2>/dev/null || true

  if [ -f "$VENV_DIR/bin/python" ]; then
    uv pip uninstall --python "$VENV_DIR" onnxruntime-gpu 2>/dev/null || true
  fi

  # Force audio-separator Separator to CPU to avoid VRAM OOM collision with WhisperX
  if [ -d "$REPO_DIR/python-sidecar" ]; then
    find "$REPO_DIR/python-sidecar" -type f -name "*.py" -exec sed -i 's/Separator(torch_device="cpu", /Separator(/g' {} + 2>/dev/null || true
    find "$REPO_DIR/python-sidecar" -type f -name "*.py" -exec sed -i 's/Separator(/Separator(torch_device="cpu", /g' {} + 2>/dev/null || true
  fi
}

setup_ai_env() {
  echo "=========================================================="
  echo " Configuring UltraStar Karaoke Maker AI (PyTorch + CUDA 12)"
  echo "=========================================================="
  rm -rf "$VENV_DIR"
  echo "[1/5] Creating Python 3.12 virtualenv..."
  uv venv "$VENV_DIR" --python 3.12

  export VIRTUAL_ENV="$VENV_DIR"
  export PATH="$VENV_DIR/bin:$PATH"

  echo "[2/5] Installing PyTorch with CUDA 12.6 support..."
  uv pip install --python "$VENV_DIR" torch torchaudio torchvision --index-url https://download.pytorch.org/whl/cu126

  echo "[3/5] Installing AI pipeline dependencies (WhisperX, Demucs, SwiftF0, librosa)..."
  if [ -f "$REPO_DIR/python-sidecar/requirements.txt" ]; then
    uv pip install --python "$VENV_DIR" --extra-index-url https://download.pytorch.org/whl/cu126 -r "$REPO_DIR/python-sidecar/requirements.txt"
  else
    uv pip install --python "$VENV_DIR" --extra-index-url https://download.pytorch.org/whl/cu126 whisperx demucs librosa swift-f0 pyphen yt-dlp soundfile numpy scipy
  fi

  uv pip uninstall --python "$VENV_DIR" onnxruntime-gpu 2>/dev/null || true
  uv pip install --python "$VENV_DIR" onnxruntime "audio-separator[cpu]"

  configure_sidecar_rescue

  echo "[4/5] Pre-downloading NLTK tokenizer models (punkt, punkt_tab)..."
  "$VENV_DIR/bin/python" -c "import ssl, nltk; ssl._create_default_https_context = ssl._create_unverified_context; nltk.download('punkt_tab', quiet=True); nltk.download('punkt', quiet=True)" 2>/dev/null || true

  echo "[5/5] Verifying NVIDIA CUDA acceleration:"
  "$VENV_DIR/bin/python" -c "import torch; print('   CUDA Available: ', torch.cuda.is_available()); print('   Device Name:    ', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'CPU (CUDA not detected)')"
  echo "=========================================================="
}

if [ ! -d "$REPO_DIR/.git" ]; then
  echo "Fetching UltraStar Karaoke Maker repository..."
  git clone https://github.com/walterfr/UltraStarKaraokeMaker.git "$REPO_DIR"
fi

if [ "${1:-}" = "--setup-ai" ] || [ "${1:-}" = "setup-ai" ]; then
  shift || true
  setup_ai_env
  exit 0
fi

if [ "${1:-}" = "--update" ] || [ "${1:-}" = "update" ]; then
  shift || true
  echo "Updating UltraStar Karaoke Maker..."
  cd "$REPO_DIR" && git pull || true
  setup_ai_env
  exit 0
fi

if [ "${1:-}" = "--build" ] || [ "${1:-}" = "build" ]; then
  shift || true
  cd "$REPO_DIR" || exit 1
  [ ! -d "node_modules" ] && npm install
  echo "Compiling UltraStar Karaoke Maker release binary via Tauri..."
  npm run tauri build
  exit 0
fi

if [ ! -f "$VENV_DIR/bin/python" ]; then
  setup_ai_env
elif ! "$VENV_DIR/bin/python" -c "import torch; assert torch.cuda.is_available()" 2>/dev/null; then
  echo "CUDA is not active in the existing Python environment. Reinstalling..."
  setup_ai_env
fi

export VIRTUAL_ENV="$VENV_DIR"
export PATH="$VENV_DIR/bin:$PATH"

configure_sidecar_rescue

"$VENV_DIR/bin/python" -c "import ssl, nltk; ssl._create_default_https_context = ssl._create_unverified_context; nltk.download('punkt_tab', quiet=True); nltk.download('punkt', quiet=True)" 2>/dev/null || true

mkdir -p "$REPO_DIR/python-sidecar"
ln -sfn "$VENV_DIR" "$REPO_DIR/python-sidecar/venv"

cd "$REPO_DIR" || exit 1

RELEASE_BIN=$(find "$REPO_DIR/src-tauri/target/release" -maxdepth 1 -type f -executable ! -name "*.so" ! -name "build-script-*" 2>/dev/null | head -n 1 || echo "")
if [ -n "$RELEASE_BIN" ] && [ -x "$RELEASE_BIN" ]; then
  echo "Launching UltraStar Karaoke Maker (NVIDIA CUDA active)..."
  exec "$RELEASE_BIN" "$@"
fi

if [ ! -d "$REPO_DIR/node_modules" ]; then
  echo "Installing frontend dependencies..."
  npm install
fi

echo "Starting UltraStar Karaoke Maker via Tauri (NVIDIA CUDA active)..."
exec npm run tauri dev -- "$@"
