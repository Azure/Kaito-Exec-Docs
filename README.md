# End-to-End AI on AKS with KAITO

This repository is a playground for **end-to-end KAITO workloads on AKS**, built around **Executable Docs** – self-testing markdown playbooks that take you from an empty subscription to a running, app-ready model endpoint.

Alongside the KAITO flows, it also contains an experimental **MCPaaS (Model Control Protocol as a Service)** component, allowing Executable Docs and KAITO workflows to be exposed through an MCP server.

## Overview

The core goal of this repo is simple: **ship AI, not just clusters**.

- Focus on **full E2E AI workloads on AKS with KAITO**, not just operator install.
- Make it easy to go from **GPU quota checks → AKS + KAITO platform → workspace + model → app-facing endpoint**.
- Capture those journeys as **Executable Docs** so they are **repeatable, testable, and safe to rerun**.

The MCPaaS pieces are complementary: they explore how to surface these same flows via an MCP server, so tools like MCP Inspector (or Copilot-compatible clients) can orchestrate KAITO workflows.

## Why E2E Matters

Teams don’t just want “KAITO installed” – they want:

- A **real application online**, doing work against a KAITO-backed endpoint.
- A **repeatable path** from idea → demo → production.
- Confidence they can **get back** to that state later.

Executable Docs encode these end-to-end stories as the **contract between platform and app teams**, dramatically reducing time-to-first-success and making KAITO on AKS accessible beyond a tiny expert niche.

## KAITO AI Workload Deployment Workflow

Deploy AI models on AKS using KAITO with this three-phase approach, driven by Executable Docs in the `docs/` folder:

**Phase 1: Pre-Flight Validation (Optional)**

- Run `docs/Check_VM_Quota.md` to validate GPU quota in your subscription.
- Ensures you have sufficient NC-series or ND-series VM quota.
- Provides remediation steps if quota is insufficient.

**Phase 2: Platform Installation (One-time)**

- Run `docs/Install_Kaito_On_AKS.md` to set up KAITO on your AKS cluster.
- Installs KAITO workspace controller.
- Configures GPU Provisioner with workload identity.
- Results in a KAITO-ready cluster (no models deployed yet).

**Phase 3: Model Deployment (Repeatable)**

- Run `docs/incubation/Deploy_Kaito_Workspace.md` to deploy AI models.
- Creates workspace custom resources for specific models.
- Triggers automatic GPU node provisioning.
- Exposes OpenAI-compatible inference endpoints.
- Can be repeated for multiple models on the same cluster.

**Advanced Workflows**

- `docs/incubation/Deploy_Additional_Model_Workspaces_on_Kaito.md` – multi-model patterns.
- `docs/incubation/Deploy_RAG_On_Kaito_AKS.md` – retrieval-augmented generation.
- `docs/incubation/Configure_Diagnostics_for_Kaito.md` – monitoring and diagnostics.

## MCPaaS: Executable Docs via MCP

The **MCPaaS** concept in this repo explores how to:

- Expose KAITO and infrastructure workflows as an **MCP server**.
- Stream **Executable Docs** (local or remote markdown) through MCP without baking them into images.
- Enable tools like MCP Inspector to drive KAITO flows as **structured tools**.

This is experimental and early-stage, but it sketches a path where platform workflows, KAITO, and MCP tools all meet.

## Technologies

- Azure Kubernetes Service (AKS)
- KAITO (AI toolchain operator)
- Executable Docs (self-testing markdown workflows)
- Kubernetes
- Azure
- Model Control Protocol (MCP)

## Getting Started

Documentation and guides are available in the `docs/` directory. A good starting sequence is:

1. `docs/Create_AKS.md` – create a suitable AKS cluster.
2. `docs/Check_VM_Quota.md` – validate GPU quota.
3. `docs/Install_Kaito_On_AKS.md` – install KAITO on your AKS cluster.
4. `docs/incubation/Deploy_Kaito_Workspace.md` – deploy a KAITO workspace and model.

Once you have a stable, testable KAITO endpoint, you can build applications (chat, RAG, agents, vision, streaming, etc.) on top.

## MCP Server (innovation-engine-mcp) – Developer Quick Start

The `innovation-engine-mcp/` folder contains an experimental MCP server that can be used to surface KAITO and Executable Doc workflows.

First, scaffold and validate a simple MCP server using KMCP:

- Install [KMCP](https://kagent.dev/docs/kmcp/quickstart).
- Work through the KMCP quickstart to ensure everything is running:
  - Scaffold an MCP server and connect to it locally using MCP Inspector.
  - Create a local Kubernetes cluster with the KMCP controller.
  - Deploy an MCP server to the local cluster and connect to it using MCP Inspector.

### Unified `uv` Workflow

This repository standardizes on `uv` for environment and dependency management within the `innovation-engine-mcp` project. Key points:

1. Dependencies (including dev/test) are defined in `pyproject.toml` under `[dependency-groups]`.
2. Create or update the environment with `uv sync --group dev`.
3. Run the MCP server locally from the project directory:

   ```bash
   cd innovation-engine-mcp
   uv run python src/main.py
   ```

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

## Operator Quick Start (AKS + MCP)

For operators who want to run the MCP server alongside KAITO on AKS:

- Deploy a remote AKS cluster with the KMCP controller.
- Deploy the MCP server to AKS and connect to it using MCP Inspector.
- Use Executable Docs to validate KAITO and cluster readiness, then layer MCP-based automation on top.

## Resources

- [mcp-dev-tools](https://github.com/rgardler-msft/mcp-dev-tools) – development tools for MCP projects.

## Project Structure (High Level)

- `docs/` – Executable Docs for KAITO, AKS, and related workflows.
- `innovation-engine-mcp/` – experimental MCP server implementation.
- `aks-mcp/` – Go-based tooling and charts for AKS MCP scenarios.
- `open-webSearch/` – Open WebSearch MCP server and related assets.
- `presentations/` – slide decks (including KAITO deployment narratives).
- `scripts/` – helper scripts (e.g., test runner).
