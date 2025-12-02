# MCPaaS Project Tracker

**Last Updated:** 2025-12-02  
**Project Phase:** Early Stage Development  
**Overall Status:** Active Development - Foundation work progressing well

---

## Executive Summary

MCPaaS is building a comprehensive platform for developing, managing, and deploying Model Context Protocol (MCP) servers with focus on Azure Kubernetes Service integration. The project has three main MCP server implementations at different maturity levels: a production-ready AKS-MCP (Go), an experimental innovation-engine-mcp (Python/FastMCP), and an integrated open-webSearch server (TypeScript). Current focus is on validating deployment patterns, executable documentation framework, and establishing operational baselines before platform expansion.

### Current Sprint Focus

- Open-WebSearch AKS deployment completed and promoted to main docs
- ACR deployment documentation completed and stress-tested
- Multiple KAITO exec docs created (Install, Workspace, RAG, diagnostics)
- Next: Begin demonstration videos and chat app integration
- Next: Resolve IE MCP remote deployment issues

### Key Risks

1. **Scope Ambiguity** - PRD describes full managed platform but current development is experimental/validation phase
2. **IE MCP Deployment Failures** - IE MCP working locally but failing remote K8s validation (needs investigation)
3. **Documentation Volume** - Rapid exec doc creation needs testing/validation cadence to prevent drift

---

## Task Summary

|    ID | Task                                 | Status      | Priority | Dependencies        | Responsible          | Updated    |
| ----: | ------------------------------------ | ----------- | -------- | ------------------- | -------------------- | ---------- |
| 1.1.1 | Deploy KMCP & Echo MCP Server on AKS | in-progress | High     | None                | Platform Engineering | 2025-12-01 |
| 1.1.2 | Innovation Engine MCP Server         | blocked     | High     | None                | Platform Engineering | 2025-12-01 |
| 1.1.3 | Open-WebSearch on Local K8s          | in-progress | High     | None                | Platform Engineering | 2025-12-01 |
| 1.1.4 | Open-WebSearch on AKS                | completed   | High     | 1.1.3, 1.1.1        | Platform Engineering | 2025-12-02 |
| 1.1.5 | ACR Deployment Documentation         | completed   | High     | None                | Platform Engineering | 2025-12-02 |
| 1.1.6 | KAITO Installation Exec Docs         | completed   | High     | None                | Platform Engineering | 2025-12-02 |
| 1.2.1 | KAITO Deployment Video               | not-started | High     | 2.1.2               | Developer Relations  | 2025-12-01 |
| 1.2.2 | OpenWebSearch AKS Deployment Video   | not-started | High     | 1.1.4               | Developer Relations  | 2025-12-01 |
| 1.2.3 | Integrated Chat App with MCP & KAITO | not-started | High     | 1.2.1, 1.1.4        | Platform Engineering | 2025-12-01 |
| 1.2.4 | End-to-End Solution Demo Video       | not-started | Medium   | 1.2.3, 1.2.1, 1.2.2 | Developer Relations  | 2025-12-01 |
| 1.3.1 | KAITO Exec Doc Workflows Deck        | not-started | High     | 1.2.4               | Product Management   | 2025-12-01 |
| 1.3.2 | KAITO Workflow Review Meeting        | not-started | High     | 1.3.1               | Product Management   | 2025-12-01 |
| 2.1.1 | AKS VM Size Selection Utility        | completed   | Medium   | None                | Platform Engineering | 2025-12-01 |
| 2.1.2 | Phi-3 Fine-Tuning Exec Doc           | not-started | Medium   | None                | AI/ML Team           | 2025-12-01 |
| 2.2.1 | WebSearch Ingress & TLS              | not-started | Low      | 1.1.4               | Platform Engineering | 2025-12-01 |
| 2.2.2 | WebSearch Monitoring Integration     | not-started | Low      | 1.1.4               | Platform Engineering | 2025-12-01 |
| 2.2.3 | WebSearch Alerting                   | not-started | Low      | 2.2.2, 1.1.4        | Platform Engineering | 2025-12-01 |
| 2.2.4 | WebSearch Autoscaling & Load Testing | not-started | Low      | 1.1.4               | Platform Engineering | 2025-12-01 |
| 3.1.1 | Project Governance Setup             | in-progress | High     | None                | Product Management   | 2025-12-01 |

---

## Phase 1: Foundation & MCP Server Validation

### 1.1.1 — Deploy KMCP and Echo MCP Server on AKS

- **Description:** Establish baseline AKS deployment pattern with KMCP controller and Echo MCP server. Validate end-to-end connectivity via MCP Inspector and create reusable deployment runbook. This validates the infrastructure foundation for all subsequent MCP server deployments.
- **Acceptance Criteria:**
  - AKS cluster provisioned with KMCP controller installed and healthy
  - Echo MCP server deployed and reachable via MCP Inspector
  - KMCP CRDs installed and operational (no CrashLoopBackOff)
  - Executable documentation covers: provision, deploy, verify, teardown
  - ACR integration optional but documented if included
- **Priority:** High
- **Responsible:** Platform Engineering
- **Dependencies:** None (prerequisite: Azure subscription with sufficient quota)
- **Progress:**
  - ✅ Environment variables and naming conventions defined
  - ✅ Resource group creation documented
  - ✅ AKS cluster provisioning validated
  - ✅ KMCP controller installation confirmed
  - ⏳ Echo server container build pending
  - ⏳ KMCP CR manifests creation in progress
  - ⏳ End-to-end MCP Inspector validation pending
- **Risks & Mitigations:**
  - Risk: KMCP Helm chart version instability. Mitigation: Pin chart versions in docs, validate before each major update.
  - Risk: ACR pull permissions complexity. Mitigation: Document least-privilege pattern, provide troubleshooting guide.
