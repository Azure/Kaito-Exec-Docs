# Project TODO Register

Preamble:

- Next Available ID: 007
- Classification Quadrants:
  - HI/U: High Impact / Urgent
  - HI/NU: High Impact / Not Urgent
  - LI/U: Low Impact / Urgent
  - LI/NU: Low Impact / Not Urgent

## Priority Matrix

### HI/U

### HI/NU

### [001] Deploy KMCP and Echo MCP Server on AKS

**Status:** open
**Created:** 2025-10-08

#### Description

Provision an Azure Kubernetes Service (AKS) cluster, install the KMCP controller/operator, and deploy the sample Echo MCP server. Validate end-to-end connectivity via MCP Inspector and document the deployment steps for reuse in automation.

Subtasks (optional):

- [x] Define environment variables and resource naming conventions
- [x] Create or select Azure resource group
- [x] Do we need ACR, currently it is an optional step, should we leave it until later?
- [x] Provision AKS cluster (system + user node pools as needed)
- [x] Install KMCP (controller, CRDs) into cluster
- [ ] Scaffold Echo MCP server (using KMCP tooling) if not already present
- [ ] Build and push Echo server container image to ACR
- [ ] Create necessary Kubernetes manifests / KMCP CRs
- [ ] Deploy Echo MCP server to AKS
- [ ] Expose/connect using MCP Inspector (port-forward or ingress)
- [ ] Smoke test Echo server responses
- [ ] Write runbook and teardown instructions

#### Stakeholders

Platform Engineering, SRE, AKS Admin

#### Notes

Default priority (HI/NU) applied. Aim to later automate with GitHub Actions workflow and IaC (Bicep/Terraform). Ensure least-privilege for ACR pull.

#### Acceptance Criteria

- Echo MCP server reachable via MCP Inspector against AKS deployment
- KMCP components healthy (no CrashLoopBackOff) and required CRDs installed
- Documentation includes prerequisites, commands, and validation steps
- Runbook covers deploy, verify, update, and teardown

### [003] Deploy Open-WebSearch MCP Server (multi-engine web search) on Local K8s Cluster

**Status:** In Progress
**Created:** 2025-10-30

#### Description

Integrate and deploy the Apache-2.0 licensed Open-WebSearch MCP server (multi-engine web search without API keys) into the MCPaaS platform. Provide standardized access for agents to perform multi-engine search and article/content retrieval (CSDN, Linux.do, GitHub README, Juejin) via MCP tools. Ensure secure configuration, environment variable management, and optional proxy support. Produce deployment artifacts (local, Docker, KMCP, AKS) and operational documentation (rate limits, legal/usage constraints, monitoring/alerting integration).

Subtasks (optional):

- [x] Create a local K8s cluster using Kind
- [x] Install KMCP CRDs
- [x] Clone OpenWebSearch Repo
- [x] Create KMCP scaffold wrapper if required (or validate direct MCP usage via npx)
- [x] Implement container build (Dockerfile / compose alignment) for MCPaaS baseline
- [x] Implement configuration profiles (stdio, http, streamableHttp, sse)
- [x] Add environment variable policy & defaults (ALLOWED_SEARCH_ENGINES, PROXY_URL, DEFAULT_SEARCH_ENGINE)
- [ ] Integrate secrets & proxy configuration (USE_PROXY gating, CORS settings)
- [x] Local run validation (npx, node build output, search tool basic query)
- [x] Tool invocation tests: search, fetchCsdnArticle, fetchLinuxDoArticle, fetchGithubReadme, fetchJuejinArticle
- [x] Add MCP client config examples (Cherry Studio, VS Code, NPX Command Line, SSE)
- [ ] Performance baseline (p50 latency, memory footprint under concurrent searches)
- [ ] Implement rate limiting / backoff strategy (document approach)
- [ ] Logging & audit integration (structure: query, engines, result count, user)
- [ ] Error handling strategy (engine failure, proxy unreachable, parsing errors)
- [ ] Add monitoring dashboard metrics (search_count, error_rate, latency buckets)
- [ ] AKS deployment manifests / KMCP CR adjustments (image reference, ports, mode)
- [ ] Security review (scraping practices, legal constraints, user guidance)
- [ ] Documentation: deployment guide + usage limitations + configuration matrix
- [ ] Acceptance tests (automated scripted queries & content fetch validations)
- [ ] Publish image & update MCPaaS registry/catalog entry
- [ ] Final readiness review & close task

#### Notes

Execute the Doc with `ie execute docs/OpenWebSearch_On_K8s.md`

To clean the envirnment of earlier runs use `ie clear-env --force; kind get clusters | xargs -r -I {} kind delete cluster --name {}`

