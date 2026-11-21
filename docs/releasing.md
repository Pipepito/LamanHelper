# Releasing

Pushing a version tag releases the addon: the `Release` workflow
(`.github/workflows/release.yml`) checks that the tag, the TOC and the
changelog agree, runs the test suite, builds `NewbieNudge-<version>.zip` from
the `NewbieNudge/` folder, publishes a GitHub release with that zip, and
uploads the same zip to CurseForge. Nothing is zipped or uploaded by hand.

## Cutting a release

1. Set the version in `NewbieNudge/NewbieNudge.toc` (`## Version: 0.3.4`).
2. Add a `## 0.3.4 - YYYY-MM-DD` section at the top of `CHANGELOG.md`, written
   for players in English. It becomes the GitHub release notes and the
   CurseForge changelog as Markdown.
3. Run the checks locally: `python tests/run.py`, then
   `python tools/release.py check v0.3.4` (it reads the TOC and the changelog;
   no network).
4. Commit, then tag and push both:

   ```powershell
   git tag v0.3.4
   git push origin main v0.3.4
   ```

5. Watch the run under Actions on GitHub. When it is green, the release exists
   on GitHub and the file is on CurseForge, where it waits for CurseForge's
   moderation before players see it (usually minutes to a few hours).

Tags of the form `v0.4.0-beta1` or `v0.4.0-alpha2` publish a GitHub
pre-release and a CurseForge beta or alpha file. Everything else is a release.

### If the run fails

- *tag v0.3.4 says 0.3.4 but the TOC says 0.3.3*: bump the TOC, commit, delete
  the tag locally and remotely (`git tag -d v0.3.4`,
  `git push origin :refs/tags/v0.3.4`), tag again.
- *CHANGELOG.md has no '## 0.3.4' section*: add it (and do not leave
  "unreleased" in its heading).
- *CurseForge answered 4xx*: the token or project ID is wrong, or CurseForge
  rejected the metadata. The job prints the metadata it sent.
- To run the workflow again for an existing tag, use "Run workflow" on the
  Release workflow page and enter the tag, or
  `gh workflow run release.yml --ref v0.3.4 -f tag=v0.3.4`. Re-running
  replaces the GitHub asset and uploads a new CurseForge file.

## One-time setup

- **CurseForge project:** created on <https://authors.curseforge.com> for
  World of Warcraft. Its numeric project ID goes in the TOC as
  `## X-Curse-Project-ID: 123456`; the release check refuses the placeholder 0.
- **API token:** generated on <https://authors.curseforge.com/#/settings/api-tokens>
  and stored as the repository secret `CF_API_TOKEN`:

  ```powershell
  gh secret set CF_API_TOKEN --repo Pipepito/newbie-nudge
  ```

  The command prompts for the value and never shows it. The token belongs to
  the CurseForge account, so it is not in the repository.
- **Game version:** derived from `## Interface:` in the TOC the same way the
  BigWigs packager does it (16001 becomes 1.60.1 in the Forever flavor). If
  CurseForge does not list that version yet, the newest version of the same
  flavor is used and the job prints a warning.

## Pieces

| File | Role |
|---|---|
| `.github/workflows/release.yml` | The workflow. |
| `tools/release.py` | `check`, `build`, `notes` and `cf-metadata` subcommands; unit tests in `tests/test_release.py`. |
| `CHANGELOG.md` | Source of the release notes. |
| `NewbieNudge/NewbieNudge.toc` | Version, interface and CurseForge project ID. |
