# Llamixir

Llamixir is an Elixir/OTP operations layer for local AI runtimes. It discovers
models, monitors runtime health, and keeps backend failures observable through
supervised workers.

This is an independent project inspired by terminal-first tooling's immediately useful model
inventory and terminal-first workflow. Llamixir's distinct purpose is runtime
supervision: each inference backend becomes an isolated worker that can be
monitored, restarted, queued, and eventually routed through one endpoint.

## Current capabilities

- Supervised runtime workers using OTP and a `DynamicSupervisor`.
- A backend adapter contract that isolates runtime APIs.
- Ollama health checks and model discovery through `/api/tags`.
- Normalized model metadata including size, family, and modification date.
- A small dependency-free CLI and aligned model inventory.
- Failure state that remains inspectable instead of crashing the application.
- Automatic worker recovery when a monitored runtime process crashes.

## Try it

Requirements: Elixir 1.20+ and, for live model discovery, Ollama.

```sh
mix test
mix escript.build
./llamixir
./llamixir status
./llamixir models
```

Point it at another Ollama server with:

```sh
LLAMIXIR_OLLAMA_URL=http://192.168.1.20:11434 ./llamixir models
```

## Architecture

```text
CLI / future TUI
       |
Runtime Registry
       |
DynamicSupervisor
       |
  Runtime Worker
       |
 Backend Adapter
       |
 Ollama HTTP API
```

The adapter boundary is intentionally small: health and model inventory. The
next iterations will add lifecycle operations, live metrics, request queues,
and a terminal dashboard without moving backend-specific behavior into the
supervision core.

## Development

```sh
mix format --check-formatted
mix test
```

## License

MIT © 2026 Isabella Wu
