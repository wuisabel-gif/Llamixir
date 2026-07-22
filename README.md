# Llamixir

Llamixir is an Elixir/OTP operations layer for local AI runtimes. It discovers
models, monitors runtime health, and keeps backend failures observable through
supervised workers.

Llamixir combines an immediately useful model inventory with resilient runtime
supervision. Each inference backend becomes an isolated worker that can be
monitored, restarted, queued, and eventually routed through one endpoint.

## Current capabilities

- Supervised runtime workers using OTP and a `DynamicSupervisor`.
- A backend adapter contract that isolates runtime APIs.
- Ollama and llama.cpp health checks and model discovery.
- Loaded-model inventory and Ollama VRAM visibility.
- Normalized model metadata including size, family, and modification date.
- A small dependency-free CLI and aligned model inventory.
- Failure state that remains inspectable instead of crashing the application.
- Automatic worker recovery when a monitored runtime process crashes.
- A foreground daemon mode that exercises continuous supervision and polling.

## Try it

Requirements: Elixir 1.20+ and at least one supported local runtime.

```sh
mix test
mix escript.build
./llamixir
./llamixir status
./llamixir models
./llamixir running
./llamixir daemon
```

Point it at another Ollama server with:

```sh
LLAMIXIR_OLLAMA_URL=http://192.168.1.20:11434 ./llamixir models
```

Configure llama.cpp independently:

```sh
LLAMIXIR_LLAMA_CPP_URL=http://192.168.1.21:8080 ./llamixir models llamacpp
```

One-shot commands discover current state and exit. `llamixir daemon` stays in
the foreground, refreshes runtime state every five seconds, and lets OTP
restart failed monitoring workers. A local control socket will make one-shot
commands thin clients of that daemon in the next milestone.

## Architecture

```text
CLI / daemon
     |
Runtime Registry
     |
DynamicSupervisor
     |
Runtime Workers
   /       \
Ollama   llama.cpp
```

The adapter boundary covers health, installed models, and loaded models. The
next iterations will add a local control socket, lifecycle operations, live
metrics, request queues, and health-aware routing without moving
backend-specific behavior into the supervision core.

See [Architecture and roadmap](docs/architecture.md) for the daemon decision,
trade-offs, and planned delivery order.

## Development

```sh
mix format --check-formatted
mix test
```

## License

MIT © 2026 Isabella Wu