- **Next Steps:**
  1. Scaffold Echo MCP server using KMCP tooling
  2. Build and push container image to ACR
  3. Create and apply KMCP CRs
  4. Validate via MCP Inspector (port-forward or ingress)
  5. Document complete runbook with teardown
- **Last Updated:** 2025-12-01

---

### 1.1.2 — Innovation Engine MCP Server

- **Description:** Deploy MCP server exposing Innovation Engine capabilities (executable doc execution, idea indexing, experiment metadata) through standardized MCP interface. Server uses FastMCP with dynamic tool loading pattern. Currently working locally but failing remote K8s validation tests.
- **Acceptance Criteria:**
  - Server responds successfully to execute tool invocations (local and remote)
  - HTTP transport mode validated (currently stdio-only confirmed)
  - Deployed to AKS with external accessibility
  - Complete documentation covering all deployment modes
  - Access controls and audit logging functional
  - Performance: p50 latency < 300ms for standard operations
- **Priority:** High
- **Responsible:** Platform Engineering
- **Dependencies:** None (prerequisite: Innovation Engine CLI installed and on PATH)
- **Progress:**
  - ✅ IE CLI installed and verified
  - ✅ Server scaffolding with KMCP complete
  - ✅ Execute tool implemented (supports inline content streaming)
  - ✅ Local stdio testing successful
  - ✅ MCP Inspector local validation passed
  - ✅ Kind cluster deployment successful
  - ❌ HTTP transport testing blocked
  - ❌ AKS deployment test failures
- **Risks & Mitigations:**
  - Risk: Remote test failures indicate networking or configuration issues. Mitigation: Add detailed debug logging, validate HTTP endpoint exposure, test incremental steps.
  - Risk: Dynamic tool loading may fail in containerized environment. Mitigation: Validate HOME directory setup, ensure writable .bash_history path.
- **Blockers:**
  - Remote deployment test consistently failing (see notes)
  - Root cause analysis needed for K8s deployment vs local success
- **Next Steps:**
  1. Debug remote test failures (`ie execute docs/IE_MCP_On_K8s.md`)
  2. Validate HTTP transport mode locally first
  3. Add health check endpoint monitoring
  4. Complete IE_MCP_server.md documentation
  5. Create troubleshooting runbook for common deployment issues
- **Notes:** Test reproduction: `ie clear-env --force; kind get clusters | xargs -r -I {} kind delete cluster --name {}; ie execute docs/IE_MCP_On_K8s.md`
- **Last Updated:** 2025-12-01

---

### 1.1.3 — Open-WebSearch on Local K8s Cluster

- **Description:** Integrate Apache-2.0 licensed Open-WebSearch MCP server (multi-engine web search without API keys) for local K8s deployment. Validates containerization, KMCP integration, and tool functionality before AKS deployment. Core functionality working with remaining observability and security hardening tasks.
- **Acceptance Criteria:**
  - MCP server deployable via KMCP over stdio/http/streamableHttp/SSE transports
  - All tools functional: search, fetchCsdnArticle, fetchLinuxDoArticle, fetchGithubReadme, fetchJuejinArticle
  - Multi-engine search returns structured results (title, url, description, source)
  - Configurable search engines (ALLOWED_SEARCH_ENGINES enforcement)
  - Proxy configuration documented and functional
  - Rate limiting strategy documented
  - Observability: structured logs, metrics exported
  - Security review completed with usage constraints documented
  - Automated test suite covering happy/error paths
  - Deployment docs complete (local npx, container, K8s)
- **Priority:** High
- **Responsible:** Platform Engineering
- **Dependencies:** None (self-contained TypeScript project)
- **Progress:**
  - ✅ Local K8s cluster creation (Kind)
  - ✅ KMCP CRDs installed
  - ✅ OpenWebSearch repo cloned and evaluated
  - ✅ KMCP wrapper validated (direct npx usage confirmed)
  - ✅ Container build implemented
  - ✅ Transport modes configured (stdio, http, streamableHttp, sse)
  - ✅ Environment variable policy established
  - ✅ Local validation successful (npx, node build, basic search)
  - ✅ All tool invocation tests passing
  - ✅ MCP client config examples documented
  - ⏳ Secrets/proxy integration pending
  - ⏳ Performance baseline needed
  - ⏳ Rate limiting implementation pending
  - ⏳ Monitoring dashboard metrics pending
  - ⏳ Security review pending
  - ⏳ Automated acceptance tests pending
- **Risks & Mitigations:**
  - Risk: HTML scraping brittleness due to upstream site changes. Mitigation: Document supported engines, implement graceful degradation, plan periodic validation.
  - Risk: Rate limiting may trigger 429 responses from search engines. Mitigation: Implement exponential backoff, document usage constraints, consider rotation strategies.
  - Risk: Legal/compliance concerns with web scraping. Mitigation: Add prominent usage limitation notice, recommend personal/research use only.
- **Next Steps:**
  1. Implement proxy configuration with USE_PROXY gating
  2. Establish performance baseline (p50 latency, memory footprint)
  3. Document rate limiting approach (per-engine throttling)
  4. Add structured logging (query, engines, result count, user)
  5. Implement error handling strategy
  6. Create monitoring dashboard template
  7. Conduct security review
  8. Write automated acceptance test suite
- **Notes:** Execute with: `ie execute docs/OpenWebSearch_On_K8s_Local.md`. Source: https://github.com/Aas-ee/open-webSearch (TypeScript, Apache-2.0)
- **Last Updated:** 2025-12-01

---

### 1.1.4 — Open-WebSearch on AKS

