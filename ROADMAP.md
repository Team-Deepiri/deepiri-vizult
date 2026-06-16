# deepiri-vizult roadmap

This document tracks **where the tool is today** and **planned evolution**. Priorities can shift; update this file when scope changes.

## Goals

- Stay **local-first**: no required hosted service; outputs are files you can diff, commit, or open offline.
- Stay **discovery-driven**: no hardcoded service catalogs; the graph comes from your repo’s compose, K8s, Skaffold, packages, and code.
- Stay **useful for Deepiri-scale** monorepos: many services, submodules, mixed Node/Python, Redis/Kafka-shaped usage.

---

## Shipped (as of v0.3.x)


| Area                                                                               | Status |
| ---------------------------------------------------------------------------------- | ------ |
| CLI (`scan`, `render`, `open`, `query`, `diff`, `version`)                         | Done   |
| Graph model + `graph.json` + `Graph#merge_prefixed!`                               | Done   |
| Mermaid + **Graphviz `.dot`** + `**edges.csv**`                                    | Done   |
| Offline HTML viewer (Cytoscape.js, **min-confidence filter**)                      | Done   |
| Docker Compose, Kubernetes, Skaffold                                               | Done   |
| Git / `.gitmodules` / sibling repos                                                | Done   |
| `**--submodules` — per-checkout scan merged with `sm<hash>_` prefixes              | Done   |
| Optional `gh` org repo listing                                                     | Done   |
| Package / source / stream / DB / WebSocket heuristics                              | Done   |
| RSpec (incl. integration, merge, exports, submodule path parser)                   | Done   |
| **GitHub Actions** CI (`rspec`, `gem build`, RuboCop, Ruby version matrix 3.0-3.2) | Done   |
| **docs/INTERPRETING.md**                                                           | Done   |
| Apache 2.0 + `NOTICE`                                                              | Done   |


---

## Near term (0.4.x)

1. **Accuracy & noise** — Tune regex families (especially stream/Kafka); optional “strict” mode.
2. **Dedup** — When `--submodules` overlaps main-tree scan, optional dedupe or provenance tags only.
3. **RubyGems** — Publish workflow + changelog on release. 

---

## Mid term (0.5.x+)

1. **Tree-sitter** (or similar) for TS/JS/Python call targets.
2. **OpenAPI / gRPC** — Endpoint nodes from `openapi.yaml` / `*.proto`.
3. **Terraform / Helm** — Ingress hosts, module outputs.
4. **Incremental scan** — `.vizult-cache/` file-hash skip (opt-in).

---

## Longer term / research

1. **Data-flow semantics** — read/write labels where inferable.
2. **Policy / `vizult lint`** — Composable rule packs.
3. **IDE** — Jump graph node → source evidence.

---

## Out of scope (for now)

- Live cluster traffic or APM replacement.

---

## How to use this roadmap

- Open issues/PRs against a target milestone; update this file when you ship.

---

*Last updated: 2026-04-04.*