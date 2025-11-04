# Innovation Engine MCP Server - Executable Deployment and Validation Guide

## Introduction

This document describes the end to end process for designing,
implementing, testing, and deploying an MCP server. It is intended to
provide a full End-to-End experience of building and deploying an MCP
Server. In this example we will expose the command line tool
Innovation Engine (IE) via the Model Control Protocol (MCP).

In this example we target read only functionality to reduce compliance
overhead while establishing a secure and observable baseline. Each command
block is parameterized using environment variables for repeatability and
automation. The document proceeds from local development through kind based
ephemeral testing to Azure Kubernetes Service (AKS) deployment.

The objectives are to scaffold the server, implement a minimal execute
operation using a HelloWorld document, validate with MCP Inspector, measure
latency, and prepare for future feature expansion (search, fetch, access
control, audit logging, and performance optimization).

## Executable Documentation

This document is written in executable form. If you have Innovation Engine
installed then you can execute the entire document in unattended mode
with `ie execute docs/IE_MCP_Server.md`, alternatively you can run in
interactive mode with `ie interactive docs/IE_MCP_Server.md`. The latter
mode will work through each section allowing you time to learn about what
is happening.

## Prerequisites

This section outlines required accounts, tools, and permissions. Ensure all
items are satisfied before proceeding. A summary command block is provided
to verify tool versions. Adjust paths or versions as needed for the target
environment.

Prerequisites list:

- Azure subscription with permissions to create Resource Groups, AKS, ACR
- Local workstation with Bash shell
- Installed tools: `az`, `kubectl`, `kmcp`, `docker` (or `nerdctl`), `kind`,
  `jq`, `uv`, `MCPInspector` (GUI or CLI), and Innovation Engine binary (`ie`)
- Network egress to pull container images and reach Azure APIs
- Sufficient local Docker resources (2 CPU, 4 GB RAM) for kind cluster
- Authentication: `az login` already performed prior to running commands

Verification commands (non destructive):

```bash
command -v az kubectl docker kind jq kmcp uv || true
az version --output json | jq '."azure-cli"'
kubectl version --client --output json | jq '.clientVersion.gitVersion'
kmcp --version || true
kind version || true
docker version --format '{{.Server.Version}}' || true
uv --version 2>/dev/null | head -n 1 || echo "uv missing"
command -v ie && ie --help | head -n 3 || echo "Innovation Engine (ie) missing"
```

Summary: All listed tools must be installed and accessible on PATH. Resolve
missing dependencies before moving forward.

## Setting up the environment

This section defines all environment variables used throughout the steps.
Defaults are sensible for a sandbox scenario and may be overridden.

```bash
export WORK_DIR="${WORK_DIR:-$(pwd)}"
export SERVER_NAME="${SERVER_NAME:-innovation-engine-mcp}"            # Logical MCP server name
export MCP_PROJECT_DIR="${MCP_PROJECT_DIR:-$(pwd)/${SERVER_NAME}}"  # Root of KMCP-scaffolded server
```

For convenience lets output these values to the console:

```bash
echo "## Environment Setup"

echo "PWD=$(pwd)"
echo "WORK_DIR=${WORK_DIR}"
echo "SERVER_NAME=${SERVER_NAME}"
echo "MCP_PROJECT_DIR=${MCP_PROJECT_DIR}"
```

Summary: Environment variables are now exported with defaults. Adjust any
values (region, versions, names) as appropriate for the target environment.

## Steps

This section presents discrete, ordered steps. Each subsection introduces
its purpose, provides executable commands, and concludes with a brief
summary of expected outcomes.

### Scaffold MCP server using KMCP

Generate the initial server project structure. If `kmcp scaffold` differs in
syntax across versions, consult KMCP documentation and adjust accordingly.

```bash
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"
kmcp init python "$SERVER_NAME" \
	--description "Innovation Engine MCP Server" \
    --non-interactive

cd $SERVER_NAME
```

<!-- expected_similarity=0.7 -->

