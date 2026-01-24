# Git Operations in Kargo

> ⚠️ **SSH Key Required**: Git push operations require SSH credentials with write access.
> Run `./scripts/setup-git-credentials.sh` and add the key to GitHub.
> See the main [README](../../README.md) for details.

## Worktrees: Multiple branches at once

Kargo uses **git worktrees** to checkout multiple branches simultaneously:

```yaml
- uses: git-clone
  config:
    checkout:
      - branch: main        # Source code → ./src
        path: ./src
      - branch: env/dev     # Target manifests → ./out
        path: ./out
```

Both directories share one `.git` database but contain different branches.

---

## git-clear: Why you need it

After cloning, `./out` contains **old files** from the previous promotion. Without clearing:

```
Promotion 1 → [deployment.yaml]
Promotion 2 → [deployment.yaml, service.yaml]  ← deployment.yaml may be stale!
```

**git-clear** empties the directory while preserving the worktree link:

```yaml
- uses: git-clear
  config:
    path: ./out    # Clears all files, keeps .git metadata
```

---

## Standard Pattern

```yaml
steps:
  - uses: git-clone
    config:
      checkout:
        - branch: main
          path: ./src
        - branch: env/${{ ctx.stage }}
          path: ./out

  - uses: git-clear              # Clear old files
    config:
      path: ./out

  - uses: kustomize-build        # Generate fresh manifests
    config:
      path: ./src/envs/${{ ctx.stage }}
      outPath: ./out

  - uses: git-commit
    config:
      path: ./out

  - uses: git-push
    config:
      path: ./out
      targetBranch: env/${{ ctx.stage }}
```

---

## Quick Reference

| When to use git-clear | Yes/No |
|-----------------------|--------|
| Regenerating all manifests (kustomize/helm) | ✅ Yes |
| Updating a single file (yaml-update) | ❌ No |
| Adding files without replacing | ❌ No |

**⚠️ Common mistakes:**
- Clearing `./src` instead of `./out` (deletes source!)
- Calling git-clear *before* git-clone (nothing to clear yet)
