#!/bin/bash
# Installs the classical PIR engine for SRBench (dev branch).
# Auto-detected by the GitHub Actions workflow via the *_install.sh name.
# No sudo; installs into the active conda env ($CONDA_PREFIX).
#
# Pulls the PUBLIC, torch-free engine pinned at an immutable tag.
set -euo pipefail

PIR_REPO_URL="${PIR_REPO_URL:-https://github.com/Qazi-pk/physics-engine}"
PIR_REF="${PIR_REF:-v0.1.0}"

echo "[PIR install] python: $(which python)"
echo "[PIR install] installing ${PIR_REPO_URL}@${PIR_REF}"

pip install "git+${PIR_REPO_URL}@${PIR_REF}"

# Sanity: import must resolve and expose PIRRegressor.
python -c "from physics_engine.sklearn_adapter import PIRRegressor; print('[PIR install] import OK')"