```text
  To run the server locally:
  kmcp run local --project-dir /home/user/WORK_DIR/innovation-engine-mcp
✓ Successfully created Python MCP server project: innovation-engine-mcp
```

Summary: A new MCP server scaffold exists under the working directory.

### Add Innovation Engine to the container image

The scaffolded project includes a basic `Dockerfile`. Apply a unified diff patch
to install the Innovation Engine binary (`ie`) during the builder stage and copy
it into the final runtime image. The unified diff format is required by the
`patch` utility.

```bash
DOCKERFILE_PATH="${MCP_PROJECT_DIR}/Dockerfile"

# 1. Make a backup reference if one does not already exist (optional but useful)
cp -n "$DOCKERFILE_PATH" "${MCP_PROJECT_DIR}/Dockerfile.orig" || true

# 2. Create the unified diff patch file
cat > /tmp/ie-dockerfile.patch <<'EOF'
--- Dockerfile.orig	2025-10-24 15:12:01.757290956 -0700
+++ Dockerfile	2025-10-24 15:18:16.593245265 -0700
@@ -1,6 +1,15 @@
 # Multi-stage build for innovation-engine-mcp MCP server using uv
 FROM python:3.11-slim as builder

+# --- Innovation Engine installation (builder stage) ---
+ARG IE_VERSION=latest
+RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
+    && rm -rf /var/lib/apt/lists/* \
+    && curl -fsSL -o /tmp/ie "https://github.com/Azure/InnovationEngine/releases/download/${IE_VERSION}/ie" \
+    && chmod +x /tmp/ie \
+    && install -Dm755 /tmp/ie /usr/local/bin/ie \
+    && echo "Innovation Engine installed to /usr/local/bin/ie"
+
 # Install uv
 COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

@@ -30,6 +39,7 @@

 # Install uv in production
 COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv
+COPY --from=builder /usr/local/bin/ie /usr/local/bin/ie

 # Create non-root user
 RUN groupadd -r mcpuser && useradd -r -g mcpuser mcpuser
@@ -44,7 +54,7 @@
 COPY --from=builder /app/pyproject.toml /app/pyproject.toml

 # Make sure scripts in .venv are usable
-ENV PATH="/app/.venv/bin:$PATH"
+ENV PATH="/app/.venv/bin:/usr/local/bin:$PATH"

 # Install runtime dependencies only
 RUN apt-get update && apt-get install -y \
EOF

# 3. Apply the patch (use -p0 because paths have no leading directories to strip)
patch -p0 < /tmp/ie-dockerfile.patch || true

# 4. Validate presence of key lines
grep -q 'Innovation Engine installation' "$DOCKERFILE_PATH" && \
grep -q 'curl -fsSL -o /tmp/ie' "$DOCKERFILE_PATH" && \
grep -q 'COPY --from=builder /usr/local/bin/ie' "$DOCKERFILE_PATH" && \
grep -q 'ENV PATH="/app/.venv/bin:/usr/local/bin:$PATH"' "$DOCKERFILE_PATH" && \
echo "Innovation Engine patch applied" || echo "Innovation Engine patch missing lines"
```

Summary: The Dockerfile now installs the Innovation Engine binary in the builder
stage and copies it into the final image, enabling the execute tool to invoke
`ie` inside the container.

### Implement minimal execute functionality (scaffold tool)

Add an `execute` tool to the scaffolded project using KMCP. This generates
the boilerplate handler code inside the project directory. Additional logic
to read a HelloWorld document or call Innovation Engine can be added inside
the generated handler file after creation.

```bash
cd "$MCP_PROJECT_DIR"
kmcp add-tool execute
```

<!-- expected_similarity=0.8 -->

```text
✅ Successfully created tool: execute
📁 Generated file: src/tools/execute.py
🔄 Updated tools/__init__.py with new tool import

Next steps:
1. Edit src/tools/execute.py to implement your tool logic
2. Configure any required environment variables in kmcp.yaml
3. Run 'uv run python src/main.py' to start the server
4. Run 'uv run pytest tests/' to test your tool
```