- **Description:** Deploy validated Open-WebSearch MCP server to AKS environment, establishing a repeatable AKS + KMCP deployment pattern based on the local K8s work from 1.1.3. This task focuses on getting a working, documented AKS deployment with end-to-end MCP validation; advanced hardening (ingress, TLS, monitoring, autoscaling) is covered by Phase 2.2 tasks.
- **Acceptance Criteria:**
  - Server deployed to AKS via KMCP using exec doc
  - MCP session initialization and `tools/call` search flow validated end to end
  - Exec doc `docs/OpenWebSearch_On_AKS.md` runs successfully from a clean environment
  - Registry and KMCP CR wiring documented (image build, push, and reference)
- **Priority:** High
- **Responsible:** Platform Engineering
- **Dependencies:** 1.1.3, 1.1.1
- **Progress:**
  - ✅ Initial AKS deployment successful
  - ✅ Search functionality validated
  - ✅ Session ID management working
  - ✅ Exec doc `docs/OpenWebSearch_On_AKS.md` executed cleanly from a fresh shell
  - ✅ Registry, image, and KMCP Server CR wiring documented
- **Risks & Mitigations:**
  - Risk: Production traffic patterns may expose rate limiting gaps. Mitigation: Start with conservative limits, monitor closely, adjust based on telemetry.
  - Risk: Multi-engine failures could degrade user experience. Mitigation: Implement circuit breakers, fallback engine selection.
- **Next Steps:**
  1. Use this AKS deployment pattern as the reference for OpenWebSearch in downstream docs and demos (1.2.2, 1.2.3, 1.2.4)
  2. Tackle Phase 2.2 hardening tasks (ingress/TLS, monitoring, alerting, autoscaling) as follow-on work
- **Last Updated:** 2025-12-02

---

### 1.1.5 — ACR Deployment Documentation

- **Description:** Create comprehensive executable documentation for deploying Azure Container Registry (ACR) with proper configuration for AKS integration. This establishes the standard pattern for container registry setup used across all MCP server deployments.
- **Acceptance Criteria:**
  - Exec doc `docs/Deploy_ACR_for_AKS.md` exists with standard structure
  - All environment variables documented with HASH-based uniqueness
  - ACR creation, configuration, and AKS integration steps documented
  - Role assignments and permissions configured correctly
  - Validation steps confirm push/pull functionality
  - Cleanup instructions included
  - Referenced from other deployment docs (OpenWebSearch, IE MCP)
- **Priority:** High
- **Responsible:** Platform Engineering
- **Dependencies:** None
- **Progress:**
  - ✅ Documentation created and validated
  - ✅ Stress tested and promoted from incubation to main docs
  - ✅ Integrated into other deployment workflows
- **Status:** Completed
- **Last Updated:** 2025-12-02

---

### 1.1.6 — KAITO Installation and Workspace Exec Docs

- **Description:** Create comprehensive executable documentation suite for KAITO (Kubernetes AI Toolchain Operator) covering installation, workspace deployment, diagnostics, and advanced use cases like RAG and multiple model workspaces.
- **Acceptance Criteria:**
  - Install_Kaito_On_AKS.md: Complete KAITO installation with GPU node pools
  - Deploy_Kaito_Workspace.md: Single model workspace deployment pattern
  - Deploy_Additional_Model_Workspaces_on_Kaito.md: Multi-model scenarios
  - Deploy_RAG_On_Kaito_AKS.md: RAG architecture with KAITO
  - Configure_Diagnostics_for_Kaito.md: Monitoring and troubleshooting
  - All docs follow standard exec doc template
  - Cross-references established between related docs
  - Validation successful in target environment
- **Priority:** High
- **Responsible:** Platform Engineering
- **Dependencies:** None (builds on existing AKS cluster patterns)
- **Progress:**
  - ✅ Install_Kaito_On_AKS.md created (631 lines)
  - ✅ Deploy_Kaito_Workspace.md created (307 lines)
  - ✅ Deploy_Additional_Model_Workspaces_on_Kaito.md created (113 lines)
  - ✅ Deploy_RAG_On_Kaito_AKS.md created (345 lines)
  - ✅ Configure_Diagnostics_for_Kaito.md created (112 lines)
  - ✅ All docs in incubation directory for validation
  - ⏳ End-to-end execution validation pending (task 1.2.1 dependency)
- **Risks & Mitigations:**
  - Risk: GPU quota limitations in test environments. Mitigation: Pre-flight checks documented, multiple region options.
  - Risk: KAITO version changes may break docs. Mitigation: Version pinning in docs, changelog tracking.
- **Next Steps:**
  1. Execute Install_Kaito_On_AKS.md in clean environment
  2. Validate all KAITO workspace deployment patterns
  3. Test RAG deployment end-to-end
  4. Promote validated docs from incubation to main docs directory
  5. Create KAITO deployment video (task 1.2.1)
- **Status:** Completed (pending validation before promotion)
- **Last Updated:** 2025-12-02

---

## Phase 1.2: Demonstration & Integration

### 1.2.1 — KAITO Deployment Video

- **Description:** Create comprehensive video demonstration showing end-to-end deployment of KAITO on AKS using the executable documentation approach. Video will showcase the Exec Doc pattern, GPU quota validation, KAITO installation, workspace creation, and model deployment. This serves as both a marketing asset and technical reference for users adopting the MCPaaS platform patterns.
- **Acceptance Criteria:**
  - Video demonstrates complete KAITO deployment from clean AKS cluster to working model inference
  - Showcases executable documentation workflow (ie execute command usage)
  - Covers prerequisite checks (GPU quota, Azure CLI, subscription setup)
  - Shows KAITO add-on enablement and workspace creation
  - Demonstrates model deployment and inference validation
  - Includes troubleshooting tips for common issues
  - Video quality: HD (1080p minimum), clear audio, proper pacing
  - Duration: 10-15 minutes with chapter markers
  - Published to accessible platform (YouTube, Microsoft Learn, project docs)
  - Accompanying written transcript or summary provided
