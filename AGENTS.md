# noOS collaboration

Runtime code is NASM Assembly only. Build/test tools may use Make and Python.
Read the modules and their callers before changing interrupt/context layouts.

For each completed meaningful milestone, run the relevant real QEMU tests,
update docs and verified progress, commit it and push directly to origin/main.
The user explicitly requested this workflow and many meaningful commits.
Keep commits coherent; do not create empty or artificial history.

Progress comes from docs/progress.json, rendered by tools/progress.py and shared
with the site. Mark gates only after actual evidence. The 40 v0.1 gates are
complete; future roadmap scopes need explicit new gates, not fabricated credit.
Run make test and inspect exact-head CI before reporting the build verified.

Keep data/noos-data.img private and preserved by make clean. Never stage build,
credentials or private artifacts. Never force-push, delete a remote repository,
change visibility or modify unrelated shared GitHub Pages folders. Publishing
the site uses the existing noOS/ folder of OthmaneBlial.github.io on master.

Physical hardware, UEFI and x86-64 are unverified. Document limits: one synchronous
user process, no NX in non-PAE paging, bounded experimental noFS persistence.
