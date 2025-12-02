# Install uv for MCPaaS Development

## Introduction

This executable document installs and verifies the `uv` tool used for Python environment and dependency management in this project. It ensures a consistent workflow for syncing dependencies and running tests.

## Prerequisites

A Linux shell environment with `curl` available is required. Network egress to `astral.sh` must be permitted.

## Setting up the environment

This section defines environment variables used in subsequent steps. Each variable has a default that can be overridden before execution.

```bash
export HASH=$(date +"%y%m%d%H%M")
export UV_INSTALL_URL="https://astral.sh/uv/install.sh"
export UV_BIN_DIR="$HOME/.local/bin"
export UV_PROFILE_FILE="$HOME/.bashrc"
export UV_EXPECTED_MIN_VERSION="0.4.0"
```

Summary: Core variables prepared including a timestamp hash and installation metadata.

## Steps

### Download and install uv

The official installation script is used to install `uv` into the local user bin directory.

```bash
curl -LsSf ${UV_INSTALL_URL} | sh
```

Summary: Installation script executed.

### Ensure PATH contains the uv binary directory

Append the bin directory to PATH if not already present. The change is persisted in the shell profile for future sessions.

```bash
if ! echo "$PATH" | grep -q "$UV_BIN_DIR"; then
  echo "export PATH=\"$UV_BIN_DIR:$PATH\"" >> ${UV_PROFILE_FILE}
  export PATH="$UV_BIN_DIR:$PATH"
fi
```

Summary: PATH updated for current and future shells.

### Verify installation and version

Confirm that the `uv` command exists and meets the minimum version requirement.

```bash
if ! command -v uv >/dev/null 2>&1; then
  echo "uv not found on PATH" >&2
  exit 1
fi
UV_VERSION=$(uv --version | awk '{print $2}')
# Simple semantic version compare (major.minor.patch)
python - <<'PYCODE'
import os,sys
min_req=os.environ.get('UV_EXPECTED_MIN_VERSION','0.0.0')
installed=os.environ.get('UV_VERSION','0.0.0')
from packaging import version
if version.parse(installed) < version.parse(min_req):
    print(f"Installed uv version {installed} is less than required {min_req}")
    sys.exit(1)
print(f"uv version {installed} satisfies minimum {min_req}")
PYCODE
```

Summary: uv presence and version validated.

### Sync development dependencies

Run the sync command within the project directory to create/update the virtual environment.

```bash
cd innovation-engine-mcp
uv sync --group dev
```

Summary: Development dependencies installed.

## Summary

The `uv` tool was installed, added to PATH, version checked against a minimum requirement, and development dependencies were synced for the MCPaaS project.

## Next Steps

Start using the VS Code tasks such as `uv: sync dev deps` or `uv: pytest (verbose)`. If `uv` is still not found, open a new terminal session or source the profile file:

```bash
source ${UV_PROFILE_FILE}
```