- **Priority:** High
- **Responsible:** Developer Relations
- **Dependencies:** 2.1.2 (or existing KAITO installation docs as alternative)
- **Progress:**
  - ❌ Not started
- **Risks & Mitigations:**
  - Risk: Video becomes outdated as KAITO/AKS evolves. Mitigation: Include version numbers, plan for quarterly reviews, maintain update schedule.
  - Risk: GPU quota limitations prevent clean demo run. Mitigation: Use pre-validated environment, have fallback cluster ready.
  - Risk: Complex topics hard to convey in video format. Mitigation: Script carefully, use visual aids, provide timestamped chapters.
- **Next Steps:**
  1. Review existing KAITO exec docs and identify optimal demo flow
  2. Create video script with chapter outline
  3. Set up clean demo environment with validated quota
  4. Record screen capture with voiceover
  5. Edit video with callouts, annotations, and chapter markers
  6. Create accompanying written summary
  7. Publish and link from project documentation
  8. Gather feedback and iterate
- **Last Updated:** 2025-12-01

---

### 1.2.2 — OpenWebSearch AKS Deployment Video

- **Description:** Create detailed video walkthrough demonstrating deployment of OpenWebSearch MCP server to AKS cluster using executable documentation. Video will cover containerization, KMCP integration, AKS deployment, ingress configuration, and end-to-end testing of multi-engine web search functionality. Complements task 1.1.4 with visual learning resource.
- **Acceptance Criteria:**
  - Video shows complete deployment from local development to AKS production
  - Demonstrates executable documentation workflow for MCP server deployment
  - Covers container build and registry push (ACR)
  - Shows KMCP CR creation and application
  - Demonstrates ingress/TLS configuration
  - Tests all search engines (DuckDuckGo, Bing, Brave, etc.)
  - Shows MCP Inspector or client integration for validation
  - Includes security considerations and configuration options
  - Video quality: HD (1080p minimum), clear audio
  - Duration: 12-18 minutes with chapter markers
  - Published with written summary/transcript
- **Priority:** High
- **Responsible:** Developer Relations
- **Dependencies:** 1.1.4
- **Progress:**
  - ❌ Not started
- **Risks & Mitigations:**
  - Risk: Search engine APIs/scrapers may fail during recording. Mitigation: Test thoroughly before recording, have backup recording session.
  - Risk: Complex networking concepts difficult to visualize. Mitigation: Use diagrams, network flow illustrations, step-by-step callouts.
  - Risk: Rapid changes in OpenWebSearch upstream. Mitigation: Note version/commit in video, plan for update when major changes occur.
- **Next Steps:**
  1. Wait for task 1.1.4 completion and production validation
  2. Create video script covering all deployment phases
  3. Prepare demo environment (clean AKS cluster, ACR, networking)
  4. Record deployment walkthrough with explanations
  5. Add visual annotations for key concepts
  6. Create chapter markers and summary document
  7. Publish and integrate into project docs
  8. Monitor feedback and plan updates
- **Last Updated:** 2025-12-01

---

### 1.2.3 — Integrated Chat App with MCP & KAITO

- **Description:** Deploy and integrate an open-source chat application (e.g., Open WebUI, LibreChat, or similar) on AKS that leverages KAITO-deployed LLM for inference and OpenWebSearch MCP server for web search augmentation. Create end-to-end solution where users can ask questions and receive web-augmented responses, demonstrating the full MCPaaS value proposition of orchestrating AI workloads with MCP tools.
- **Acceptance Criteria:**
  - Open-source chat application selected and evaluated (licensing, features, extensibility)
  - Chat app deployed to same AKS cluster as KAITO workspace
  - Chat app configured to use KAITO-hosted LLM as backend (e.g., Phi-3 or Mistral)
  - OpenWebSearch MCP server integrated as tool/plugin for the chat app
  - End-to-end flow validated: user asks question → LLM processes → MCP search triggered → results incorporated → response returned
  - Example use case: "What are the latest features in AKS?" returns web-searched results
  - Authentication/authorization configured (basic level acceptable for demo)
  - Resource limits and health checks configured
  - Network policies ensure secure communication between components
  - Executable documentation created for deployment
  - Troubleshooting guide for integration issues
- **Priority:** High
- **Responsible:** Platform Engineering
- **Dependencies:** 1.2.1, 1.1.4
- **Progress:**
  - ❌ Not started
- **Risks & Mitigations:**
  - Risk: Chat app may not support MCP protocol natively. Mitigation: Evaluate apps with plugin/extension support, consider adapter pattern or custom integration layer.
  - Risk: LLM inference latency combined with web search may result in poor UX. Mitigation: Implement streaming responses, set reasonable timeouts, optimize search query generation.
  - Risk: Resource contention on AKS cluster. Mitigation: Right-size node pools, implement resource quotas, monitor and scale as needed.
  - Risk: Complex multi-component integration increases failure points. Mitigation: Implement comprehensive health checks, circuit breakers, and fallback behaviors.
- **Next Steps:**
  1. Research and evaluate open-source chat apps (Open WebUI, LibreChat, Continue, others)
  2. Select chat app based on: MCP/tool support, deployment simplicity, community activity
  3. Create deployment manifests for chosen chat app
  4. Configure chat app to connect to KAITO LLM endpoint
  5. Develop MCP integration layer (native plugin or adapter)
  6. Configure OpenWebSearch MCP server as available tool
  7. Test end-to-end flow with sample queries
  8. Implement error handling and fallback logic
  9. Document architecture and deployment steps as exec doc
  10. Create troubleshooting guide
