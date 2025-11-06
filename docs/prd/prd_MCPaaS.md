# Product Requirements Document (PRD)

Title: MCP-as-a-Service (MCPaaS)
Version: 0.2 (Draft for Review)
Status: Request for Feedback
Last Updated: 2025-10-31
Owner: (assign)
Approval: (stakeholders for sign-off)

### Revision History

| Date       | Version | Change                                                       |
| ---------- | ------- | ------------------------------------------------------------ |
| 2025-07-22 | 0.1     | Initial draft                                                |
| 2025-07-29 | 0.1     | Request for feedback iteration                               |
| 2025-08-26 | 0.2     | Version 2 content pass                                       |
| 2025-10-31 | 0.2     | Integrated extended market, solution phases, risks alignment |

## 1. Executive Summary

Problem Domain

Deploying and operating Model Context Protocol (MCP) servers at scale is substantially more complex than authoring them. Moving from local prototype to production on AKS requires containerization, Kubernetes expertise, networking and ingress configuration, security hardening, compliance controls, observability setup, and ongoing day 2 operations. This complexity creates delays, inconsistent security posture, and elevated operational overhead. Many teams stall or adopt fragile workarounds rather than fully embracing MCP.

Proposed Approach

MCP-as-a-Service (MCPaaS) removes infrastructure friction through a phased delivery model: initial developer-focused CLI toolkit (fast scaffold, test, deploy), followed by a portal-based catalog with guided deployment, and culminating in a fully managed enterprise platform with governance, automation, and AI-assisted operations. Progressive adoption ensures individual developers, team leads, and enterprises can enter at an appropriate maturity level and expand capabilities without migration pain.

Core Capabilities (progressively delivered)

- Automated containerization, Kubernetes configuration, networking, and TLS setup
- Searchable catalog evolving from CLI templates to portal marketplace to federated registry (community + vetted sources)
- Push-to-deploy CI/CD automation with health monitoring, autoscaling, and lifecycle controls
- Secure-by-default endpoints (managed TLS, Azure AD integration, RBAC, compliance scanning)
- IDE integration path (connection helpers → VS Code extension → multi-IDE native support)
- MCP protocol optimizations (stdio-to-HTTP bridging, streaming compatibility)
- Unified governance (catalog, RBAC, audit logging, policy enforcement)
- Enterprise features (managed identities, private networking, cost and quota visibility)
- AI-assisted discovery and deployment (long-term phase) via meta-MCP endpoint

Business Impact

- Accelerated AI adoption: shorter time-to-value for AI agent integration with real systems
- Increased Azure consumption: higher utilization of AKS, ACR, networking, identity, and AI services
- Democratized MCP development: reduces dependency on specialized DevOps/platform engineering
- Strategic differentiation: positions Azure strongly in managed AI orchestration and agent infrastructure

Vision

MCP-as-a-Service becomes the default path on Azure for building, deploying, discovering, and governing self managed MCP servers - securely connecting AI agents to enterprise and community systems at scale while minimizing infrastructure overhead and maximizing innovation velocity.

## 2. Background and Context

Model Context Protocol (MCP) is an open standard enabling AI applications and agents to connect to external tools, resources, prompts, and data sources through a consistent JSON-RPC based protocol. An MCP server is any program serving context data or tool interfaces, locally or remotely. MCP defines a data layer (lifecycle, primitives: tools, resources, prompts, notifications) and a transport layer (connection establishment, framing, authorization for stdio, HTTP, and future streaming variants).

Operating MCP servers in production introduces requirements beyond development: catalog and access management, secure networking (ingress, TLS termination), scaling and elasticity, monitoring and observability, update orchestration, internal discoverability, and adherence to enterprise compliance standards. These dimensions frequently require specialized infrastructure expertise.

Research Findings

- Customer observations (Note 8007633) highlight fragmentation in deployment tooling, absence of standardized production readiness criteria, inconsistent observability surfaces, governance and audit gaps, cost sizing uncertainty, and ad hoc regional reliability patterns.
- Adoption survey (Note 8007824) shows non-adoption primarily driven by limited current need and agent maturity rather than solely infrastructure friction; interoperability remains a leading driver among active users.
- Documentation personalization study (Note 8007405) identifies demand for adaptive, role and scenario specific runbooks with authoritative sourcing, freshness metadata, and integrated feedback loops.
- Additional adoption observations (Note 8007462) reinforce the necessity of incremental readiness scaffolding (checklists, benchmarks) over assumption of pure infrastructure blockers.

