#!/usr/bin/env bash
set -euo pipefail

# Standard uv-based test runner invoked from repo root.
# Ensures dependencies (including dev group) are synchronized before running tests.

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_DIR="${ROOT_DIR}/innovation-engine-mcp"

cd "$PROJECT_DIR"

# Sync runtime + dev deps
uv sync --group dev

# Run tests with verbose output
uv run pytest -vv