- **Notes:** Consider Open WebUI (supports Ollama/OpenAI-compatible endpoints) or LibreChat (extensible with plugins). Verify MCP protocol compatibility or plan adapter development. Example query flow: User: "What's new in AKS?" → LLM: [generates search query] → MCP: [web search] → LLM: [synthesizes with results] → User: [receives answer with sources].
- **Last Updated:** 2025-12-01

---

### 1.2.4 — End-to-End Solution Demo Video

- **Description:** Create comprehensive demonstration video showing the complete integrated solution built in task 1.2.3. Video will showcase the deployment process using executable documentation and demonstrate real-world usage of the chat application querying web content via MCP and receiving LLM-generated responses powered by KAITO. This is the capstone demonstration illustrating the full MCPaaS platform capabilities.
- **Acceptance Criteria:**
  - Video demonstrates complete deployment using exec docs from tasks 1.2.1, 1.2.2, and 1.2.3
  - Shows step-by-step deployment: KAITO setup → OpenWebSearch deployment → Chat app integration
  - Live demonstration of end-to-end user flow (ask question → web search → LLM response)
  - Multiple example queries showcasing different scenarios (factual lookup, recent events, technical questions)
  - Highlights key architectural components and data flow
  - Demonstrates monitoring and observability (logs, metrics, health checks)
  - Discusses scalability and production considerations
  - Shows troubleshooting workflow for common issues
  - Video quality: HD (1080p minimum), professional presentation
  - Duration: 15-20 minutes with chapter markers
  - Published with architecture diagrams and written guide
- **Priority:** Medium
- **Responsible:** Developer Relations
- **Dependencies:** 1.2.3, 1.2.1, 1.2.2
- **Progress:**
  - ❌ Not started
- **Risks & Mitigations:**
  - Risk: Complex multi-component demo may encounter failures during recording. Mitigation: Thoroughly test in staging environment, have contingency plans, consider multiple recording sessions.
  - Risk: Long video may lose viewer engagement. Mitigation: Create engaging script, use chapter markers for navigation, maintain good pacing with visual variety.
  - Risk: Technical depth may overwhelm some audiences. Mitigation: Layer information (overview → details), provide separate deep-dive content, include timestamps for different audience levels.
- **Next Steps:**
  1. Wait for task 1.2.3 completion and stability validation
  2. Develop comprehensive video script with storyboard
  3. Create architecture diagrams and visual aids
  4. Set up validated demo environment (all components healthy)
  5. Record deployment walkthrough using exec docs
  6. Record usage demonstration with varied queries
  7. Add visual annotations, diagrams, and explanatory overlays
  8. Create detailed chapter markers for easy navigation
  9. Write accompanying deployment guide and architecture doc
  10. Publish across multiple channels (YouTube, Microsoft Learn, project site)
  11. Gather analytics and feedback for improvements
- **Notes:** This is a marquee demonstration for MCPaaS platform capabilities. Consider: presentation at conferences/meetups, blog post series accompanying video, community office hours for Q&A. Video should emphasize: ease of deployment via exec docs, power of composable MCP architecture, enterprise-readiness of AKS-based solution.
- **Last Updated:** 2025-12-01

---

## Phase 1.3: KAITO Adoption Enablement

### 1.3.1 — KAITO Exec Doc Workflows Deck

- **Description:** Create a high-impact presentation deck that proposes end-to-end workflows as Executable Docs to accelerate KAITO adoption. The deck will translate the working demos (video and integrated solution from 1.2.4) into opinionated patterns and reference architectures, showing how teams can standardize KAITO workflows (provisioning, tuning, deployment, monitoring) as repeatable Exec Docs.
- **Acceptance Criteria:**
  - Deck clearly explains the Executable Docs concept and how it applies to KAITO
  - At least three end-to-end KAITO workflows captured as Exec Doc blueprints (e.g., “Provision GPU AKS + Install KAITO”, “Fine-tune Phi-3 with QLoRA”, “Deploy and wire LLM to app/MCP tools”)
  - Includes architecture diagrams showing how Exec Docs, KAITO, AKS, and MCP servers fit together
  - References concrete examples from completed work (1.2.1, 1.2.2, 1.2.3, 1.2.4, 2.1.1, 2.1.2)
  - Identifies target personas (platform engineering, ML, app dev, DevRel) and their workflows
  - Proposes a minimal KAITO “workflow catalog” structure in the repo
  - Includes call-to-action for early adopters and internal stakeholders
  - Ready to present to KAITO PM/engineering and internal advocacy groups
- **Priority:** High
- **Responsible:** Product Management
- **Dependencies:** 1.2.4
- **Progress:**
  - ❌ Not started
- **Risks & Mitigations:**
  - Risk: Deck remains too abstract and not grounded in real flows. Mitigation: Derive all examples from existing Exec Docs and demos, include concrete commands and paths.
  - Risk: Overlaps with existing KAITO documentation without adding value. Mitigation: Focus specifically on “workflow as code” and MCPaaS patterns rather than generic KAITO overview.
  - Risk: Stakeholders unsure how to adopt proposals. Mitigation: Include phased rollout plan and example “first 3 workflows to standardize.”
- **Next Steps:**
  1. Inventory existing KAITO-related Exec Docs and demo flows (1.2.1–1.2.4, 2.1.2)
  2. Identify 3–5 canonical KAITO workflows to feature
  3. Draft narrative: problem framing, Exec Doc pattern, KAITO-specific benefits
  4. Create architecture and workflow diagrams
  5. Outline proposed workflow catalog structure and ownership model
  6. Add example slides tying back to concrete repo files/commands
  7. Review deck with Platform Engineering and AI/ML teams
  8. Present to KAITO PM/engineering and iterate based on feedback