Implication: A successful managed MCP platform must combine infrastructure automation with adaptive executable documentation and governance baselines to shorten experiment-to-production transition while ensuring interoperability and compliance; adoption uncertainty highlighted in Note 8007824 (broad distribution of MCP maturity and need) necessitates a phased delivery approach to validate customer response and de-risk large scale investment before full platform build-out.

Ecosystem Commentary Examples

- Introducing MCP as a Service (Kiessling 2025): Emphasizes reducing lifecycle burdens (routing, TLS, auth, observability).
- Agentgateway project: Focus on secure, observable agent-to-agent and agent-to-tool communication.
- KMCP Quickstart: Multi-step manual setup (Docker, Kind, Helm, controller install) illustrating onboarding friction.

### Agent2Agent Protocol Overview and Comparison

Agent2Agent (A2A) protocol (Google, 2025) focuses on standardized interoperability between autonomous agents, enabling direct coordination, capability negotiation, and multi-agent orchestration workflows. Core design motifs emphasize agent identity, intent exchange, and cross-boundary task delegation. MCP centers instead on connecting agents or AI-powered development tools to external resources, data stores, prompts, and tool interfaces via a server abstraction. While both aim to reduce fragmentation, their scopes differ:

| Dimension           | MCP                                                                        | Agent2Agent (A2A)                                                           |
| ------------------- | -------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| Primary Focus       | Tool/resource exposure and contextual data for agent consumption           | Agent-to-agent coordination and interoperability layer                      |
| Interaction Model   | Client (IDE/agent) ↔ MCP server (tools/resources)                          | Peer agents exchanging capabilities, intents, tasks                         |
| Transport           | Stdio, HTTP (expanding to streaming)                                       | Defined message envelopes for agent capability negotiation and task routing |
| Governance Surface  | Catalog, RBAC, audit logging, compliance for exposed tools                 | Trust, identity, permissioning across agent boundaries                      |
| Adoption Drivers    | Need to connect AI workflows to existing systems securely and consistently | Desire to compose multi-agent solutions without bespoke integration glue    |
| Enterprise Concerns | Security hardening, compliance evidence, operational scaling               | Cross-organizational interoperability, agent identity federation            |
| Maturity Signals    | Growing server/template ecosystem, emerging managed hosting patterns       | Early standard articulation, validation through multi-agent experimentation |

Adoption Observations:

- Note 8007824 indicates broad distribution of MCP maturity; similar early-stage distribution is expected for multi-agent coordination standards like A2A.
- Early MCP adoption is driven by practical integration (GitHub, filesystem, data connectors); A2A adoption is likely to trail until multi-agent workflows yield clear ROI beyond single-agent plus tool architectures.
- Platform investment risk: Over-indexing prematurely on complex multi-agent orchestration could dilute near-term customer value where single-agent plus robust tool/resource integration solves immediate needs.
- Strategic implication: MCPaaS should monitor A2A evolution and design extensibility points (e.g. protocol conformity validation, meta-endpoint abstraction) so future integration of agent-to-agent negotiation does not require architectural rework.

Positioning Guidance:

- Prioritize MCP operational excellence and governance while maintaining a pluggable interface layer that can observe or proxy emergent agent-to-agent standards.
- Provide documentation comparing when to use MCP server integration vs when multi-agent coordination may be appropriate (avoid premature complexity for early adopters).
- Capture telemetry on composite workflows (agent invokes multiple MCP servers sequentially); if patterns suggest emergent multi-agent negotiation needs, evaluate A2A bridging.

Citation: Google Developer Blog announcement on Agent2Agent protocol (2025) publicly outlines goals for standardized agent interoperability. https://developers.googleblog.com/en/a2a-a-new-era-of-agent-interoperability/

Conclusion

Interoperability, governance, and readiness acceleration are emerging critical success factors. Early investment in managed lifecycle patterns, adaptive documentation, protocol conformity validation, and standardized observability positions the platform to meet evolving enterprise and developer requirements.

## 3. Problem Statement / Motivation