Summary: An `execute` tool skeleton was generated by KMCP inside the server
project, ready for custom business logic.

### Run automated tests for the execute tool

Execute the project's test suite to validate the generated `execute` tool
logic. Add or extend tests under `tests/` to cover new functionality.

```bash
cd "$MCP_PROJECT_DIR"
uv venv
uv pip install pytest pytest-asyncio
uv run pytest tests/ -q
```

<!-- expected_similarity=0.8 -->

```text
...................                                                                                                                                  [100%]
19 passed in 0.61s
```

Summary: Test suite executed using `uv run pytest`; results indicate current
tool correctness baseline.

### Implement the execute tool

The `add-tool` command above created a skeleton for the tool, but it still
needs an actual implementation. The implementation below runs the
`ie execute <DOC_PATH>` command where `<DOC_PATH>` is the path to a document
to be processed by the Innovation Engine CLI. Replace the entire contents
of `./src/tools/execute.py` with the following code block:

```bash
TARGET_FILE="${WORK_DIR}/${SERVER_NAME}/src/tools/execute.py"
cat > "$TARGET_FILE" <<'EOF'
"""Execute tool for IE MCP server.

Enhanced to support executing either:
1. A document available inside the container/image (executableDocPath)
2. Arbitrary markdown/script content provided by the client (content)

If the file path does not exist or is not supplied, but content is provided,
the tool writes the content to a temporary file and executes that instead.
This enables execution of host/local docs without requiring them to be baked
into the container image or mounted as a volume.
"""

import os
import tempfile
import uuid
import subprocess
from core.server import mcp


@mcp.tool()
def execute(executableDocPath: str = "", content: str = "") -> str:
    """Execute an Innovation Engine Executable Document.

    Priority:
    1. If executableDocPath is provided AND exists, use it directly.
    2. Else if content is provided, write to a temp file and execute.
    3. Else return an error describing required parameters.

    Args:
        executableDocPath: Path to the executable document accessible within the runtime.
        content: Raw executable document markdown/script content supplied by client.

    Returns:
        str: Stdout from execution or a descriptive error message.
    """
    # Decide execution target
    target_path = None
    cleanup_path = None

    if executableDocPath and os.path.isfile(executableDocPath):
        target_path = executableDocPath
    elif content:
        # Create temp file for provided content
        try:
            suffix = f"-mcp-exec-{uuid.uuid4().hex[:8]}.md"
            fd, tmp_path = tempfile.mkstemp(suffix=suffix)
            with os.fdopen(fd, "w", encoding="utf-8") as f:
                f.write(content)
            target_path = tmp_path
            cleanup_path = tmp_path
        except Exception as e:  # pragma: no cover - rare filesystem failure
            return f"Error creating temp file for provided content: {e}"
    else:
        return (
            "Error: No valid 'executableDocPath' (file exists) or 'content' provided. "
            "Supply a path inside the runtime or raw document content."
        )

    try:
        command = ["ie", "execute", target_path]
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            timeout=600  # TODO: Make configurable if needed, 600 seconds is too short for some use cases.
        )

        if result.returncode == 0:
            return result.stdout.strip()
        else:
            error_msg = result.stderr.strip() if result.stderr else "Command failed with no error message"
            source_desc = executableDocPath if executableDocPath else "<inline content>"
            return (
                "Error executing 'ie execute' with source '" + source_desc +
                f"' (exit code {result.returncode}): {error_msg}"
            )
    except subprocess.TimeoutExpired:
        return "Error: 'ie execute' command timed out"
    except FileNotFoundError:
        return "Error: 'ie' CLI not found in PATH inside runtime"
    except Exception as e:  # pragma: no cover - catch-all
        return f"Unexpected error executing document: {e}"
    finally:
        if cleanup_path and os.path.isfile(cleanup_path):
            try:
                os.remove(cleanup_path)
            except OSError:
                pass  # Non-fatal cleanup failure
EOF
echo "Wrote execute tool to: $TARGET_FILE"
```

<!-- expected_similarity=0.3 -->