Source: https://github.com/Aas-ee/open-webSearch (TypeScript, Apache-2.0). Supports multi-engine search (bing, duckduckgo, exa, brave, baidu, csdn, juejin; linux.do temporarily unsupported). No API keys required (HTML scraping). Must clarify rate limiting and legal usage constraints before production exposure. Consider fork for controlled updates versus tracking upstream main directly. Evaluate need for restricting engines via ALLOWED_SEARCH_ENGINES. Add optional proxy support for region restrictions (USE_PROXY, PROXY_URL). SSE endpoint available; may integrate streamableHttp and SSE transports. Confirm KMCP compatibility when packaging.

#### Acceptance Criteria

- MCP server deployable via KMCP and accessible over configured transport modes (stdio/http/streamableHttp/SSE)
- All advertised tools registered: search, fetchLinuxDoArticle, fetchCsdnArticle, fetchGithubReadme, fetchJuejinArticle
- Successful multi-engine search returning structured results (title, url, description, source/engine) for sample queries
- Content fetch tools return readable article/README content for representative sources
- Configurable default and allowed search engines enforced (invalid engine requests rejected or normalized)
- Proxy configuration (USE_PROXY/PROXY_URL) functional and documented
- Rate limiting guidance documented; basic throttling/backoff implemented or justified
- Observability: logs with query + engine set + result count; metrics exported for search_count, error_rate, latency
- Security & legal usage notes published (personal use limitation, scraping constraints)
- Automated test suite covers each tool (happy path + error path) and environment variable config matrix
- Deployment docs (local npx, container, AKS/KMCP) published in `docs/`
- Image published to registry and referenced in KMCP CR manifest

### [002] MCP Server to provide access to Innovation Engine

**Status:** open
**Created:** 2025-10-09

#### Description

Design and deploy an MCP server that exposes the internal "Innovation Engine"
capabilities (idea indexing, vector similarity search, experiment metadata)
through a standardized MCP interface. This enables AI agents and tooling to
query, retrieve, and act on innovation artifacts programmatically while
enforcing access controls and auditability.

Subtasks (optional):

- [x] Install IE and ensure it is on PATH
- [x] Implement server scaffolding using KMCP
- [x] Implement execute functionality using a simple HelloWorld.md document
- [x] Test locally using the CLI over stdio
- [x] Test locally using MCPInspector
- [x] Deploy to kind cluster
- [ ] Test locally over http
- [ ] Deploy to AKS hosted MCPaaS
- [ ] Test remotely over http
- [ ] Documentation (IE_MCP_server.md) covering each of the steps here

#### Notes

This is working to the point of deployment but failing to pass the test. To reproduce the error do `ie clear-env --force; kind get clusters | xargs -r -I {} kind delete cluster --name {}; ie execute docs/IE_MCP_On_K8s.md`

#### Acceptance Criteria

- Server returns successful responses for defined search and fetch operations
- Access control rules enforced per user/agent identity (no unauthorized data)
- Latency p50 < 300ms for standard search queries (baseline region)
- Audit log captures each operation with principal and timestamp
- Documentation includes resource list, sample requests, and error handling

### [006] Fine-Tune Phi-3 Mini (QLoRA) on AKS via KAITO Exec Doc

**Status:** open
**Created:** 2025-11-20

#### Description

Author an executable documentation (Exec Doc) that guides users through
fine-tuning the `Phi-3-mini-128k-instruct` (or successor `Phi-4-mini` if
available) model on AKS using the KAITO AI toolchain operator with the
QLoRA method. The doc will cover environment setup, GPU quota checks,
add-on enablement verification, workspace tuning specification, dataset
ingestion (e.g. Dolly 15k), monitoring tuning progress, producing and
pushing an optimized image, validating inference quality, and cleanup.
All commands parameterized via environment variables and structured in
the standard Exec Doc sections (Introduction, Prerequisites, Setting up
the environment, Steps, Summary, Next Steps) with `HASH` uniqueness.

Subtasks (optional):

- [ ] Create new exec doc file `docs/incubation/Fine_Tune_Phi_3_On_AKS_With_Kaito.md`
- [ ] Define environment variables (HASH, LOCATION, SUBSCRIPTION_ID,
      RESOURCE_GROUP, AKS_CLUSTER_NAME, WORKSPACE_NAME, MODEL_NAME,
      TUNING_METHOD, DATASET_URL, SECONDARY_DATASET_URL, REGISTRY_NAME,
      REGISTRY_SERVER, OUTPUT_IMAGE_REPO, OUTPUT_IMAGE_TAG, GPU_SKU,
      KAITO_VM_SIZE, IDENTITY_NAME) with sensible defaults
