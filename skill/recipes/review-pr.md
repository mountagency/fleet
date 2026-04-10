---
name: review-pr
description: Comprehensive PR review -- code quality, security, and test coverage
params:
  pr: { required: true, description: "PR number to review" }
  focus: { default: "all", description: "Review focus: all | security | performance | correctness" }
steps:
  - id: code-review
  - id: security-audit
  - id: coverage-check
  - id: synthesize
    needs: [code-review, security-audit, coverage-check]
outputs:
  - Individual reviews posted as GitHub PR comments
  - Synthesis comment with overall recommendation
---

## code-review

Review PR #{pr}. Read the full diff and PR description:

```bash
gh pr diff {pr}
gh pr view {pr}
```

Post a thorough code review focusing on:
- Logic correctness and edge cases
- Error handling completeness
- Naming clarity and code readability
- Whether the approach matches project conventions
- Opportunities for simplification

If focus is `{focus}` and not "all", weight your review toward that area.

Post your review using `gh pr review {pr} --comment --body "..."`.

Write your findings summary to `.fleet/session.md` before completing.

## security-audit

Security audit for PR #{pr}. Read the full diff:

```bash
gh pr diff {pr}
```

Check for:
- Input validation gaps (SQL injection, XSS, command injection)
- Authentication/authorization bypasses
- Secrets or credentials in code
- Insecure dependencies
- OWASP Top 10 vulnerabilities relevant to the changes

Post security findings as PR comments. Prefix critical issues with **SECURITY:**.

Write findings to `.fleet/session.md`.

## coverage-check

Test coverage analysis for PR #{pr}. Read the changed files:

```bash
gh pr diff {pr} --name-only
```

For each changed file:
1. Identify the corresponding test file
2. Check if tests exist for the modified code paths
3. Assess whether existing tests cover the new/changed behavior
4. Identify untested edge cases

Post a coverage summary as a PR comment listing files with adequate coverage, files with gaps, and suggested test cases to add.

Write findings to `.fleet/session.md`.

## synthesize

Read the session digests from the three review workers (the bridge will provide these in your context).

Write a single summary comment on PR #{pr} with:
1. **Overall recommendation**: Approve, Request Changes, or Comment
2. **Key findings** (top 3-5 across all reviews)
3. **Blockers** (must fix before merge)
4. **Suggestions** (nice to have, non-blocking)

Post using `gh pr review {pr} --comment --body "..."`.
