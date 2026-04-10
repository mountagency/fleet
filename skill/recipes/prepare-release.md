---
name: prepare-release
description: Prepare a release -- changelog, dependency check, version bump, and validation
params:
  version: { required: true, description: "Version to release (e.g., 1.2.0)" }
  from: { default: "last tag", description: "Starting point for changelog" }
steps:
  - id: changelog
  - id: dep-check
  - id: version-bump
    needs: [changelog, dep-check]
  - id: validate
    needs: [version-bump]
outputs:
  - Updated CHANGELOG.md
  - Version bumped in package files
  - Validation report
  - Ready-to-merge release PR
---

## changelog

Generate a changelog for version {version}. Find commits since {from}:

```bash
git describe --tags --abbrev=0 2>/dev/null || echo "initial"
git log $(git describe --tags --abbrev=0 2>/dev/null || echo "HEAD~50")..HEAD --oneline --no-merges
```

Group changes: Added, Changed, Fixed, Removed, Security. Follow Keep a Changelog format.

Do NOT commit yet -- the version-bump step will commit everything together.

Write findings to `.fleet/session.md` including a summary of what's in this release.

## dep-check

Check dependencies for issues before release {version}:

1. Check for outdated dependencies with known security vulnerabilities
2. Run the project's dependency audit tool (`npm audit`, `bundle audit`, `pip audit`, etc.)
3. Flag any new dependencies added since {from} and their licenses

Write a dependency report to `.fleet/session.md`. Flag any blockers for the release.

Do NOT make changes -- just report.

## version-bump

Bump the version to {version}. The bridge will provide context from changelog and dep-check.

1. Update version numbers in all relevant files (package.json, Cargo.toml, version.rb, pyproject.toml, etc.)
2. If dep-check found blocking issues, address them
3. Add the changelog entry from the changelog step
4. Create a single commit: "Release {version}"
5. Create a PR: `gh pr create --title "Release {version}" --body "..."`

## validate

Final validation before the release PR is ready:

1. Run the full test suite
2. Verify version number is correct in all files
3. Verify CHANGELOG.md is properly formatted
4. Check CI status: `gh pr checks`

Post a validation report as a PR comment with verdict: Ready to merge / Needs attention.

Write findings to `.fleet/session.md`.
