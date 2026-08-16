# quiesce — examples

```text
/quiesce
/quiesce "prioritize the auth PRs first"
/quiesce --scope=pr:42 --auto-merge=hold
/quiesce --condition='NOT open PR AND every PR green' --max-pdca=3
/quiesce --driver=auto-orchestrator --auto-merge=authorized --auto-merge-reason="nightly convergence"
```