```text
Wrote execute tool to: /home/rogardle/mcp_ie_server/innovation-engine-mcp/src/tools/execute.py
```

Summary: The `execute` tool now shells out to the Innovation Engine CLI and
returns either the command output or a detailed error message, with timeout
and missing binary safeguards.

### Add unit tests for the execute tool

Add unit tests that verify the `execute` tool is discovered and callable.
The tests assume a sample document file at `tests/hello_world.md` containing
the string `Hello, World.`. First, add the `@pytest.mark.unit` decorator to
all existing scaffolded tests in the `tests/` directory, then append the new
execute tool test class. This ensures all unit tests are properly marked for
selective execution:

Add @pytest.mark.unit decorator to all existing test methods in all test files

```bash
cd "$MCP_PROJECT_DIR"
for test_file in tests/test_*.py; do
    sed -i '/^    def test_/i\    @pytest.mark.unit' "$test_file"
done
```

Append the execute tool test class to test_tools.py:

```bash
cd "$MCP_PROJECT_DIR"
cat >> tests/test_tools.py <<'EOF'
class TestExecuteTool:
    """Test the execute tool that runs the IE CLI version command."""

    @pytest.mark.unit
    def test_execute_tool_exists(self) -> None:
        """Test that the execute tool exists and can be loaded."""
        server = DynamicMCPServer(name="Test Server", tools_dir="src/tools")
        server.load_tools()
        assert "execute" in server.loaded_tools

    @pytest.mark.unit
    def test_execute_tool_function(self) -> None:
        """Test that the execute tool function works."""
        server = DynamicMCPServer(name="Test Server", tools_dir="src/tools")
        server.load_tools()
        tools = server.get_tools_sync()
        assert "execute" in tools
        execute_tool = tools["execute"]
        result = execute_tool.fn("tests/hello_world.md")
        assert isinstance(result, str)
        assert result.endswith("Hello, World.")
EOF
```

Summary: The test files now contain unit test validation for discovery and
execution of the `execute` tool using a sample document. All scaffolded tests
(in `test_discovery.py`, `test_server.py`, and `test_tools.py`) and the new
execute tool tests are marked with `@pytest.mark.unit` for selective execution.
However, if we run the tests now they will fail as the `tests\hello_world.md`
document doesn't exist yet.

### Create a sample executable document

Create a `tests/hello_world.md` file used by the execute tool tests. This
file contains a minimal Executable Doc with an inline bash block and an
expected output section. The expected similarity marker can be leveraged by
future harnesses to validate output semantics.

````bash
cd "$MCP_PROJECT_DIR"
cat > tests/hello_world.md <<'EOF'
This is a very simple Executable Doc for testing purposes.

```bash
echo "Hello, World."
```

Expected output:

<!-- expected_similarity=0.8 -->

```text
Hello, World.
```
EOF
````

Summary: The `tests/hello_world.md` file now exists with the required
document content. Re-run the execute tool tests to confirm they pass.

### Configure pytest markers

Register custom pytest markers to avoid warnings about unknown marks. This
configuration file tells pytest about the `unit` and `integration` markers
used to categorize tests.

```bash
cat > $MCP_PROJECT_DIR/pytest.ini <<'EOF'
[pytest]
markers =
    unit: Unit tests that test individual functions in isolation
    integration: Integration tests that test the full system end-to-end
EOF
```

Summary: The `pytest.ini` file registers custom markers, eliminating warnings
and providing documentation for test categories.

### Run unit test suite

Execute the unit test suite to validate the `execute` tool implementation and
associated sample document. These unit tests directly call the Python function
without starting the server process or using the MCP protocol. Passing tests
at this stage indicate a working baseline IE MCP server (scaffold + execute
tool). Rerun selectively when making changes to tool logic.

Run only unit tests (skips integration tests):

```bash
cd "$MCP_PROJECT_DIR"
uv run pytest -v -m unit
```

Expected result: All tests pass (exit code 0). If failures occur, inspect
tracebacks, verify the `ie` CLI availability, ensure the sample document
exists, and confirm the tool registration under `src/tools`.

### Add integration test for STDIO communication