- [ ] Add GPU quota and SKU availability pre-flight check block
- [ ] Add Azure CLI version gate (reuse existing logic) and tools check
- [ ] Insert KAITO add-on enablement verification block (non-mutating)
- [ ] Author workspace tuning YAML (tuning.method=qlora, input dataset
      URLs, output.image, instanceType=${KAITO_VM_SIZE}) via heredoc
- [ ] Implement readiness and tuning phase polling loops with status
      condition parsing
- [ ] Add verification section: workspace status, image presence in ACR,
      sample inference prompt quality comparison (pre vs post tuning)
- [ ] Include expected_similarity tests for major bash blocks
- [ ] Provide timing/cost guidance and estimated GPU hour calculation
- [ ] Add cleanup section (delete workspace, images, resource group opt)
- [ ] Cross-link from existing KAITO install doc and README
- [ ] Add dataset licensing and responsible AI notes
- [ ] Update changelog (if present) referencing new exec doc
- [ ] Final review for line length <=80 and style compliance

#### Stakeholders

Platform Engineering, AI/ML, Documentation, Governance/Compliance

#### Notes

Reference blog source: Roy Kim fine-tuning series (external).
Source (Part 1 Intro): https://roykim.ca/2025/01/11/deep-dive-into-fine-tuning-an-lm-using-kaito-on-aks-part-1-intro/
Ensure
dataset license (Dolly 15k) acknowledged. Consider optional switch to
`Phi-4-mini` once stable. Include guardrails for large dataset sizes and
quota escalation steps. Provide fallback path when `jq` is missing.
Document that QLoRA reduces VRAM usage; mention alternative methods
(full fine-tune, LoRA) with trade-offs. Avoid hard-coding regions.

#### Acceptance Criteria

- New exec doc file exists with required structured sections
- All environment variables documented with defaults and uniqueness
- GPU quota and SKU checks run successfully and produce actionable
  messages on failure
- Workspace tuning YAML applied and reaches Succeeded (or Completed)
  status for tuning phase
- Output image built, tagged `${OUTPUT_IMAGE_REPO}:${OUTPUT_IMAGE_TAG}`
  and pushed to `${REGISTRY_SERVER}`
- Inference test after tuning shows qualitative improvement (example
  prompt comparison captured) and is reproducible
- Verification section runs end-to-end without mutation except where
  explicitly stated
- Expected similarity tests present for at least: env var export block,
  quota/SKU check, workspace YAML creation/apply, readiness polling,
  verification script
- Cleanup instructions validated (no orphaned GPU nodes or images)
- Cross-links added (KAITO install doc + README) and no broken references
- Line width adherence, no em dashes, consistent indentation

#### Priority

HI/NU (High Impact / Not Urgent) - foundational advanced KAITO scenario
that unlocks model adaptation workflows.

#### Risks

- GPU quota insufficiency causing tuning delays
- Dataset license misuse if not clarified
- Image push failures due to ACR auth or naming conflicts
- Long-running tuning incurring unexpected cost (need early abort path)

#### Mitigations

- Pre-flight quota/SKU checks and escalation guidance
- License note and link to dataset terms
- `az acr login` validation and unique tagging with `_${HASH}` suffix
- Poll loop with max duration + user notice for early stop procedure

#### Success Metrics

- Exec doc executes successfully in two regions (e.g. eastus, westus3)
- Tuning completes within documented expected time window
- Post-tuned model yields higher relevance score or reduced hallucination
  rate in sample evaluation (qualitative + optional quantitative metric)
- Positive internal adoption (tracked via follow-up tasks or feedback)

### LI/U

### LI/NU

### [004] Extract AKS Dynamic VM Size Selection into Reusable Executable Doc

**Status:** In Progress
**Created:** 2025-10-30

#### Description

Create a dedicated executable documentation file (`docs/AKS_VM_Size_Selection.md`) that encapsulates the dynamic Azure AKS VM size (SKU) pre-flight selection and quota validation logic currently embedded in the troubleshooting section of `docs/OpenWebSearch_On_K8s.md`. The outcome is a reusable, parameterized script and guidance that other MCP server deployment docs can source or link to—reducing duplication, improving maintainability, and standardizing cluster creation resilience across regions and quota conditions.

Subtasks (optional):

