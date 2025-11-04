# MCPaaS - Model Control Protocol as a Service

A comprehensive development and management platform for Model Control Protocol (MCP) servers.

## Overview

MCPaaS provides a user-friendly interface that allows users to easily create, manage, and monitor their MCP servers, including deployment, scaling, and maintenance tasks.

## Key Features

NOTE: this is an early stage project and what is written below reflects goals rather than current status.

- **Easy MCP Server Management**: Streamlined creation and configuration of MCP servers
- **Deployment & Scaling**: Automated deployment and scaling capabilities
- **Monitoring & Maintenance**: Real-time monitoring and maintenance tools
- **User-Friendly Interface**: Intuitive platform for both technical and non-technical users
- **Executable Docs Streaming**: Execute local or arbitrary markdown content through the MCP server without baking files into images (inline content fallback)

## Technologies

- Kubernetes
- Azure
- AI Technologies
- Model Control Protocol (MCP)

## Getting Started

Documentation and guides are available in the `docs/` directory.

### Developer quick start

First we will scaffold a simple MCP server using KMCP:

- Install [KMCP](https://kagent.dev/docs/kmcp/quickstart)
- Work through their quickstart to ensure everything is running well, the quickstart will take you through these steps

  - Scaffold an MCP Server and connect to it locally using MCP Inspector
  - Create a local K8s Cluster with KMCP controller
  - Deploy MCP Server to local K8s cluster and connect to it using MCP Inspector

  ### Unified uv Workflow

  This repository standardizes on `uv` for environment and dependency management within the `innovation-engine-mcp` project. Key points:

  1. Dependencies (including dev/test) defined in `pyproject.toml` under `[dependency-groups]`.
  2. Create or update the environment with `uv sync --group dev`.
  3. Run the MCP server locally: `uv run python src/main.py` from the project directory.
  4. Run tests from anywhere (repo root or project directory) using the helper script:

  ```bash
  scripts/test.sh
  ```

  Or directly:

  ```bash
  cd innovation-engine-mcp
  uv sync --group dev
  uv run pytest -vv
  ```

  Do not manually manage a separate root virtual environment; rely on the per-project `.venv` created by `uv`.

### Operator quick start

Now we will deploy this to production on AKS

- Deploy a remote AKS cluster with KMCP controller
- Deploy MCP Server to AKS and connect to it using MCP Inspector

## Resources

- [mcp-dev-tools](https://github.com/rgardler-msft/mcp-dev-tools) - Development tools for MCP projects

## Project Structure

- `.github/` - GitHub configurations and workflows
- `docs/` - Project documentation
- `src/` - Source code
- `tests/` - Test cases and scripts