Building MCP servers is straightforward; operating them in production on AKS is complex and resource intensive. Teams must address containerization, Kubernetes configuration, networking (ingress, certificates), authentication and authorization, observability, scaling policies, patching cadence, audit logging, compliance scanning, and secure endpoint exposure. Without a managed solution, engineering effort shifts from AI capability development to infrastructure assembly and maintenance.

Operational Risks from Current Approach

- Security vulnerabilities persist due to delayed image patching and lack of automated base image updates.
- Hardcoded secrets or long-lived tokens appear when OAuth/OIDC integration requires extra infrastructure work.
- Compliance evidence (audit trails, GDPR/PII controls) becomes fragmented across pipelines and scripts.
- Reliability issues arise during traffic spikes without autoscaling or proactive health checks.
- Incident response slows because observability is incomplete or inconsistent.
- Configuration drift results from divergent custom deployment scripts per team.
- Certificate management errors cause avoidable downtime (expired TLS certificates).

Strategic Impact

- Slower time-to-value for AI agent integration.
- Increased operational overhead and duplicated scripting effort.
- Elevated risk posture (security, compliance, reliability gaps).
- Potential abandonment of MCP adoption or reliance on insecure workarounds.

Motivation

Providing a managed, secure, governed MCP platform with automated deployment, scaling, and adaptive documentation reallocates engineering time to AI innovation, improves security and compliance posture, and accelerates safe production adoption.

Success requires coupling infrastructure automation with governance baselines, protocol conformity validation, and role-aware executable guidance.

## 4. Goals

Primary measurable objectives for initial phase (MVP) and progression guidance.

- Goal 1: Reduce time to deploy a production-ready MCP server to under 10 minutes (from scaffold or catalog selection).
- Goal 2: Provide a uniform control plane for lifecycle operations (deploy, status, update, rollback) across CLI and portal.
- Goal 3: Enable baseline monitoring and health visibility (status indicators, logs, metrics, scaling events).
- Goal 4: Deliver adaptive executable documentation filtered by role, project scenario, and compliance needs to reduce experiment-to-production promotion time.
- Goal 5: Establish best practice benchmark (security, resource sizing, protocol conformity) with feedback loop (inline submission + freshness metadata).
- Goal 6: Provide secure-by-default endpoints (managed TLS, Azure AD integration, RBAC) with minimal user configuration.
- Goal 7: Support progressive adoption path (CLI → Portal → Enterprise platform) without migration steps.

Derived Insight Alignment (Note 8007633, 8007405, 8007462):

- Standardized deployment pipeline reduces bespoke scripting and accelerates readiness.
- Early audit and role controls mitigate governance pressure.
- Baseline metrics and logs improve troubleshooting speed.
- Interoperability focus (protocol conformity, template quality) enhances cross-agent integration.
- Guidance on node SKU and resource sizing reduces cost uncertainty.
- Adaptive documentation addresses personalization and learning mode requirements.

## 5. Non-Goals (MVP)

Clarifies exclusions to prevent scope creep.

- Advanced multi-tenant chargeback or detailed cost allocation reporting (beyond tagging and basic usage metrics)
- Automated autoscaling policy optimization (initial manual or threshold-based configurations only)
- Hosting MCPs on local machines or on-premises infrastructure (Azure cloud focus)
- Non-containerized MCP deployments (OCI image workflow is required)
- Building or maintaining AI agent runtimes or client applications (focus remains on MCP servers and platform operations)
- Deep code analysis, linting, or runtime debugging of user application logic (provide deployment and operational tooling, not static analysis)
- Full multi-region failover orchestration (post-MVP roadmap)
- Advanced policy engine (OPA/Gatekeeper integration moves to later phase)
- Dynamic per-tenant resource quota enforcement beyond coarse RBAC (advanced isolation in future phase)

## 6. User Personas

Primary personas and concise goals.

- Application Developer: Needs rapid scaffold, discoverability, and one-click deployment with minimal infrastructure knowledge.
- Machine Learning Engineer: Requires automatic wrapping of existing repo code into hosted MCP endpoints with CI/CD and private sharing.
- Data Scientist: Wants frictionless discovery and installation of community or curated MCP servers for analysis workflows.
- Open Source Contributor: Publishes MCP implementations with metadata and monitors adoption and ratings.
- Platform Engineer: Establishes control plane, automation standards, and governance baselines.
- SRE / Operations: Monitors health, scaling events, performance, and manages lifecycle actions (start/stop/update).
- Security / Governance Officer: Enforces RBAC, audit logging, compliance scanning, and verifies catalog integrity.
- Enterprise Architect: Curates approved MCP catalog, applies organization policies, ensures secure networking and identity integration.