- **Last Updated:** 2025-12-01

---

### 1.3.2 — KAITO Workflow Review Meeting

- **Description:** Schedule and run a KAITO workflows review meeting with key stakeholders (Fei, Sachi, Rita, Ahmed, Liqian) to walk through the Exec Doc-based end-to-end workflows and the proposal deck from 1.3.1. The goal is to validate the workflows, capture feedback, and agree on a near-term adoption and rollout plan.
- **Acceptance Criteria:**
  - Meeting invite sent and accepted by Fei, Sachi, Rita, Ahmed, and Liqian
  - 60–90 minute session held with clear agenda focused on Exec Doc workflows for KAITO
  - 1.3.1 deck presented, including E2E workflows and catalog proposal
  - Key questions and concerns captured in notes
  - Action items and owners identified for at least:
    - First 2–3 KAITO workflows to standardize and publish
    - Any required platform changes or doc gaps
    - Follow-up alignment with KAITO product/engineering
  - Meeting summary circulated to attendees and stored in project docs
  - Tracker updated with resulting tasks or decisions
- **Priority:** High
- **Responsible:** Product Management
- **Dependencies:** 1.3.1
- **Progress:**
  - ❌ Not started
- **Risks & Mitigations:**
  - Risk: Scheduling delays across multiple stakeholders. Mitigation: Propose several time slots and consider async review of the deck if needed.
  - Risk: Discussion drifts away from concrete workflows into broad roadmap topics. Mitigation: Timebox agenda sections and keep focus on Exec Doc workflows and immediate adoption steps.
  - Risk: No clear ownership emerges for follow-ups. Mitigation: Reserve final 10–15 minutes to confirm owners and dates for all action items.
- **Next Steps:**
  1. Confirm 1.3.1 deck is in review-ready state
  2. Draft meeting agenda and objectives
  3. Propose 2–3 time options and send invite to Fei, Sachi, Rita, Ahmed, and Liqian
  4. Prepare walkthrough of key workflows and catalog proposal
  5. Capture notes, decisions, and action items during the meeting
  6. Send post-meeting summary and update tracker with any new tasks
- **Last Updated:** 2025-12-01

---

## Phase 2: Utilities & Advanced Features

### 2.1.1 — AKS Dynamic VM Size Selection Utility

- **Description:** Reusable executable documentation for dynamic AKS VM SKU selection with quota validation. Extracts and generalizes logic from OpenWebSearch troubleshooting into standalone utility. Reduces deployment doc duplication and standardizes capacity planning across MCP deployments.
- **Acceptance Criteria:**
  - Exec doc `docs/incubation/AKS_VM_Size_Selection.md` exists with standard sections
  - Environment variables documented with defaults (LOCATION, NODE_ARCH, PREFERRED_SKUS, etc.)
  - Script selects viable SKU (available + within quota) or provides remediation guidance
  - Works with and without `jq` (optimization path + fallback)
  - ARM and AMD64 candidate lists with burstable fallback option
  - Sample output for success, fallback, and failure scenarios
  - Referenced from OpenWebSearch and IE MCP deployment docs
  - Validates in at least two regions (eastus, westus3)
  - Changelog updated
- **Priority:** Medium
- **Responsible:** Platform Engineering
- **Dependencies:** None
- **Progress:**
  - ✅ Logic extracted from OpenWebSearch doc
  - ✅ New exec doc created with standard structure
  - ✅ Environment variables defined
  - ✅ Pre-flight script implemented (jq optimization + fallback)
  - ✅ Quota evaluation logic complete
  - ✅ ARM/AMD64 candidates documented
  - ✅ Reference links updated in source docs
  - ⏳ Output examples pending
  - ⏳ Multi-region validation pending
- **Risks & Mitigations:**
  - Risk: Regional SKU availability can change without notice. Mitigation: Document ephemeral nature, link to allocation guidance, recommend fallback SKUs.
- **Next Steps:**
  1. Add output examples (success, fallback, failure)
  2. Validate execution in eastus and westus3
  3. Final review for line length and style compliance
  4. Mark task complete
- **Status:** Completed (pending final validation)
- **Last Updated:** 2025-12-01

---

## Phase 2.2: WebSearch Hardening

### 2.2.1 — WebSearch Ingress & TLS

- **Description:** Configure production-ready ingress and TLS termination for the Open-WebSearch MCP deployment on AKS, ensuring secure external access to the MCP endpoint.
- **Acceptance Criteria:**
  - Ingress or load balancer configured and reachable from outside the cluster
  - TLS certificates provisioned and correctly terminating at the ingress layer
  - Basic MCP client (e.g., MCP Inspector) can reach Open-WebSearch over HTTPS
  - Ingress configuration checked into source control and referenced from exec docs
- **Priority:** Low
- **Responsible:** Platform Engineering
- **Dependencies:** 1.1.4
- **Progress:**
  - ❌ Not started
- **Next Steps:**
  1. Choose ingress strategy (e.g., Nginx Ingress, AGIC, or others)
  2. Provision TLS certificates (managed or via cert-manager)
  3. Configure ingress rules and test external reachability
  4. Update exec docs with ingress/TLS steps and verification commands
- **Last Updated:** 2025-12-01

---

### 2.2.2 — WebSearch Monitoring Integration

- **Description:** Integrate the Open-WebSearch AKS deployment with Azure Monitor (or equivalent) to capture logs and metrics needed for operational visibility.
- **Acceptance Criteria:**
  - Logs from Open-WebSearch pods visible in Azure Monitor/Container Insights
  - Basic metrics (CPU, memory, request counts, error rates) available on dashboards
  - At least one starter dashboard or workbook created for WebSearch
  - Monitoring configuration documented and linked from exec docs
