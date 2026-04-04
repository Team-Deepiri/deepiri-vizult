# deepiri-vizult

Local-first architecture graph for microservice repos. Scans **Docker Compose**, **Kubernetes** manifests, **Skaffold** (`build.artifacts`, `deploy.kubectl.manifests`), **package manifests**, and **source code** (HTTP URLs, env defaults, Redis/Kafka-style patterns, WebSockets, DB env hints) with **no hardcoded service names**—services and links are inferred from your tree.

## Install

```bash
cd deepiri-vizult
./bin/setup              # Ruby 3+ check, bundle install, usage hints
./bin/setup --verify     # also runs RSpec
bundle exec ruby exe/vizult help
```

Without the script: `bundle install` then use `exe/vizult` as below.

Or add to your Gemfile:

```ruby
gem "deepiri-vizult", path: "../deepiri-vizult"
```

## Usage

```bash
# Scan a project (writes vizult-output/ under that project)
bundle exec ruby exe/vizult scan /path/to/deepiri-platform

# Same as scan (explicit name for CI/scripts)
bundle exec ruby exe/vizult render /path/to/project --format all

# JSON only
bundle exec ruby exe/vizult scan /path/to/project --format json

# Open interactive HTML graph (Cytoscape.js, no server)
bundle exec ruby exe/vizult open

# Edges matching a substring
bundle exec ruby exe/vizult query gateway

# Compare current graph.json to a git revision (after you commit graph output)
bundle exec ruby exe/vizult diff HEAD~1

# Include sibling repos (parent directory with other git clones)
bundle exec ruby exe/vizult scan . --siblings

# Full scan + merge each sibling repo (sb* prefixes, scan_overlay bridges)
bundle exec ruby exe/vizult scan . --siblings-scan

# Low-confidence same_org edges between sibling pairs sharing git org (optional)
bundle exec ruby exe/vizult scan . --infer-org-links

# Merge an isolated scan per .gitmodules checkout (prefixed node ids)
bundle exec ruby exe/vizult scan . --submodules

# Remote repo names via GitHub CLI (optional)
bundle exec ruby exe/vizult scan . --org Team-Deepiri

# Version
bundle exec ruby exe/vizult version
```

Run tests: `bundle exec rake` or `bundle exec rspec`.

## Verification checklist

- `./bin/setup --verify` — bundle install + full RSpec (same as CI-style check).
- `bundle exec rspec` — full suite (graph merge, sibling / manifest linkers, HTML viewer, DOT/CSV, submodule paths, scanners, CLI, integration).
- `bundle exec ruby exe/vizult help` — lists `scan`, `render`, `open`, `query`, `diff`, `version` (see `scan` for `--siblings-scan`, `--infer-org-links`).
- Smoke on a real tree, e.g. `bundle exec ruby exe/vizult scan /path/to/deepiri-platform --siblings` (or `--siblings-scan` for merged subgraphs per sister repo).
- After `vizult scan`, outputs appear under `<project>/vizult-output/` (gitignored). If a Docker run created files as root, fix with `sudo chown -R "$USER" vizult-output` or remove that directory.

`Gemfile.lock` is tracked for reproducible `bundle install` in CI and local dev.

## Outputs

| File | Description |
|------|-------------|
| `vizult-output/graph.json` | Full typed graph (nodes, edges, evidence) |
| `vizult-output/system.mmd` | Mermaid flowchart (all edges) |
| `vizult-output/repos.mmd` | Repo / import relationships |
| `vizult-output/data-flow.mmd` | Streams + DB access |
| `vizult-output/http.mmd` | HTTP proxy + calls |
| `vizult-output/*.dot` | Graphviz (same views as Mermaid; `dot -Tpng system.dot -o out.png`) |
| `vizult-output/edges.csv` | All edges (from, to, type, confidence, file, line) |
| `vizult-output/index.html` | Offline graph viewer (filters include min confidence) |

Set `VIZULT_DEBUG=1` to print parse warnings.

## Interpreting output

See [docs/INTERPRETING.md](docs/INTERPRETING.md) for node/edge types, confidence levels, and limits.

## Roadmap

Planned work and milestones: [ROADMAP.md](ROADMAP.md).

## License

Copyright 2026 Deepiri. Licensed under the [Apache License 2.0](LICENSE).