User stories expanded in Appendix provide detailed success criteria mapping to KPIs (e.g. Time to first server, deployment success rate, audit coverage).

## 7. Primary Use Cases

High value workflows the platform must enable (MVP and foundation for future phases).

| ID  | Use Case                | Summary                                                               |
| --- | ----------------------- | --------------------------------------------------------------------- |
| UC1 | Provision Control Plane | Create KMCP-backed environment on AKS with documented workflow        |
| UC2 | Deploy MCP Server       | Configure and deploy MCP server artifact (image, replicas, resources) |
| UC3 | Monitor Health          | View status, logs, key metrics, scaling events                        |
| UC4 | Update / Rollback       | Perform safe upgrade with version history and rollback                |
| UC5 | Access Control          | Enforce RBAC for deploy, update, delete operations                    |
| UC6 | Audit Change            | View history of deployments and configuration diffs                   |
| UC7 | Discover Templates      | Access curated scaffold / catalog entries for rapid start             |
| UC8 | Adaptive Runbooks       | Generate role and scenario specific executable documentation          |
| UC9 | Just-in-Time Provision  | Dynamically mount and start server on first request                   |

## 8. Phased Solution Overview

### 8.1 Short Term (Developer Toolkit / CLI)

Focus: Immediate infrastructure simplification for developers deploying MCP servers to AKS.

Capabilities:

- Project scaffolding (Node.js / Python) with Dockerfile and Kubernetes manifests
- Local testing harness (stdio-to-HTTP bridge, health checks) without Docker/Kubernetes dependency
- Single-command deploy (build image, push to ACR, deploy to AKS, configure ingress, issue endpoint + API key)
- Connection helper for VS Code integration
- Quick-start templates (GitHub, filesystem, database connectors)
- Documentation guides with examples and videos

Trade-offs: Requires some Kubernetes knowledge, lacks UI/catalog, manual security hardening.

### 8.2 Medium Term (Managed Catalog + Portal)

Focus: Visual discovery, guided deployment, basic lifecycle management bridging CLI and full platform.

Capabilities:

- Azure Portal MCP catalog (20–30 curated MCPs with metadata, ratings, reviews)
- Deployment wizard (cluster selection including AKS Automatic, networking, auth method, progress tracking)
- VS Code extension for catalog browsing and automatic endpoint connection
- Basic management dashboard (status, metrics, logs, start/stop/delete, cost summary)
- GitHub repository auto-detection and CI/CD automation (GitHub Actions on push)

Trade-offs: Limited enterprise security automation; manual hardening steps remain.

### 8.3 Long Term (Full Managed Platform)

Focus: Enterprise-grade, fully automated platform with governance, federation, AI-assisted operations.

Capabilities:

- Comprehensive catalog (100+ MCPs) with semantic search, compliance certifications, federation (GitHub, npm)
- Automated stdio-to-HTTP wrapper generation and streaming support
- Organization-specific private catalogs with approval workflows
- Meta-MCP endpoint enabling programmatic management and AI-assisted discovery/deployment
- Advanced governance (RBAC, policy enforcement, audit, cost attribution, quota management)
- Autonomous operations (autoscale, patching, proactive alerts, cost optimization, dynamic security validation)
- Team collaboration (permission inheritance, shared dashboards)
- Executive visibility (deployment metrics, security posture, availability SLAs, cost trends)

Trade-offs: Significant engineering investment and cross-team coordination; longer time to market.

Progression Principle: Users can adopt at any phase and advance without disruptive migration (tooling and metadata continuity maintained).

## 9. Scope (MVP vs Later)

Separate features into MVP and Post-MVP buckets.

### 9.1 MVP In-Scope