- [x] Identify and extract the existing troubleshooting + dynamic SKU helper logic segments from `OpenWebSearch_On_K8s.md` (initial extraction complete; original doc still contains block pending replacement link)
- [x] Design new exec doc sections (Introduction, Prerequisites, Setting up the environment, Steps, Summary, Next Steps)
- [x] Define environment variables (LOCATION, NODE_ARCH, PREFERRED_SKUS, FALLBACK_SKUS, NODE_COUNT, INCLUDE_BURSTABLE, QUOTA_SAFETY_MARGIN, HASH) with sensible defaults
- [x] Implement consolidated pre-flight script (single `az vm list-skus` call when `jq` present; fallback per-SKU queries otherwise)
- [x] Add quota evaluation (regional vCPUs vs projected) and selection algorithm explanation
- [x] Provide optional ARM vs AMD64 candidate lists and justification comments (allocation guidance link)
- [ ] Include output examples for success, fallback, and failure cases
- [x] Add guidance for when no viable SKU found (quota increase, region change, reduce node count) (expand beyond inline error message)
- [x] Update `OpenWebSearch_On_K8s.md` to replace embedded troubleshooting block with a concise reference link
- [x] (Optional) Update `IE_MCP_On_K8s.md` to reference the new exec doc for consistency
- [x] Document environment variable matrix and override examples (table or bullet matrix)
- [ ] Verify doc passes execution end-to-end in at least two regions (e.g., eastus, westus3)
- [ ] Final review and mark task complete

#### Stakeholders

- Platform Engineering
- SRE / Observability
- AKS Administration
- Documentation / Developer Experience

#### Notes

Rationale: Centralizing dynamic SKU selection reduces repetitive troubleshooting across deployment docs and encourages consistent capacity mitigation (diversified SKUs, burstable fallback, ARM/AMD64 differentiation). Source logic currently in `docs/OpenWebSearch_On_K8s.md` Step 4 (post-create troubleshooting section). Consider aligning naming with `Create_MCP_AKS_Cluster.md` if overlapping logic evolves. Ensure legal and performance disclaimers retained (quota variance, ephemeral availability). Provide hyperlink: http://aka.ms/allocation-guidance.

Progress 2025-10-30: Created `docs/AKS_VM_Size_Selection.md` with dynamic selection script (supports ARM/AMD64, fallback regions, burstable toggle, quota margin, JSON output, DRY_RUN). Remaining work includes trimming original troubleshooting block to a reference link, adding output examples, explicit remediation guidance section, test harness snippet, and multi-region execution validation.

#### Acceptance Criteria

- New exec doc `docs/AKS_VM_Size_Selection.md` exists with required structured sections
- Environment variables documented with defaults and uniqueness via HASH where required
- Script selects first viable SKU (available + within quota) or outputs actionable remediation steps
- Works with and without `jq` installed (performance optimization path + fallback path)
- Demonstrates ARM and AMD64 candidate list examples; includes burstable fallback toggle
- Includes sample output blocks for success, fallback, and failure scenarios
- Existing `OpenWebSearch_On_K8s.md` references new doc (embedded logic removed or significantly reduced)
- (Optional) `IE_MCP_On_K8s.md` updated to reference the new doc (if cluster creation logic present)
- Shell lint (manual or shellcheck) notes included or no critical warnings
- Changelog updated with addition entry

### [005] Web Seatch MCP Server on AKS cluster

**Status:** In Progress
**Created:** 2025-10-09

#### Description

Design and deploy an MCP server that exposes the internal "Open Web Search"
MCP Server through a standardized MCP interface. This enables AI agents and tooling to
query, retrieve, and act on Web content programmatically.

Subtasks (optional):

- [ ] Implement server scaffolding using KMCP
- [ ] Implement execute functionality using a simple HelloWorld.md document
- [ ] Test locally using the CLI over stdio
- [ ] Test locally using MCPInspector
- [ ] Deploy to kind cluster
- [ ] Test locally over http
- [ ] Deploy to AKS hosted MCPaaS
- [ ] Test remotely over http
- [ ] Documentation (IE_MCP_server.md) covering each of the steps here

#### Notes

This is working to the point of deployment but failing to pass the test. To reproduce the error do `ie clear-env --force; kind get clusters | xargs -r -I {} kind delete cluster --name {}; ie execute docs/OpenWebSearvh_On_K8s_Local.md`

#### Acceptance Criteria

- Server returns successful responses for defined search and fetch operations
- Access control rules enforced per user/agent identity (no unauthorized data)
- Latency p50 < 300ms for standard search queries (baseline region)
- Audit log captures each operation with principal and timestamp
- Documentation includes resource list, sample requests, and error handling

## Completed Items Archive

_(empty)_

## Rejected Items Archive

_(empty)_

## Changelog

- 2025-10-08: [001] Deploy KMCP and Echo MCP Server on AKS — added to TODO register (HI/NU).
- 2025-10-09: [002] MCP Server to provide access to Innovation Engine — added to TODO register (HI/NU).

---

## Canonical TODO Item Template

### [ID] Short Actionable Title

**Status:** open | closed | rejected | In Progress
**Created:** YYYY-MM-DD

#### Description

(Clear problem / outcome statement)

Subtasks (optional):

- [ ] Step 1
- [ ] Step 2

#### Notes

(Context, links, decisions, progress made)

#### Acceptance Criteria

- First thing that must be true for this task to be complete
- Second thing that must be true for this task to be complete
