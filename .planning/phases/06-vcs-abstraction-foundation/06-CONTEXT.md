# Phase 6: VCS Abstraction Foundation - Context

**Gathered:** 2026-03-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Extract a VCS-neutral abstraction layer from existing Git-specific units. Introduce shared types (DX.Blame.VCS.Types), a shared process base class (DX.Blame.VCS.Process), an IVCSProvider interface, and a TGitProvider wrapper. Existing Git blame must work identically afterward. No Mercurial implementation in this phase.

</domain>

<decisions>
## Implementation Decisions

### Process base class design
- TVCSProcess is the base class owning all CreateProcess+pipe capture logic (Execute, ExecuteAsync, CancelProcess)
- TGitProcess and future THgProcess are thin subclasses that only pass the correct executable path
- CancelProcess remains a class method on TVCSProcess (callable without instance, just needs handle)
- The duplicated ExecuteGitSync in Git.Discovery is eliminated — discovery units use TVCSProcess.Execute instead
- TVCSProcess lives in its own unit: DX.Blame.VCS.Process (mirrors the current Git.Types / Git.Process split)

### Claude's Discretion
- Interface granularity (single IVCSProvider vs split interfaces) — choose what fits the existing call sites best
- Unit namespace organization — naming convention for new VCS-neutral units beyond VCS.Types and VCS.Process
- Type migration scope — which types move to VCS.Types vs stay Git-specific (e.g., sentinel values for uncommitted lines)
- Whether Git.Blame and Git.Process remain as implementation units behind TGitProvider or get folded in
- TCommitDetail record placement (stays in CommitDetail unit or moves to VCS.Types)

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches. The user confirmed all recommended options, favoring maximum DRY and clean SoC.

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- TGitProcess (src/DX.Blame.Git.Process.pas): Full CreateProcess+pipe implementation — becomes TVCSProcess base
- TBlameLineInfo, TBlameData (src/DX.Blame.Git.Types.pas): VCS-neutral blame data types ready to move
- TCommitDetail, TCommitDetailCache (src/DX.Blame.CommitDetail.pas): Commit detail types used by popup/diff

### Established Patterns
- Async thread pattern: TBlameThread and TCommitDetailThread both create TGitProcess, execute, and Queue results to main thread
- Singleton pattern: BlameEngine and CommitDetailCache are lazy-initialized global singletons
- Discovery caching: Git path and repo root cached per session, cleared on project switch

### Integration Points
- DX.Blame.Engine uses Git.Types, Git.Discovery, Git.Process, Git.Blame, CommitDetail — primary refactoring target for Phase 7
- DX.Blame.Navigation uses Git.Types, Git.Discovery, Git.Process — will dispatch through provider in Phase 7
- DX.Blame.CommitDetail uses Git.Discovery, Git.Process — will dispatch through provider in Phase 7
- ExecuteGitSync in Git.Discovery (lines 58-124) duplicates TGitProcess pipe logic — must be unified into TVCSProcess

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 06-vcs-abstraction-foundation*
*Context gathered: 2026-03-23*
