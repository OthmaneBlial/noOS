# Contributing

Start with a concrete bug reproduction or an unverified gate in
`docs/progress.json`. Keep runtime code in NASM and modules small. A new feature
must boot in QEMU, have one meaningful hardware/self-check, and leave `make test`
passing. Document its ABI and supported hardware; do not add a host simulation
to stand in for guest behavior.

For a normal contribution, fork and open a focused pull request. Describe the
observed behavior, the change and verification. Never include tokens, private
captures, generated build directories or personal host data. Respect existing
validation and interrupt/memory ownership rules.

Mark a progress gate only after its evidence passes, then run
`python3 tools/progress.py`. This refreshes README and the site's JSON copy.
Keep screenshots authentic (`make screenshot` on macOS) and documentation
source-grounded. Avoid performance claims without the measurement method.

Maintainer milestones are committed and pushed to main after checks pass.
Publishing a tag/release is separate from uploading a CI image artifact.