- KMCP control plane deployment automation
- Basic UI or CLI for server creation and status
- Echo MCP server sample deployment template
- Role based access (coarse) with audit logging baseline
- Health indicators (pod readiness, basic logs)
- Adaptive executable runbook scaffolding (parameterized by role and project scenario)
- Best practice metadata (last updated timestamp, source links) surfaced in server template docs
- Inline feedback capture mechanism (issue link or form) for documentation and templates
- Path-based multi-server hosting (single process host mounting multiple MCP server subprocesses)
- On-demand (just-in-time) MCP server provisioning via configuration database row insertion
- Basic distributed lock (e.g. Redis) coordination for concurrent server startup avoidance

### 9.2 Post-MVP / Future

- Multi-region failover
- Advanced autoscaling (metrics based)
- Cost visibility and chargeback tagging dashboards
- Policy engine for configuration governance
- Marketplace of reusable MCP server templates
- Streamable HTTP transport support (bi-directional low-latency alternative to SSE)
- Migration option for Kubernetes-based hosting (multi-port/service mesh, advanced autoscaling)
- Automated dynamic resource scaling per server (CPU/memory driven)
- Multi-tenant isolation policies (quota, per-tenant RBAC beyond coarse role access)

## 10. Functional Requirements

Enumerate testable behaviors. Use FR identifiers.

- FR-001: System must provision an AKS cluster and install KMCP via a single documented workflow.
- FR-002: Users must create a new MCP server instance with a defined spec (image, replicas, resources) via UI or CLI.
- FR-003: System must display current lifecycle status (Pending, Deploying, Running, Error) for each MCP server.
- FR-004: Users must trigger a redeploy/update of a server with versioned history.
- FR-005: Audit log must capture create, update, and delete actions with timestamp and actor.
- FR-006: Access must be restricted so only authorized roles can deploy or delete servers.
- FR-007: System must expose a sample server template (Echo) for onboarding.
- FR-008: Documentation must include executable runbooks for control plane and server deployment.
- FR-009: System must generate adaptive executable documentation filtered by role (e.g. Platform Engineer, Developer) and project scenario (e.g. modernization, security hardening) using parameterized templates.
- FR-010: Documentation artifacts must display metadata (last updated date, source references, version) for each MCP server template and runbook.
- FR-011: System must provide a feedback capture mechanism (e.g. inline submission) attached to each documentation page or template artifact.
- FR-012: System must surface a best practice checklist referencing endorsed security, compliance, and operational standards and allow marking completion status per server deployment.
- FR-013: Host must support path-based multiplexing of multiple MCP servers under a single network endpoint with dynamic sub-app mounting.
- FR-014: System must implement just-in-time provisioning: first request to an enabled, unmounted server path triggers install/start/mount workflow.
- FR-015: Configuration database must allow zero-downtime onboarding by adding a server record without host redeploy.
- FR-016: Distributed lock mechanism must prevent duplicate concurrent onboarding attempts across host instances.
- FR-017: Each MCP server must expose /status endpoint returning process liveness and minimal health JSON.
- FR-018: System must record ownership metadata (owner_team) and allow access sharing updates audited.
- FR-019: System must support parameter isolation (e.g. scoping per project for external service integrations) at startup.
- FR-020: Onboarding workflow must validate security clearance (allowlisting) before activation.
- FR-021: Removal operation must allow de-registration and shutdown of idle servers (e.g. remove path handler) without host restart.
- FR-022: Audit log must capture per invocation (AAD object id, timestamp, server_name).
- FR-023: System must support selectable multi-tenancy isolation model (shared model with tenant-scoped context vs dedicated per-tenant server) documented and configurable per deployment.
- FR-024: Marketplace / external customer onboarding workflow must expose a guided path for users without existing Azure AD tenant (guest invitation or alternative sign-up) with automated validation of identity readiness.
- FR-025: Rate limiting must enforce per-identity request thresholds (e.g. requests per minute) configurable and logged.
- FR-026: System must provide cost event emission (per server invocation with estimated token/model usage) enabling external budgeting integration.
- FR-027: Tier change resilience: network and security configuration artifacts (APIM or gateway settings) must be exportable and restorable automatically after pricing tier adjustments.
- FR-028: Quota management interface must surface current AI model usage (tokens/minute, requests/minute) and recommend quota increase actions when sustained utilization exceeds 80% of limit for defined window.
- FR-029: Foundry/agent configuration export capability documented (manual or automated) to reproduce playground agents in production environment.

## 11. Non-Functional Requirements

### 11.1 Performance

