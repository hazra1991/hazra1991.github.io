---
layout: post
title: "Git in One Page: A Quick Summary"
date: 2026-11-10
description: "The whole Git picture in a few minutes: commits, branches, merging, rebase, reset, remotes, tracking and config, then a short list of everyday commands. Links to the full explanations."
categories: [Developer Tools, Git]
tags: [git, summary, cheatsheet]
---

> **Git series:** **Quick Summary** · [1. Commits, Branches and Merging]({{ site.posts | where: "slug", "git-part-1" | first.url | relative_url }}) · [2. Remotes and Pointers]({{ site.posts | where: "slug", "git-part-2" | first.url | relative_url }}) · [Cheat Sheet]({{ site.posts | where: "slug", "git-cheat-sheet" | first.url | relative_url }})
{: .prompt-info}

This is the short version. Read it when you only need to be reminded; follow the links when something doesn't click.

## **The core idea**

> Details: [full explanation]({{ site.posts | where: "slug", "git-part-1" | first.url | relative_url }}#commits)
{: .prompt-tip}

- A **commit** is a saved snapshot. It points back at its **parent**. History = these parent links, nothing else.
- Commits never change. Anything new (commit, merge, rebase, cherry-pick) gets a **new SHA**.
- A **branch** is a pointer: a small file holding one SHA. Names exist only because we can't remember SHAs.
- **HEAD** = where you are. It normally points at a branch; the branch points at a commit.
- Creating, moving or deleting a branch never touches commits. Deleting a branch doesn't delete history.

```
A ← B ← C            main (HEAD)
         \
          D ← E      feature
```

## **Merging**

> Details: [full explanation]({{ site.posts | where: "slug", "git-part-1" | first.url | relative_url }}#three-way)
{: .prompt-tip}

**Merge base** = the newest commit both branches share (`C` above). Git needs three versions to merge: base, yours, theirs.

| Situation | What happens |
|---|---|
| Only one side moved | **Fast-forward**: the pointer just slides along existing history. No new commit. |
| Both sides moved | **Three-way merge**: new merge commit `M` with **two parents**. This is the "knot". |
| Same lines changed on both sides | **Conflict**: you pick; `-X theirs/ours` only decides conflicting lines. |
| No shared history at all | "Unrelated histories": refused unless `--allow-unrelated-histories`. |

- After a merge, the next merge base is the old feature tip, not `M`. So the same conflict doesn't come back.
- **Same code ≠ related.** Two repos can have identical files and still share no commits. Relatedness is arrows, not content.
- `git merge-base A B` prints where they diverged; for unrelated branches it prints nothing.
- **Squash** and **cherry-pick** copy *content* into a new commit with no arrow to the source. Squash = "I want the result, not the story". Cherry-pick keeps the message, gets its own new SHA, and can conflict.

## **Rebase**

> Details: [full explanation]({{ site.posts | where: "slug", "git-part-1" | first.url | relative_url }}#rebase)
{: .prompt-tip}

- Replays your commits on top of another branch. The commits are **new** (new SHAs); the old ones are left behind.
- Result is a straight line, no merge commit.
- Don't rebase commits other people already have. If you must, a force push is needed afterwards.
- During a rebase "ours" and "theirs" flip (ours = the branch you're rebasing onto).
- Stuck? `git rebase --abort` goes back to before. (`--quit` just stops and leaves things half-done, it does not undo.)

## **Moving pointers: reset**

> Details: [full explanation]({{ site.posts | where: "slug", "git-part-1" | first.url | relative_url }}#reset)
{: .prompt-tip}

```
git reset --soft  B    # move the branch only; changes stay staged
git reset --mixed B    # (default) also unstage; files untouched
git reset --hard  B    # also overwrite files: the only one that loses uncommitted work
```

- `B` can be anything that resolves to a commit: a SHA, `HEAD~2`, a branch, a tag, a remote-tracking branch (`origin/main`).
- A branch can be pointed anywhere, even somewhere unrelated.
- **Nothing committed is lost**: `git reflog` lists where HEAD has been (kept ~90 days, unreachable ~30).

## **Remotes**

> Details: [full explanation]({{ site.posts | where: "slug", "git-part-2" | first.url | relative_url }}#remote)
{: .prompt-tip}

- A remote is just another copy of the repo (GitHub, a server, a folder).
- **`origin` is a local nickname** stored in your config. It could be `abc` or `myorigin`. `git clone` simply names it origin.
- Works without clone:
  ```
  git init
  git remote add origin git@github.com:you/prism.git
  git fetch origin
  git checkout main          # creates main and sets it to track origin/main
  ```
- **`origin/main`** = *nickname/branch*. It is **your local record** of where their `main` was last time you looked. It lives in `refs/remotes/origin/main`. Not live, not online.

```
main          ← local branch
origin/main   ← local record of the remote's main
```

- **Fetch** downloads new commits and moves `origin/*` only. It never touches HEAD, your branches or your files.
- If `main` tracks `origin/main`, after a fetch `origin/main` is ahead and `main` lags (`git status` says "behind N"). You decide how to catch up: `merge`, `rebase`, or `reset --hard origin/main`.
- **Pull** = fetch + merge (or rebase with `--rebase`).
- **Push** = ask the remote to move *its* pointer to your commit. Refused unless it's a fast-forward.
- **Force push** = ask it to move the pointer anywhere. Safer: `--force-with-lease` (refuses if someone pushed since your last fetch).
- `git reset --hard origin/main` is **local only**: no network. It resolves the name to a commit and moves your branch. It does **not** set tracking.

## **Tracking**

> Details: [full explanation]({{ site.posts | where: "slug", "git-part-2" | first.url | relative_url }}#tracking)
{: .prompt-tip}

- Tracking is just two lines in config: `branch.<name>.remote` and `branch.<name>.merge`.
- `git branch -u origin/main` sets it. `git branch -vv` shows it.
- Several remotes in one clone = several repos in one folder. Each local branch can track a different one.
- Swap what a branch follows:
  ```
  git checkout development
  git reset --hard prism/feature     # put it on that commit
  git branch -u prism/feature        # and follow it from now on
  ```
- Reset alone does not change tracking; I tested it.
- With `push.default=simple`, plain `git push` refuses when the local and remote branch names differ. Use `git push prism HEAD:main`.

## **Full ref names**

> Details: [full explanation]({{ site.posts | where: "slug", "git-part-2" | first.url | relative_url }}#refs)
{: .prompt-tip}

- You type `main`; Git means `refs/heads/main`. Remote ones are `refs/remotes/origin/main`; tags `refs/tags/v1`.
- A **refspec** is `source:destination`. Example: `git push origin HEAD:refs/heads/main`.
- Some servers give special refs meaning (a code-review server treats pushes to `refs/for/<branch>` as "open a review"). On a plain server it's just an ordinary ref.

## **Config and identity**

> Details: [full explanation]({{ site.posts | where: "slug", "git-part-2" | first.url | relative_url }}#config)
{: .prompt-tip}

- `.git/config` holds remotes, tracking, user settings. Everything above can be edited there.
- **Author** = who wrote the change. **Committer** = who last applied it (rebase, cherry-pick, amend change it; a plain merge doesn't).
- Per-repo identity: `git config user.name "you"` and `git config user.email "you@example.com"`.
- Different identity per folder: `includeIf` in global config (put it after `[user]`).
- `git config --global user.useConfigOnly true` makes Git refuse to guess an identity.

---

## **Command list (basic to intermediate)**

> Every group, with the idea behind it, is in the [Cheat Sheet and Refresher]({{ site.posts | where: "slug", "git-cheat-sheet" | first.url | relative_url }}).
{: .prompt-info}

### **Look around**
```
git status                          # state of files, ahead/behind
git log --oneline --graph --all     # the whole picture
git show <commit>                   # one commit
git diff / git diff --staged        # unstaged / staged changes
git branch -vv                      # branches, their SHA, what they track
git remote -v                       # remotes and URLs
git ls-remote origin                # what the remote has (needs network)
git rev-parse main                  # name → SHA
git reflog                          # where HEAD has been
```

### **Stage and commit**
```
git add <file>   |   git add -p          # whole file / piece by piece
git commit -m "msg"
git commit --amend                       # replace the last commit (new SHA)
git reset HEAD <file>                    # unstage   (new: git restore --staged <file>)
git checkout -- <file>                   # discard   (new: git restore <file>)
```

### **Branches and HEAD**
```
git checkout -b feature                  # create and switch   (new: git switch -c feature)
git checkout main                        # switch              (new: git switch main)
git checkout <sha>                       # detached HEAD
git branch feature <sha>                 # make a branch anywhere
git branch -d feature                    # delete (safe) / -D force
git branch -m old new                    # rename
```

### **Merge family**
```
git merge-base main feature              # where they diverged
git merge feature                        # FF or three-way
git merge --no-ff feature                # force a merge commit
git merge --squash feature               # content only, no arrow
git merge --abort                        # back out of a conflict
git cherry-pick <sha>                    # copy one commit (new SHA)
git rebase main                          # replay on top of main
git rebase -i HEAD~3                     # edit/squash last 3
git rebase --abort
git merge --allow-unrelated-histories other
```

### **Undo**
```
git reset --soft|--mixed|--hard <target>
git revert <sha>                         # new commit that undoes one (safe on shared branches)
git stash / git stash pop / git stash list
git restore --source=<sha> -- <file>     # old version of a file
git checkout <sha> -- <file>             # same, older form (stages it)
```

### **Remotes**
```
git remote add <name> <url>
git remote rename old new
git remote set-url <name> <new-url>
git remote remove <name>
git fetch <name>                         # update origin/* only
git fetch --all --prune                  # all remotes, drop deleted branches
git pull / git pull --rebase
git push <name> <branch>
git push -u <name> <branch>              # push and set tracking
git push <name> HEAD:<remote-branch>     # different names
git push --force-with-lease
git push <name> --delete <branch>
```

### **Tracking**
```
git branch -u <remote>/<branch>          # set upstream for current branch
git branch -vv                           # check it
git branch --unset-upstream
git checkout --track <remote>/<branch>   # new local branch that follows it
git config branch.<name>.remote          # the raw config
```

### **Config and identity**
```
git config --list --show-origin
git config user.name "you"
git config user.email "you@example.com"
git config --global pull.rebase true
git commit --author="Name <name@example.com>" -m "msg"
git log --format='%h %an | %cn %s'       # author | committer
```

### **Handy extras**
```
git tag v1.0   |   git tag -a v1.0 -m "msg"
git bisect start / good / bad            # find the commit that broke it
git worktree add ../other feature        # second checkout, same repo
git clean -fd                            # remove untracked (try -n first)
```
