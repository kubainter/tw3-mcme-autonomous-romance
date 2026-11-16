## Checklist

- [ ] `scripts/precheck_syntax.ps1` passes locally (or CI is green)
- [ ] `CHANGELOG.md` has an entry for this change — top `## [X.Y.Z]` section + Nexus snippet updated
- [ ] README.md / docs updated if behavior changed — docs describe only implemented features, never roadmap items
- [ ] No secrets, `.env`, or local-only files in the diff (`plans/` lives in `.git/info/exclude`)
- [ ] Release PRs: version tag matches the newest `## [X.Y.Z]` heading in CHANGELOG.md
