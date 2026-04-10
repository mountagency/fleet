---
name: onboard-codebase
description: Deep codebase analysis -- architecture, conventions, test coverage, synthesized into Fleet knowledge
params:
  focus: { default: "full", description: "Focus area: full | backend | frontend | api | data" }
steps:
  - id: architecture-audit
  - id: convention-discovery
  - id: test-coverage-map
  - id: synthesize
    needs: [architecture-audit, convention-discovery, test-coverage-map]
outputs:
  - .fleet/knowledge/architecture.md populated
  - .fleet/knowledge/conventions.md populated
  - .fleet/knowledge/gotchas.md populated
  - Onboarding summary for new developers
---

## architecture-audit

Map the architecture of this codebase.

Explore systematically:
1. **Entry points**: Where does execution start?
2. **Layer structure**: How is the code organized?
3. **Key abstractions**: Core domain objects/services/modules
4. **Data flow**: How does data move through the system?
5. **External integrations**: Third-party services, databases, APIs
6. **Build and deploy**: How is it built and deployed?

Read key files -- don't just list directories. Understand the *why*.

Write findings directly to `.fleet/knowledge/architecture.md`. Also note gotchas in `.fleet/knowledge/gotchas.md`.

## convention-discovery

Discover coding conventions by reading 5-10 representative files per category:

1. **Naming**: Files, classes, functions, variables
2. **Code organization**: Where different types of code live
3. **Error handling**: Patterns, custom error classes
4. **Testing**: Framework, patterns, factories/fixtures
5. **API patterns**: Endpoint structure, serialization, validation
6. **Configuration**: Env vars, config files, feature flags

Write findings to `.fleet/knowledge/conventions.md`. Format as clear rules a developer can follow.

## test-coverage-map

Map the test coverage landscape:

1. **Test framework and setup**: What tools, how to run
2. **Coverage by area**: Well-tested vs. under-tested areas
3. **Test types**: Unit, integration, e2e -- what exists
4. **Test infrastructure**: Factories, fixtures, helpers
5. **CI configuration**: How tests run in CI
6. **Critical gaps**: Important untested code paths

Run the test suite if possible. Write coverage map to `.fleet/session.md`. Flag critical gaps in `.fleet/knowledge/gotchas.md`.

## synthesize

Read the knowledge files the other workers wrote. Clean them up:
- Remove contradictions
- Consolidate overlapping findings
- Ensure consistent formatting
- Add cross-references

Commit the knowledge files:

```bash
git add .fleet/knowledge/
git commit -m "Populate Fleet knowledge base from codebase onboarding"
```