- NFR-PERF-001: Control plane deployment end-to-end under 20 minutes in standard region.
- NFR-PERF-002: MCP server create operation surfaces initial status within 15 seconds.
- NFR-PERF-003: First-request just-in-time provisioning completes mount + status availability under 60 seconds for third-party package servers (baseline).
- NFR-PERF-004: Status endpoint response time under 200 ms at P95.
- NFR-PERF-005: Rate limiting decision latency under 50 ms added overhead.

### 11.2 Reliability

- NFR-REL-001: Control plane components target 99.5% monthly availability (initial target).
- NFR-REL-002: Rollback procedure documented and executable within 10 minutes.
- NFR-REL-003: Just-in-time provisioning retries limited to 1 automatic attempt after failure; subsequent failures generate alert.
- NFR-REL-004: Redis coordination lock expiration defaults < 30 s with ready flag TTL >= 600 s to avoid thrash.
- NFR-REL-005: Automated restoration of gateway/network configuration after tier change completes within 10 minutes.
- NFR-REL-006: Quota monitoring detects sustained >80% usage and raises advisory alert within 5 minutes.

### 11.3 Security

- NFR-SEC-001: Use least-privilege Azure RBAC assignments for cluster and registry.
- NFR-SEC-002: Secrets stored in Azure Key Vault or Kubernetes secret with encryption at rest.
- NFR-SEC-003: Image pulls use ACR with scoped pull permissions.
- NFR-SEC-004: All server invocations require valid AAD bearer token; unauthorized requests rejected with 401.
- NFR-SEC-005: Parameter isolation enforces scope boundaries (e.g. project id) preventing cross-project resource access.
- NFR-SEC-006: Configuration database access restricted to host service identity with least privilege (CRUD on server metadata only).
- NFR-SEC-007: Rate limiting and quota alerts must include identity attribution to support abuse detection.
- NFR-SEC-008: Guest/external identity onboarding flow must enforce email domain verification and record tenant mapping for audit.

#### Security References

