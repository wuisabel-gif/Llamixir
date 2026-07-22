# Architecture and roadmap

Llamixir is choosing a daemon-centered architecture. Its core value is
continuous supervision, health-aware routing, queueing, and recovery across
heterogeneous local AI runtimes. Those behaviors require state that outlives a
single terminal command.

## Daemon and CLI responsibilities

The daemon owns long-lived concerns:

- runtime workers and their refresh timers;
- health and loaded-model state;
- restart and backoff policy;
- future request queues and routing decisions;
- event and benchmark history.

The CLI owns human interaction:

- querying daemon state;
- requesting lifecycle operations;
- rendering tables and diagnostics;
- starting a foreground daemon for development.

The daemon exposes a versioned JSON protocol over a Unix-domain socket.
One-shot commands query that socket when it is available and start short-lived
workers only as a fallback. This keeps scripts convenient while ensuring that
interactive operations share the daemon's authoritative state.

## Trade-offs

| Concern | One-shot CLI | Daemon |
| --- | --- | --- |
| Installation | Simpler | Requires service setup |
| Idle resources | None | Small persistent BEAM process |
| Current inventory | Good | Good |
| Historical state | Recomputed | Retained |
| Crash recovery | Not meaningful after exit | Continuous |
| Queues and failover | Impractical | Natural fit |
| Multi-client coordination | None | Centralized |

The project keeps one-shot commands because they are useful for scripts and
diagnostics, but new orchestration features belong in the daemon.

## Runtime boundary

Every backend implements three read operations:

1. health;
2. installed or served models;
3. currently loaded models and available memory metadata.

Lifecycle operations will be added as explicit capabilities rather than making
every adapter pretend to support every action. For example, an Ollama adapter
may support pulling and deleting, while a remote llama.cpp server may only
support observation and restart through an external process manager.

## Delivery roadmap

### 0.2 — Local control

- Unix-domain control socket with a versioned JSON protocol. Complete.
- CLI detection of a running daemon with one-shot fallback. Complete.
- Runtime state and health queries. Complete.
- Graceful daemon shutdown and stale-socket recovery. Complete.
- Recovery-event queries and bounded event history.

### 0.3 — Lifecycle

- Capability discovery per adapter.
- Start, stop, restart, unload, and delete where supported.
- Streaming model pulls with progress reporting.
- Structured error and audit events.

### 0.4 — Routing

- One OpenAI-compatible local endpoint.
- Health-aware model routing and bounded request queues.
- Retry and failover policies.
- Stable aliases independent of backend model identifiers.

### 0.5 — Operations

- Latency, throughput, queue depth, and memory history.
- Benchmark comparisons and model-fit recommendations.
- Service installers for macOS and Linux.
- Interactive terminal dashboard backed by the daemon protocol.

## Dependency policy

The supervision and adapter core stays dependency-light. New dependencies must
remove meaningful implementation risk. A maintained HTTP client becomes
justified when streaming downloads arrive, and a server library becomes
justified when the OpenAI-compatible routing endpoint is implemented.
