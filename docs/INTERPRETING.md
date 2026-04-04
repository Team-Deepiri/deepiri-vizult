# Interpreting vizult output

## Node types

| Type | Meaning |
|------|--------|
| `repo` | A git repository (root, sibling, submodule, or remote-only from `gh`). |
| `service` | A process inferred from Docker Compose, Kubernetes, Skaffold, or HTTP targets. |
| `stream` | A message topic or stream name found via pub/sub-style patterns in code. |
| `database` | A datastore hint (env vars, Prisma datasource, etc.). |
| `endpoint` | Skaffold file, configmap summary, WebSocket aggregate, or package manifest node. |

## Edge types

| Type | Meaning |
|------|--------|
| `contains` | Repo contains another repo or a Skaffold/config artifact. |
| `depends_on` | Docker Compose `depends_on` (startup order). |
| `http_call` / `http_proxy` | Inferred HTTP client or reverse-proxy target to another service hostname. |
| `publishes` / `consumes` | Heuristic stream producer / consumer. |
| `db_access` | Connection-string or ORM hint toward a database node. |
| `websocket` | Socket.IO / WebSocket usage detected in source. |
| `imports` | Internal package dependency (heuristic from `package.json` / `Gemfile`). |
| `adjacent_clone` | **Inferred:** scan root and a sibling git repo share a parent directory, but no other edge connected them. Not a runtime dependency. |
| `same_org` | **Inferred (optional `--infer-org-links`):** two **sibling** repos share the same GitHub org from `git` remote metadata, and had no path between them yet. Often unused when `adjacent_clone` already connected the platform via the root repo. |
| `manifest_ref` | `package.json` (`file:` / `link:`) or `go.mod` (`replace => ../…`) points at another repo directory name next to the scan root. |
| `scan_overlay` | With `--siblings-scan`, links the canonical `repo:<name>` node to the prefixed copy (`sb…_repo:<name>`) from the merged sibling scan. |

## Confidence

- **high** — Parsed from infrastructure (e.g. Compose `depends_on`, explicit URL in compose env) or clear string URL in code.
- **medium** — Resolved via `process.env.* \|\| 'default'` or similar; manifest-based `manifest_ref`.
- **low** — Broad pattern match (e.g. generic WebSocket line); **inferred** cross-repo edges (`adjacent_clone`, `same_org`) always include `metadata.inference` and render dashed in HTML / Mermaid / Graphviz where supported.

Use the HTML viewer’s **Min edge confidence** filter to hide noisy edges.

## Submodule merge (`--submodules`)

A second pass runs a full scan from each `.gitmodules` checkout path under the root and **merges** the result with node ids prefixed `sm<8-hex>_` so subgraphs do not collide. You may see overlap with the main tree scan; use `--submodules` when you want isolated per-submodule graphs in one file set.

## Sibling repos (`--siblings`, `--siblings-scan`)

By default, sibling git checkouts under the **same parent folder** become `repo` nodes. They are **not** fully scanned unless you pass **`--siblings-scan`**, which runs the same pipeline on each sibling and merges with ids prefixed `sb<8-hex>_`, then adds **`scan_overlay`** from `repo:<name>` to the prefixed repo node.

After scanning, **manifest** hints (`ManifestSiblingRefs`) run on the root and each sibling directory. **`CrossRepoLinker`** adds **`adjacent_clone`** edges from the scan root’s repo to each sibling repo when the graph had no connecting path (co-located clones, not a wire). Optional **`--infer-org-links`** adds low-confidence **`same_org`** edges between sibling pairs that share `git` remote org metadata when there was still no path (rare if `adjacent_clone` already linked the set through the root).

## Mermaid vs Graphviz vs CSV

- **`.mmd`** — Paste into Mermaid Live or docs.
- **`.dot`** — `dot -Tpng system.dot -o system.png` (Graphviz).
- **`edges.csv`** — Filter/sort in a spreadsheet or import into other tools.

## Limits

vizult is **static** and **regex/heuristic-heavy**. It does not execute your stack or guarantee complete data-flow correctness. Treat the graph as a **map for navigation and review**, not a formal verification artifact unless you tighten rules in your own process.