- **Priority:** Low
- **Responsible:** Platform Engineering
- **Dependencies:** 1.1.4
- **Progress:**
  - ❌ Not started
- **Next Steps:**
  1. Verify cluster is sending logs/metrics to Azure Monitor
  2. Ensure WebSearch namespace/pods are included in telemetry
  3. Create or adapt a dashboard for key WebSearch signals
  4. Document how to access and interpret the monitoring views
- **Last Updated:** 2025-12-01

---

### 2.2.3 — WebSearch Alerting

- **Description:** Define and implement alert rules for the Open-WebSearch AKS deployment to detect critical failures and degraded performance.
- **Acceptance Criteria:**
  - Alert rules created for key conditions (e.g., high error rate, pod restarts, elevated latency)
  - Alerts routed to appropriate notification channels (email/Teams/etc.)
  - Test alerts fired and confirmed as received by on-call stakeholders
  - Alert definitions stored as IaC or clearly documented
- **Priority:** Low
- **Responsible:** Platform Engineering
- **Dependencies:** 2.2.2, 1.1.4
- **Progress:**
  - ❌ Not started
- **Next Steps:**
  1. Identify SLOs and key alert conditions for WebSearch
  2. Create alert rules in Azure Monitor (or equivalent)
  3. Configure notification channels and test alert delivery
  4. Document alert strategy and ownership
- **Last Updated:** 2025-12-01

---

### 2.2.4 — WebSearch Autoscaling & Load Testing

- **Description:** Configure resource requests/limits and autoscaling (HPA) for Open-WebSearch, and perform basic load testing to validate behavior under traffic.
- **Acceptance Criteria:**
  - CPU/memory requests and limits defined for Open-WebSearch pods
  - Horizontal Pod Autoscaler configured with sensible thresholds
  - Load test executed to simulate sustained query traffic
  - Observed behavior documented (scaling up/down, latency, error rates)
  - Any follow-up tuning actions identified and tracked
- **Priority:** Low
- **Responsible:** Platform Engineering
- **Dependencies:** 1.1.4
- **Progress:**
  - ❌ Not started
- **Next Steps:**
  1. Define resource requests/limits based on baseline measurements
  2. Configure HPA and verify scaling behavior
  3. Run a simple load test (e.g., repeated search queries) against WebSearch
  4. Capture results and recommendations in documentation
- **Last Updated:** 2025-12-01

---

### 2.1.2 — Phi-3 Fine-Tuning on AKS via KAITO Exec Doc

- **Description:** Author executable documentation guiding users through fine-tuning Phi-3-mini-128k-instruct (or Phi-4-mini) on AKS using KAITO with QLoRA method. Covers GPU quota checks, KAITO enablement, workspace tuning, dataset ingestion (Dolly 15k), monitoring, image production, validation, and cleanup. Establishes pattern for advanced AI/ML workloads on MCPaaS.
- **Acceptance Criteria:**
  - New exec doc `docs/incubation/Fine_Tune_Phi_3_On_AKS_With_Kaito.md` exists
  - All environment variables documented with defaults and HASH uniqueness
  - GPU quota/SKU checks produce actionable messages on failure
  - Workspace tuning YAML reaches Succeeded status
  - Output image built, tagged, and pushed to ACR
  - Inference test shows qualitative improvement (pre vs post comparison)
  - Expected similarity tests present for major blocks
  - Cleanup instructions validated
  - Cross-links added (KAITO install doc + README)
  - Line width <=80, no em dashes
- **Priority:** Medium (High Impact / Not Urgent)
- **Responsible:** AI/ML Team
- **Dependencies:** None (prerequisite: KAITO installation doc, AKS cluster with GPU nodes)
- **Progress:**
  - ❌ Not started
- **Risks & Mitigations:**
  - Risk: GPU quota insufficiency. Mitigation: Pre-flight checks and escalation guidance.
  - Risk: Dataset license misuse. Mitigation: License note and link to terms.
  - Risk: Image push failures. Mitigation: ACR login validation, unique tagging.
  - Risk: Long-running tuning cost. Mitigation: Poll loop with max duration, early stop procedure.
- **Next Steps:**
  1. Create exec doc file with standard sections
  2. Define all environment variables with defaults
  3. Implement GPU quota/SKU pre-flight checks
  4. Author workspace tuning YAML
  5. Add readiness and tuning phase polling
  6. Implement verification section
  7. Add expected_similarity tests
  8. Document timing/cost guidance
  9. Write cleanup section
  10. Add cross-links and dataset licensing notes
- **Success Metrics:**
  - Executes successfully in two regions
  - Tuning completes within documented window
  - Post-tuned model shows measurable improvement
- **Notes:** Reference source: https://roykim.ca/2025/01/11/deep-dive-into-fine-tuning-an-lm-using-kaito-on-aks-part-1-intro/
- **Last Updated:** 2025-12-01

---

## Phase 3: Platform & Governance

### 3.1.1 — Project Governance Setup

- **Description:** Establish project management structures including tracker maintenance workflow, PRD alignment, and stakeholder communication patterns. Ensures project visibility and accountability as team expands.
- **Acceptance Criteria:**
  - Tracker agent operational and updating .pm/tracker.md regularly
  - PRD aligned with current project scope and roadmap
  - Weekly status updates established
  - Risk register maintained
  - Stakeholder communication plan documented
- **Priority:** High
- **Responsible:** Product Management
- **Dependencies:** None
- **Progress:**
  - ✅ PRD moved to .pm/ directory
  - ✅ Tracker.md initialized with current project state
  - ✅ Tracker agent definition generalized
  - ⏳ Regular update cadence to be established
  - ⏳ Stakeholder communication plan pending