Add an integration test to validate the MCP server can operate over STDIO (no
TCP socket). Unlike the unit tests in step 7, this integration test starts the
full server process and validates end-to-end communication using the MCP
protocol over subprocess stdin/stdout pipes. This approach confirms protocol
correctness, transport layer functionality, and complete request/response
flow. The test will use the `tests/hello_world.md` document created in step 6.

Create the integration test file with the `@pytest.mark.integration` decorator:

```bash
cat > $MCP_PROJECT_DIR/tests/test_integration.py <<'EOF'
"""Integration tests for MCP server STDIO communication."""
import subprocess
import json
import os
import pytest


def send_request(proc, request):
    """Send JSON-RPC request and read response."""
    request_json = json.dumps(request)
    proc.stdin.write(request_json + "\n")
    proc.stdin.flush()

    response_line = proc.stdout.readline()
    if not response_line:
        return None

    return json.loads(response_line)


class TestMCPServerIntegration:
    """Integration tests for full MCP server lifecycle over STDIO."""

    @pytest.mark.integration
    def test_server_stdio_communication(self):
        """Test complete MCP server communication over STDIO transport.

        This test validates:
        1. Server initialization with JSON-RPC handshake
        2. Sending initialized notification
        3. Calling the execute tool with a test document
        4. Validating response format and content
        """
        server_dir = os.getcwd()
        test_doc = os.path.join(server_dir, 'tests', 'hello_world.md')

        proc = subprocess.Popen(
            ["uv", "run", "python", "src/main.py"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,
            cwd=server_dir
        )

        try:
            # Step 1: Initialize
            init_req = {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "initialize",
                "params": {
                    "protocolVersion": "2024-11-05",
                    "capabilities": {},
                    "clientInfo": {"name": "test-client", "version": "1.0.0"}
                }
            }

            init_resp = send_request(proc, init_req)
            assert init_resp is not None, "No response received from initialize"
            assert "error" not in init_resp, f"Initialize failed: {init_resp}"
            assert "result" in init_resp, "Initialize response missing result"

            # Send initialized notification
            initialized_notif = {
                "jsonrpc": "2.0",
                "method": "notifications/initialized"
            }
            proc.stdin.write(json.dumps(initialized_notif) + "\n")
            proc.stdin.flush()

            # Step 2: Call execute tool
            exec_req = {
                "jsonrpc": "2.0",
                "id": 2,
                "method": "tools/call",
                "params": {
                    "name": "execute",
                    "arguments": {
                        "executableDocPath": test_doc
                    }
                }
            }

            exec_resp = send_request(proc, exec_req)
            assert exec_resp is not None, "No response received from tools/call"
            assert "error" not in exec_resp, f"Execute tool call failed: {exec_resp}"

            result = exec_resp.get("result", {})
            assert result, f"Unexpected result format: {exec_resp}"

            # Check response content
            content = result.get("content", [])
            is_error = result.get("isError", False)

            assert not is_error, "Tool execution returned an error"

            if content and len(content) > 0:
                output = content[0].get("text", "")
                assert "Hello, World." in output, f"Output missing expected text: {output}"

        finally:
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait()
EOF
```

Run the integration test:

```bash
cd "$MCP_PROJECT_DIR"
uv run pytest -v -m integration
```

Expected result: Integration test passes, confirming the server correctly
implements MCP STDIO transport. The test output shows the initialize and
execute tool call steps completing successfully.

Summary: The integration test validates STDIO communication by starting the
full server process and performing two key operations: server initialization
(with the required initialized notification) and tool invocation. The test
uses pytest assertions and the `@pytest.mark.integration` decorator to
distinguish it from unit tests. This allows running unit and integration
tests separately or together using pytest markers. Success confirms the
server correctly implements the MCP STDIO transport and the execute tool
works in a complete end-to-end scenario.

## Next Step

We now have a working MCP server for Innovation Engine and we can test it locally using STDIO. The next step is to [deploy this MCP server to a local Kubernetes cluster](IE_MCP_On_K8s.md).
