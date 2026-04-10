---
name: index-codebase
description: Generate a lightweight codebase index for Fleet's context engine -- file graph, feature map, dependency clusters
params:
  focus: { default: "full", description: "Indexing scope: full | backend | frontend | api | tests" }
steps:
  - id: generate-index
outputs:
  - .fleet/index/codebase.json populated with file graph, features, and dependency clusters
  - Index committed to the branch
---

## generate-index

Generate a codebase index at `.fleet/index/codebase.json`. This index gives the bridge a file-level map of the codebase for context assembly -- which files exist, what they do, how they relate, and what features they belong to.

### Step 1: File inventory

Get all tracked files with their last modification dates:

```bash
git ls-files
```

If focus is `{focus}` and not "full", filter to relevant paths:
- **backend**: `app/models/`, `app/controllers/`, `app/services/`, `lib/`, `config/`, and similar server-side paths
- **frontend**: `app/javascript/`, `app/views/`, `src/`, `components/`, `pages/`, and similar client-side paths
- **api**: `app/controllers/api/`, `app/serializers/`, `app/graphql/`, and similar API paths
- **tests**: `spec/`, `test/`, `tests/`, `__tests__/`, and similar test paths

### Step 2: Classify files

For each file, determine its `type` based on path patterns. Use these heuristics (adapt to the actual codebase structure):

| Pattern | Type |
|---------|------|
| `**/models/**`, `**/entities/**` | model |
| `**/controllers/**`, `**/handlers/**` | controller |
| `**/services/**`, `**/use_cases/**` | service |
| `**/views/**`, `**/templates/**`, `**/components/**` | view |
| `**/serializers/**`, `**/presenters/**` | serializer |
| `spec/**`, `test/**`, `tests/**`, `**/*_test.*`, `**/*.test.*`, `**/*.spec.*` | test |
| `**/jobs/**`, `**/workers/**` | job |
| `**/mailers/**`, `**/notifications/**` | mailer |
| `**/migrations/**` | migration |
| `config/**`, `**/config.*`, `.env*` | config |
| `db/**` | database |
| `lib/**` | library |
| `scripts/**`, `bin/**` | script |
| `docs/**`, `*.md` | documentation |

If a file doesn't match any pattern, classify it as `other`.

### Step 3: Extract imports and find test associations

For each non-test, non-config, non-documentation file:

1. **Extract imports/requires.** Grep the file for import statements. Match the patterns relevant to the language:
   - JavaScript/TypeScript: `import ... from '...'`, `require('...')`
   - Ruby: `require '...'`, `require_relative '...'`
   - Python: `import ...`, `from ... import ...`
   - Go: `import "..."`, `import (...)`
   - Rust: `use ...`, `mod ...`

   Resolve relative paths where possible. Store as a list of file paths (not package names for external deps).

2. **Find test files.** Match by naming convention:
   - `app/models/order.rb` → `spec/models/order_spec.rb` or `test/models/order_test.rb`
   - `src/components/Button.tsx` → `src/components/Button.test.tsx` or `src/components/__tests__/Button.test.tsx`
   - `pkg/handler.go` → `pkg/handler_test.go`

   Only list test files that actually exist in the file inventory.

### Step 4: Detect features

Features are groups of files that form a logical unit. Detect them using three signals:

1. **Directory structure.** If the codebase is organized by feature (e.g., `app/features/checkout/`, `modules/payments/`), each directory is a feature. If organized by layer (e.g., `app/models/`, `app/controllers/`), infer features from naming (all files containing `order` in the name likely relate to an "orders" feature).

2. **Naming conventions.** Group files by shared stems: `order_service.rb`, `orders_controller.rb`, `order_spec.rb` → feature "orders".

3. **Co-change patterns.** Use git log to find files that frequently change together:

```bash
git log --oneline --name-only --since="6 months ago" | awk '/^$/{next} /^[a-f0-9]/{commit=$0; next} {print commit, $0}' | sort | uniq
```

Files that appear in the same commits 3+ times (and aren't in the same directory) likely belong to the same feature. Use this to supplement directory/naming signals, not replace them.

For each feature, identify:
- `files`: all files belonging to the feature
- `entry_points`: controllers, CLI commands, or top-level scripts that serve as entry points
- `description`: one-line summary of the feature's purpose (inferred from file names and directory structure)

### Step 5: Identify dependency clusters

Dependency clusters are groups of files tightly coupled through imports that also share an external dependency. Look for:
- Files that import each other heavily (3+ mutual imports)
- Files that share imports of a specific external library (e.g., multiple files importing from `stripe`, `aws-sdk`)

For each cluster:
- `name`: descriptive name based on the shared dependency or purpose
- `files`: files in the cluster
- `external_deps`: external packages/libraries they share

### Step 6: Write summaries for high-change files

Identify files with high change frequency:

```bash
git log --format=%H --since="3 months ago" -- <file> | wc -l
```

Files with 10+ changes in the last 3 months are "high" frequency. Files with 5-9 are "medium". Below 5 is "low".

For files with "high" change frequency, write a one-line summary by reading the first ~30 lines of the file (class definition, top-level comments, function signatures). The summary should explain what the file *does*, not what it *is* -- e.g., "Handles order lifecycle state machine and validates transitions" not "Order model".

### Step 7: Build the `imported_by` reverse index

After processing all files, compute the reverse import graph: for each file that appears in any other file's `imports` list, record which files import it in an `imported_by` field.

### Step 8: Assemble and write the index

Combine everything into `.fleet/index/codebase.json` matching this structure:

```json
{
  "version": 1,
  "generated_at": "<ISO-8601 timestamp>",
  "commit": "<current HEAD short sha>",
  "files": {
    "<file_path>": {
      "type": "<classified type>",
      "feature": ["<feature1>", "<feature2>"],
      "imports": ["<path1>", "<path2>"],
      "imported_by": ["<path1>", "<path2>"],
      "tests": ["<test_path>"],
      "last_modified": "<YYYY-MM-DD from git log>",
      "change_frequency": "high|medium|low",
      "summary": "<one-line summary, only for high-frequency files>"
    }
  },
  "features": {
    "<feature_name>": {
      "files": ["<path1>", "<path2>"],
      "entry_points": ["<controller_or_cli_path>"],
      "description": "<one-line description>"
    }
  },
  "dependency_clusters": [
    {
      "name": "<cluster-name>",
      "files": ["<path1>", "<path2>"],
      "external_deps": ["<package1>"]
    }
  ]
}
```

Keep the JSON compact but readable (2-space indentation). For repos with 500+ files, omit `imported_by` lists longer than 5 entries (keep top 5 by change frequency) and omit summaries for low-frequency files to keep the index under 500KB.

### Step 9: Commit

```bash
git add .fleet/index/codebase.json
git commit -m "Generate codebase index for Fleet context engine

Built from $(git ls-files | wc -l | tr -d ' ') tracked files at $(git rev-parse --short HEAD).
Includes file graph, feature map, and dependency clusters."
```