- **Risks & Mitigations:**
  - Risk: Tracker becomes stale without automation. Mitigation: Set up regular review schedule, consider automation hooks.
- **Next Steps:**
  1. Establish weekly tracker review schedule
  2. Define stakeholder communication cadence
  3. Create risk review process
  4. Document escalation paths
  5. Set up automated reminders for tracker updates
- **Last Updated:** 2025-12-01

---

## Risks & Issues

### Active Risks

| Risk ID | Description                                                                | Impact | Likelihood | Mitigation Status                                                                       |
| ------- | -------------------------------------------------------------------------- | ------ | ---------- | --------------------------------------------------------------------------------------- |
| R-001   | Scope ambiguity between PRD vision and current experimental phase          | High   | High       | In Progress - PRD acknowledges phased approach, needs explicit milestone mapping        |
| R-002   | Remote deployment test failures blocking IE MCP and Web Search validation  | High   | High       | Under Investigation - needs root cause analysis and debug instrumentation               |
| R-003   | Documentation drift with multiple incomplete exec docs                     | Medium | High       | Mitigation Needed - establish doc ownership, maintenance schedule, and freshness checks |
| R-004   | Single-person dependency for platform engineering work                     | High   | Medium     | Awareness - need team expansion plan or clearer prioritization                          |
| R-005   | Unclear path from current experimental work to PRD's full managed platform | Medium | High       | Planning Needed - roadmap alignment session required                                    |

### Issues

| Issue ID | Description                                                           | Priority | Owner                | Status |
| -------- | --------------------------------------------------------------------- | -------- | -------------------- | ------ |
| I-001    | IE MCP remote deployment test failing consistently                    | High     | Platform Engineering | Open   |
| I-002    | Open-WebSearch AKS deployment needs security review before production | High     | Platform Engineering | Open   |
| I-003    | Missing monitoring/alerting integration for deployed MCP servers      | Medium   | Platform Engineering | Open   |
| I-004    | No automated test suite for executable documentation                  | Medium   | Platform Engineering | Open   |

---

## Completed Work

### Sprint Ending 2025-12-01

- ✅ Generalized tracker agent definition for reusability
- ✅ Created initial project tracker aligned with TODO.md and PRD
- ✅ Moved PRD to .pm/ directory for better organization
- ✅ Completed AKS VM Size Selection utility (pending validation)
- ✅ Open-WebSearch local deployment and basic functionality validated
- ✅ Open-WebSearch AKS deployment with search working

### Sprint Current (2025-12-02)

- ✅ Open-WebSearch AKS documentation stress-tested and promoted
- ✅ ACR deployment documentation created and validated
- ✅ Comprehensive KAITO documentation suite created (5 exec docs)
- ✅ Agent definitions linted and updated for consistency
- ✅ Multiple exec docs promoted from incubation
- ⏳ KAITO docs awaiting end-to-end validation
- ⏳ IE MCP remote deployment still blocked

---

## Upcoming Milestones

| Milestone                  | Target Date | Description                                  | Key Deliverables                                               |
| -------------------------- | ----------- | -------------------------------------------- | -------------------------------------------------------------- |
| M1: Foundation Complete    | 2025-12-15  | All three MCP servers deployed and validated | Echo on AKS, IE MCP remote working, WebSearch production-ready |
| M2: Documentation Baseline | 2025-12-31  | Complete exec docs with automated testing    | All docs executable, test framework, freshness checks          |
| M3: Governance Operational | 2026-01-15  | Project management structures operational    | Regular updates, risk management, stakeholder comms            |
| M4: PRD Alignment          | 2026-01-31  | Roadmap aligned with PRD phased approach     | Phase 1 plan, scope agreement, resource allocation             |

---

## Notes & Observations

### Project Maturity Assessment

- **AKS-MCP (Go)**: Production-ready, mature codebase, comprehensive documentation
- **innovation-engine-mcp (Python)**: Experimental, promising patterns (dynamic tool loading, inline content), needs stabilization
- **open-webSearch (TypeScript)**: Integration phase, core functionality working, needs hardening

### Strategic Questions

1. How does current experimental work map to PRD's phased delivery model (Developer Toolkit → Portal → Platform)?
2. What defines "production-ready" for MCPaaS-hosted MCP servers?
3. Should focus shift from multiple experimental servers to production-hardening one reference implementation?
4. What is the team expansion plan to support PRD scope?

### Documentation Insights

- Executable documentation pattern is powerful but needs:
  - Automated testing framework
  - Freshness validation
  - Clear ownership model
  - Maintenance schedule
- Strong alignment with PRD's adaptive documentation vision (FR-009, FR-010, FR-011)

---

## Changelog

- 2025-12-01: Initial tracker.md created from TODO.md, PRD, and repository analysis
- 2025-12-01: Added governance setup task (3.1.1)
- 2025-12-01: Documented current status of all in-flight work
- 2025-12-01: Identified strategic alignment questions and risks
- 2025-12-01: Added Phase 1.2 demonstration and integration tasks:
  - 1.2.1: KAITO Deployment Video (High priority)
  - 1.2.2: OpenWebSearch AKS Deployment Video (High priority)
  - 1.2.3: Integrated Chat App with MCP & KAITO (High priority)
  - 1.2.4: End-to-End Solution Demo Video (Medium priority)
- 2025-12-01: Dependency tracking review - Added Dependencies column to summary table and standardized dependency notation across all tasks (task IDs vs prerequisites)
- 2025-12-02: Major documentation milestone - Added tasks 1.1.5 (ACR) and 1.1.6 (KAITO suite) as completed. Open-WebSearch AKS promoted to main docs. 5 new KAITO exec docs created covering installation, workspace deployment, RAG, diagnostics, and multi-model scenarios. Updated sprint focus and risks based on recent progress.