- [Agentgateway](https://agentgateway.dev/): an open source project that is built on AI-native protocols to connect, secure, and observe agent-to-agent and agent-to-tool communication across any agent framework and environment.
- [Customer Observations Note 8007633](https://hits.microsoft.com/note/8007633): summarized MCP adoption friction points (tooling fragmentation, readiness criteria gaps, governance, interoperability, cost and regional reliability concerns).

### 11.4 Compliance / Governance

- NFR-COMP-001: All deployment actions auditable with actor and timestamp.
- NFR-COMP-002: Tagging enforced for resource group and cluster (env, system, owner).

### 11.5 Operability

- NFR-OPS-001: Standard troubleshooting guide available (pod logs, events, metrics).
- NFR-OPS-002: Health endpoints or readiness signals for MCP servers documented.
- NFR-OPS-003: Executable documentation generation latency under 10 seconds, excluding infra deployment times, for standard templates.
- NFR-OPS-004: Documentation metadata (last updated timestamp) must be no older than 30 days for core templates (Echo) or flagged as stale.
- NFR-OPS-005: On-demand provisioning emits structured events (start, install_begin, install_complete, mounted) to telemetry.
- NFR-OPS-006: Per-server process crash detected and auto-recovered on next request; mean recovery initiation < 5 s.
- NFR-OPS-007: Removal operation logs server_name, actor, timestamp, child process exit code.
- NFR-OPS-008: Cost usage events (token count, model type) emitted per invocation with < 5% variance from actual billable usage (where measurable).
- NFR-OPS-009: Onboarding workflow automation success rate (completed without manual intervention) > 70% initial target.
- NFR-OPS-010: Tier change detection triggers automatic configuration restore script execution and emits completion event.

## 12. User Experience / UX Notes

Outline high level UX principles. Provide placeholders for mockups or flows.

- Simple onboarding flow: Provision control plane, then deploy first server.
- Clear separation between infrastructure view and server catalog.
- Status badges for each server (color-coded by state).

## 13. Information Architecture / Data Model (Draft)

List primary objects and key fields.

- ControlPlane: id, region, clusterId, status, createdAt
- McpServer: id, name, image, version, replicas, status, lastUpdated
- DeploymentHistory: id, serverId, actionType, actor, timestamp, diff
- AuditEvent: id, entityType, entityId, actor, verb, timestamp
- User / Role mapping (source: Azure AD / RBAC binding reference)
- ServerConfig: server_name, install_command, startup_command, env_vars (JSON), enabled, created_at, updated_at, owner_team, description
- ServerRuntimeState: server_name, status (installing|starting|running|error), pid, initialized_at, last_health_check, instance_id
- InvocationEvent: id, server_name, actor_object_id, timestamp, endpoint (sse|http|status), latency_ms, result_code
- OwnershipShare: id, server_name, shared_with (role|user_id), granted_by, granted_at
- ProvisioningLock (ephemeral): server_name, instance_id, lock_acquired_at, lock_ttl

## 14. High Level Architecture

Architecture overview (initial App Service host model, future Kubernetes migration option):

Core Components:

- Entry Layer: Single Azure App Service endpoint (80/443) receiving HTTP/SSE requests.
- Main Host Application (Starlette): Root app containing route-matching middleware and homepage/remove handlers.
- Configuration Database: Stores ServerConfig rows enabling dynamic discovery/onboarding.
- Redis (Distributed Coordination): Provides locks (mcp-lock:{server_name}) and readiness flags (mcp-ready:{server_name}).
- Sub-Applications: Dynamically mounted Starlette apps per server_name exposing /sse, /http (future), /status endpoints.
- Child MCP Server Processes: One process per mounted server communicating over stdio (stdin/stdout) with in-process MCP client stub.
- Telemetry & Audit: Emits provisioning/install/mount events and per invocation logs to monitoring backend.
- Authentication & Authorization: AAD bearer token validation; ownership and sharing enforced via ServerConfig + OwnershipShare.

Request Flow (Just-in-Time Provisioning):

1. Incoming request /{server_name}/sse
2. Middleware checks in-memory registry; if absent queries Configuration DB.
3. If server enabled and not mounted, attempts Redis lock acquisition.
4. On lock success: runs install_command (idempotent), executes startup_command, creates sub-app, mounts path, sets ready flag.
5. Routes request to /sse handler; in-process MCP client stub frames communication.
6. Subsequent requests bypass provisioning path and go directly to mounted sub-app.

Future Extensions:

- Streamable HTTP transport (/http) enabling bi-directional low-latency interactions per March 2025 MCP update.
- Optional Kubernetes deployment replacing App Service for granular scaling, network control, and service mesh integration.

Provide diagram link when available.

## 15. Dependencies

- Azure Subscription with required quotas (vCPUs, IPs, storage)
- AKS service availability in target region
- KMCP Helm charts repository availability
- Azure AD for identity and access

## 16. Assumptions

- Users have Azure CLI access and sufficient permissions
- Network outbound to Helm repo allowed
- Initial user base comfortable with Kubernetes basics

## 17. Release Plan / Milestones

| Milestone | Target Date | Description            | Exit Criteria                              |
| --------- | ----------- | ---------------------- | ------------------------------------------ |
| M1        | (set)       | Control plane runbook  | Successful AKS + KMCP deploy documented    |
| M2        | (set)       | Echo server deployment | Echo server running with status display    |
| M3        | (set)       | Audit + RBAC baseline  | Actions logged, role restrictions enforced |
| M4        | (set)       | MVP Launch             | Core goals met and docs complete           |

## 18. Metrics / KPIs

| Metric                              | Definition                                                          | Target (MVP) |
| ----------------------------------- | ------------------------------------------------------------------- | ------------ |
| Time to first server                | From start of provisioning to server Running                        | < 45 min     |
| Deployment success rate             | Successful server deployments / total                               | > 95%        |
| Mean status latency                 | Time to first visible status after create                           | < 15 s       |
| Rollback success rate               | Successful rollbacks / attempted                                    | 100%         |
| Adaptive doc generation latency     | Time from request to rendered parameterized runbook                 | < 10 s       |
| Readiness checklist completion time | Time from server scaffold to all mandatory checklist items complete | < 2 days     |
| Documentation freshness             | Percentage of core templates updated within 30 days                 | > 90%        |
| Feedback resolution time            | Median time from feedback submission to status update               | < 7 days     |
| JIT provisioning duration           | Time from first path request to server /status returning running    | < 60 s       |
| Provisioning success rate           | Successful JIT mounts / attempted mounts                            | > 95%        |
| Crash auto-recovery latency         | Time from failed process detection to successful next mount         | < 5 s        |
| Invocation audit coverage           | Percentage of requests with logged actor + server_name              | 100%         |
| Cost event fidelity                 | Variance between emitted cost events and actual billed usage        | < 5%         |
| Rate limit effectiveness            | Percentage of abusive bursts curtailed within first 3 requests      | > 90%        |
| Automated onboarding completion     | Percentage of new external users completing guided flow unaided     | > 70%        |
| Tier change restore time            | Time from tier modification to full network config restoration      | < 10 min     |
| Quota advisory responsiveness       | Time from >80% sustained quota usage to advisory alert              | < 5 min      |

## 19. Risks and Mitigations

| Risk                                 | Impact                                   | Likelihood | Mitigation                                                                           |
| ------------------------------------ | ---------------------------------------- | ---------- | ------------------------------------------------------------------------------------ |
| Helm chart instability               | Deployment failures                      | Medium     | Pin versions, smoke tests                                                            |
| Resource cost overrun                | Budget pressure                          | Medium     | Enforce tagging, right-size nodes                                                    |
| RBAC misconfiguration                | Security exposure                        | Low        | Least-privilege templates, review                                                    |
| Lack of observability                | Slow incident response                   | Medium     | Early metrics/log integration                                                        |
| Stale documentation                  | Misconfiguration risk                    | Medium     | Metadata freshness checks, update alerts                                             |
| Missing feedback loop                | Slow improvement cycle                   | Medium     | Inline feedback capture, triage SLA                                                  |
| Concurrent provisioning race         | Duplicate installs or inconsistent state | Low        | Redis lock with TTL + idempotent install commands                                    |
| Single host process bottleneck       | Throughput constraint                    | Medium     | Horizontal scale out, future Kubernetes migration                                    |
| Stdio process leaks                  | Resource exhaustion                      | Low        | Lifecycle monitoring, idle removal handler                                           |
| Parameter misconfiguration           | Cross-project data exposure              | Low        | Startup validation of required scope parameters                                      |
| Billing surprise (third-party model) | Unexpected spend reducing runway         | Medium     | Cost event emission, sponsorship exclusion checks, proactive alerts                  |
| Marketplace onboarding abandonment   | Lost customer acquisition                | High       | Guided external identity flow, guest invite automation, clear prerequisite messaging |
| APIM tier change configuration loss  | Service downtime / exposure              | Medium     | IaC backup & automated restore, tier change runbook                                  |
| Quota exhaustion (model rate limits) | Throttling impacting UX                  | Medium     | Quota monitoring, preemptive increase requests, burst smoothing                      |

## 20. Open Questions

- What level of multi-tenancy isolation is required initially?
- Which MCP server types beyond Echo are priority for templates?
- Preferred authentication model for UI/API (AAD only or token proxy)?
- Commit naming and versioning strategy for server definitions?

## 21. Appendices

### 21.1 Glossary

- MCP: Model Control Protocol
- KMCP: Kagent Model Control Platform (control plane implementation)
- AKS: Azure Kubernetes Service

### 21.2 References

#### Customer Notes

- [Agentic Tooling Think-Aloud Survey](https://hits.microsoft.com/note/8007824)
- [MCP Adoption Observation Note 8007462](https://hits.microsoft.com/note/8007462)
- [Context-Aware Documentation Personalization Study Note 8007405](https://hits.microsoft.com/note/8007405)
- CAIN MCP Server Host Service Design (internal): Azure App Service path-based multiplexing, JIT provisioning, configuration DB, Redis coordination, security model (AAD bearer, parameter isolation).
- Building AI Agents on Azure with MCP: Friction Points and Lessons Learned (internal): multitenant hosting patterns, sponsorship billing limitations, APIM tier networking impacts, customer onboarding complexity, load testing and capacity planning practices.

#### Proof of Concept Implementation

- KMCP Quickstart: https://kagent.dev/docs/kmcp/quickstart
- Project README: ../README.md
- Deployment Runbook: Create_MCP_AKS_Cluster.md

### 21.3 Change Log

| Date       | Version | Author   | Change                   |
| ---------- | ------- | -------- | ------------------------ |
| 2025-10-09 | 0.1     | (assign) | Initial skeleton created |

---

Template ready for refinement. Populate each placeholder with validated data during PR iteration.
