---
layout: post
title: "Git Cheat Sheet and Refresher"
date: 2026-11-09
description: "All of Git on one page, with a quick concept refresher above every group of commands: names and refs, undo, stash, merge, squash, rebase, cherry-pick, remotes, tracking, config, identity, force push, Gerrit, recipes, and what each error message really means."
categories: [Developer Tools, Git]
tags: [git, cheatsheet, troubleshooting]
---

> **Git series:** [Quick Summary]({{ site.posts | where: "slug", "git-in-one-page" | first.url | relative_url }}) · [1. Commits, Branches and Merging]({{ site.posts | where: "slug", "git-part-1" | first.url | relative_url }}) · [2. Remotes and Pointers]({{ site.posts | where: "slug", "git-part-2" | first.url | relative_url }}) · **Cheat Sheet**
{: .prompt-info}

Read this top to bottom and the whole thing comes back. Each group opens with a short **Refresh** that restores the idea behind the commands, and links to the full explanation if it doesn't.

<details>
<summary><strong>📑 Table of Contents</strong></summary>
<div markdown="1">

- [The Ideas](#ideas)
  - [What each command really does](#effects)
- [Names and Refs](#refs)
- [Looking Around](#looking)
- [Stage and Commit](#commit)
- [Branches and HEAD](#branches)
- [Undo](#undo)
- [The Safety Net: Reflog](#reflog)
- [Stash](#stash)
- [Merge](#merge)
- [Unrelated Histories](#unrelated)
- [Squash](#squash)
- [Rebase](#rebase)
- [Cherry-Pick](#cherry-pick)
- [Remotes](#remotes)
- [Fetch, Pull, Push](#fetch-pull-push)
- [Tracking (Upstream)](#upstream)
- [Config](#config)
- [Author, Committer, Identity](#identity)
- [Force Pushing](#force)
- [Gerrit](#gerrit)
- [Recipes](#recipes)
- [What the Error Actually Means](#errors)
- [Also Worth Knowing](#also)

</div>
</details>

---

## **The Ideas** {#ideas}

1. **Git is permanent snapshots plus pointers to them.** A commit can't change. It can only be replaced.
2. **A branch is a 41-byte file holding a hash.** You can point it at any commit you want.
3. **HEAD is where you are.** Normally it names a branch.
4. **`main` is really `refs/heads/main`.** Anywhere Git wants a commit, give it anything that leads to one.
5. **`origin` is a nickname for a URL.** One folder can have many, pointing at different repositories.
6. **`origin/main` is a file on your machine**: your record of the server's pointer. Only `fetch` updates it.
7. **Being at a commit and tracking a branch are separate facts.** `reset` does the first, `branch -u` does the second.
8. **History is the arrows between commits.** Same code doesn't mean related.
9. **Merge records that histories met. Squash and cherry-pick copy content and record nothing.**
10. **Anything committed can be recovered with the reflog.** Uncommitted edits can't.
11. **Force push just rewrites the server's pointer.** Use `--force-with-lease`, and after `stale info`, look before retrying.
12. **Unsure? `git branch backup/now` first.** It costs 41 bytes.

### **What each command really does** {#effects}

Does it add commits, which pointer moves, does it touch your files?

| Command | Adds commits | Moves | Touches files |
|---|---|---|---|
| `commit` | one | current branch | no |
| `commit --amend` | one replacement | current branch | no |
| `branch x` | no | creates `x` | no |
| `checkout x` (or `switch x`) | no | HEAD | yes |
| `merge`, fast-forward | no | current branch | yes |
| `merge`, three-way | one, two parents | current branch | yes |
| `merge --squash` + commit | one, one parent | current branch | yes |
| `rebase` | a copy of each commit | current branch | yes |
| `cherry-pick` | one copy each | current branch | yes |
| `revert` | one opposite commit | current branch | yes |
| `reset --soft` | no | current branch | no |
| `reset` (mixed) | no | current branch | index only |
| `reset --hard` | no | current branch | **yes** |
| `checkout -- file` (or `restore file`) | no | nothing | yes |
| `stash` | hidden commits | `refs/stash` | yes |
| `fetch` | downloads them | `refs/remotes/*` only | no |
| `pull` | fetch + merge or rebase | `refs/remotes/*`, current branch | yes |
| `push` | uploads them | the server's branch, your record of it | no |

---

## **Names and Refs** {#refs}

> **Refresh:** Every name is a pointer stored under `.git/refs`: `heads/` for your branches, `tags/` for tags, `remotes/` for your records of other repositories. `main` is short for `refs/heads/main`. [Full story]({{ site.posts | where: "slug", "git-part-2" | first.url | relative_url }}#refs)
{: .prompt-tip}

```bash
git rev-parse main                       # what commit does this name lead to?
git rev-parse --symbolic-full-name main  # its full name: refs/heads/main
git for-each-ref                         # every pointer in this repo
git show-ref                             # the same, shorter
git ls-remote origin                     # the server's pointers, right now
cat .git/HEAD                            # where am I?
cat .git/refs/heads/main                 # a branch, in full
```

| You can say | It leads to |
|---|---|
| `main` | `refs/heads/main` |
| `v1.0` | `refs/tags/v1.0` |
| `origin/main` | `refs/remotes/origin/main` |
| `20e29c9` | that commit |
| `HEAD~1`, `HEAD~2` | one or two arrows back |
| `HEAD^2` | a merge's second parent |
| `HEAD@{1}` | where HEAD was one move ago |
| `@{u}` | the upstream of this branch |
| `ORIG_HEAD` | where you were before the last reset, rebase or merge |

---

## **Looking Around** {#looking}

> **Refresh:** `A..B` means "reachable from B but not from A". `git diff` answers a *content* question. `git merge-base` answers an *ancestry* question. [Full story]({{ site.posts | where: "slug", "git-part-1" | first.url | relative_url }}#unrelated)
{: .prompt-tip}

```bash
git status                                  # where am I, what's changed
git status --short                          # 2 columns: staged | unstaged
git log --oneline --graph --decorate --all  # draw the whole graph
git log --first-parent --oneline            # just the main line of a branch
git log -5 --format='%h  A: %ae  |  C: %ce' # author and committer, one per line
git log -1 --format=fuller                  # both identities with dates
git show --no-patch --pretty=raw <commit>   # a commit's parents, raw

git diff                                    # unstaged changes
git diff --staged                           # what the next commit will contain
git diff --stat main..development           # the two tips compared directly
git diff main...development                 # only what development did since the split

git log --oneline main..development         # commits on development, not on main
git log --oneline main...development        # commits on one side, not both
git rev-list --left-right --count A...B     # how far apart: left, right
git merge-base A B                          # where did they split?
git merge-base --is-ancestor A B; echo $?   # 0 means A is in B's history
git branch --contains <commit>              # which branches have this commit
git branch --merged                         # which branches are fully inside this one

git log -S'text' --oneline                  # commits that added or removed this text
git log --grep='word' --oneline             # commits with this in the message
git log --oneline -- path/file              # history of one file
git show HEAD~1:path/file                   # a file as it was in that commit
git blame -L 10,20 file                     # who last changed these lines
```

---

## **Stage and Commit** {#commit}

> **Refresh:** Code lives in three places: working tree → index → the commit you're on. `git add` already stores the content, and the index is a full proposal for the next snapshot. [Full story]({{ site.posts | where: "slug", "git-part-1" | first.url | relative_url }}#reset)
{: .prompt-tip}

```bash
git add file                 # stage a file
git add -p                   # stage part of a file, hunk by hunk
git add -A                   # stage everything, including deletions
git commit -m "message"      # snapshot the index
git commit --amend           # replace the last commit (new hash!)
git commit --fixup <commit>  # a fix to squash into that commit later
git rm -r --cached .venv     # stop tracking, keep the files on disk
git clean -n -d              # preview deleting untracked files
git clean -fd                # actually delete them
```

> `.gitignore` only affects files that aren't tracked yet. Already committed? `git rm --cached` first. Old commits still contain it, so a leaked secret must be changed.
{: .prompt-warning}

---

## **Branches and HEAD** {#branches}

> **Refresh:** Creating a branch writes a small file. A commit is "on" a branch if you can walk back to it from that pointer. Detached HEAD means HEAD holds a hash instead of a branch name. [Full story]({{ site.posts | where: "slug", "git-part-1" | first.url | relative_url }}#branches)
{: .prompt-tip}

```bash
git branch                    # list local branches
git branch -a                 # local and remote-tracking
git branch -vv                # with what each tracks, and ahead/behind
git checkout x                # go to branch x                        (new: git switch x)
git checkout -                # back to the previous branch           (new: git switch -)
git checkout -b x             # create and go                         (new: git switch -c x)
git checkout -b x origin/x    # create from a remote branch, track it (new: git switch -c x origin/x)
git checkout --track origin/x # the same, keeping the name x          (new: git switch --track origin/x)
git checkout <commit>         # stand on an old commit                (new: git switch --detach <commit>)
git checkout -b rescue        # detached with work worth keeping?     (new: git switch -c rescue)
git checkout --orphan fresh   # a new branch with no history at all   (new: git switch --orphan fresh)
git branch -f x <commit>      # point branch x at any commit
git branch -m old new         # rename
git branch -d x               # delete, only if fully merged
git branch -D x               # delete anyway
```

> **Old or new?** `git checkout` is not deprecated, and `git switch` and `git restore` (added in Git 2.23) do the same jobs. They differ in only three places:
> - `git checkout origin/x` puts you on a detached HEAD. `git switch origin/x` refuses.
> - `git checkout --orphan x` leaves your files staged. `git switch --orphan x` starts empty.
> - `git checkout HEAD~2 -- file` also stages the file. `git restore --source=HEAD~2 file` only changes it on disk.
{: .prompt-info}

---

## **Undo** {#undo}

> **Refresh:** `reset` moves the pointer you're standing on, and spreads to the index (mixed) and files (hard). `checkout -- file` (or `restore`) only copies file contents. `revert` adds an opposite commit, so it's the safe one for shared history. [Full story]({{ site.posts | where: "slug", "git-part-1" | first.url | relative_url }}#reset)
{: .prompt-tip}

| Situation | Command |
|---|---|
| Throw away edits to a file | `git checkout -- file` or `git restore file` |
| Unstage a file, keep the edits | `git reset HEAD file` or `git restore --staged file` |
| Get a file from another commit | `git checkout HEAD~2 -- file` or `git restore --source=HEAD~2 file` |
| Fix the last commit | `git commit --amend` |
| Undo commits, keep them **staged** | `git reset --soft HEAD~N` |
| Undo commits, keep the code **unstaged** | `git reset HEAD~N` |
| Undo commits and the code | `git reset --hard HEAD~N` |
| Undo something already shared | `git revert <commit>` |
| Undo a shared merge commit | `git revert -m 1 <merge>` |
| Make my branch match the server | `git fetch` then `git reset --hard origin/main` |

```bash
git merge --abort          # back out of a merge
git rebase --abort         # back out of a rebase, restoring everything
git rebase --quit          # only forget the rebase: leaves detached HEAD and conflict markers
git cherry-pick --abort    # back out of a cherry-pick
git revert --abort         # back out of a revert
```

> `reset --hard` and `git clean` destroy **uncommitted** work for good. `git status` first.
{: .prompt-danger}

---

## **The Safety Net: Reflog** {#reflog}

> **Refresh:** Commits don't get deleted. Pointers just move away from them. The reflog is a private diary of everywhere HEAD has been, local to this clone, kept 90 days (30 for commits nothing reaches). [Full story]({{ site.posts | where: "slug", "git-part-1" | first.url | relative_url }}#reflog)
{: .prompt-tip}

```bash
git reflog                       # everywhere HEAD has been
git reflog show main             # everywhere main has been
git reset --hard 'HEAD@{1}'      # go back one move
git reset --hard <hash>          # go back to a commit from the reflog
git reset --hard ORIG_HEAD       # undo the last rebase, merge or reset
git branch recovered <hash>      # or put a new pointer on a lost commit
git fsck --lost-found            # last resort: finds staged content lost in a reset
```

---

## **Stash** {#stash}

> **Refresh:** A pocket for half-done work. Really hidden commits with their own pointer, `refs/stash`. Untracked files stay behind unless you add `-u`. If `pop` hits a conflict, the stash is kept.
{: .prompt-tip}

```bash
git stash                                 # save tracked changes, clean the tree
git stash push -m "WIP: description"      # the same, with a name (recommended)
git stash push -u -m "WIP: with new files"   # include untracked files
git stash push -a -m "WIP: everything"       # include ignored files too (careful)
git stash push -m "WIP: some" file1 file2    # only these files

git stash list                            # everything in the pocket
git stash show stash@{0}                  # summary
git stash show -p stash@{0}               # full diff
git stash show --include-untracked stash@{0}  # with the untracked files shown

git stash apply stash@{0}                 # restore, keep it in the list
git stash pop stash@{0}                   # restore and remove (the usual)
git stash branch new-branch stash@{0}     # make a branch from it
git stash drop stash@{0}                  # delete one
git stash clear                           # delete ALL (danger)
```

---

## **Merge** {#merge}

> **Refresh:** The **merge base** is the last commit both sides share. If your branch hasn't moved since then, the pointer just slides (**fast-forward**). If both moved, Git compares base, ours and theirs, and writes a commit with **two parents**: "these histories met". [Full story]({{ site.posts | where: "slug", "git-part-1" | first.url | relative_url }}#three-way)
{: .prompt-tip}

```bash
git merge-base main development   # where did they split? (empty = unrelated)
git merge feature                 # fast-forward if possible, else a merge commit
git merge --no-ff feature         # always a merge commit: keeps the branch visible
git merge --ff-only feature       # fast-forward or refuse
git merge --abort                 # back out

# Conflicts
git status                             # what's conflicted
git diff --name-only --diff-filter=U   # just the conflicted files
git show :1:file                       # the base version
git show :2:file                       # ours
git show :3:file                       # theirs
git add file                           # mark it resolved
git merge --continue                   # finish
```

| Command | On a conflict | Other changes from their side |
|---|---|---|
| `merge -X theirs x` | takes theirs | kept |
| `merge -X ours x` | takes ours | kept |
| `merge -s ours x` | takes ours | **discarded entirely** |
| `checkout --theirs .` (mid-merge) | takes theirs, for the conflicted files | already merged |

> These choose **content**. They don't change the ancestry: it's still a real merge with two parents.
{: .prompt-info}

---

## **Unrelated Histories** {#unrelated}

> **Refresh:** Two commits are related only if the arrows connect them. Identical files don't count. With no shared commit there's no merge base, so Git refuses unless you insist, and once a real merge joins them, future merges are normal. [Full story]({{ site.posts | where: "slug", "git-part-1" | first.url | relative_url }}#unrelated)
{: .prompt-tip}

```bash
git merge-base main development || echo "No common ancestor"
git merge --no-ff --allow-unrelated-histories development
git merge --no-ff --allow-unrelated-histories -X theirs development   # every differing file conflicts otherwise

# If files stay conflicted (rare, rename/rename)
git checkout --theirs .
git add -A
git commit -m "Merge development into main, prefer development on conflicts"
```

---

## **Squash** {#squash}

> **Refresh:** Squash copies the **result** and records **no arrow**. Fine for a short-lived branch you'll delete. On a long-lived branch every later merge starts from the old base. The real question is always: *which commits became parents of what landed on `main`?* [Full story]({{ site.posts | where: "slug", "git-part-1" | first.url | relative_url }}#squash)
{: .prompt-tip}

```bash
git merge --squash feature   # stage it all as one change
git commit -m "message"      # one commit, one parent
```

---

## **Rebase** {#rebase}

> **Refresh:** Arrows can't change, so rebase makes new commits on top of the latest. New hashes mean a pushed branch needs a force push. Only ever on branches nobody else uses. During a rebase, **`--ours` is the base and `--theirs` is your commit.** [Full story]({{ site.posts | where: "slug", "git-part-1" | first.url | relative_url }}#rebase)
{: .prompt-tip}

```bash
# The everyday flow
git checkout development && git pull
git checkout my_branch
git rebase development
git push --force-with-lease

# During a conflict
git status
git add file
git rebase --continue
git rebase --skip              # drop this commit, carry on
git rebase --abort             # back to how it was

# Tidying your own commits
git rebase -i HEAD~3           # pick / reword / squash / fixup / drop
git commit --fixup <commit>
git rebase -i --autosquash <commit>~1

# Moving a branch off another branch
git rebase --onto main mid top # take top's commits after mid, put them on main
```

| Word | In `rebase -i` |
|---|---|
| `pick` | keep |
| `reword` | keep, change message |
| `squash` | meld into the previous commit, combine messages |
| `fixup` | meld in, discard this message |
| `drop` | delete |

| | Rebase | Merge |
|---|---|---|
| History | linear | shows the real branching |
| Rewrites commits | **yes** | no |
| Needs a force push | **yes**, if already pushed | no |
| On shared branches | **no** | yes |

---

## **Cherry-Pick** {#cherry-pick}

> **Refresh:** Copy specific commits onto where you are: content without ancestry. New commits, the author stays, you become the committer, and the original is untouched. [Full story]({{ site.posts | where: "slug", "git-part-1" | first.url | relative_url }}#squash)
{: .prompt-tip}

```bash
git cherry-pick <commit>        # copy one here
git cherry-pick -x <commit>     # and note where it came from
git cherry-pick A..B            # after A, up to and including B (excludes A!)
git cherry-pick A^..B           # includes A
git cherry-pick -n <commit>     # apply without committing
git cherry-pick -m 1 <merge>    # copy a merge commit
git cherry-pick --continue      # after resolving a conflict
git cherry-pick --abort         # back out
```

---

## **Remotes** {#remotes}

> **Refresh:** A remote is a nickname for a URL, and is just another copy of the repository with its own pointers. `origin` is only the name `clone` picks by default. [Full story]({{ site.posts | where: "slug", "git-part-2" | first.url | relative_url }}#origin)
{: .prompt-tip}

```bash
git remote -v                          # list remotes and URLs
git remote add myremote <url>          # add one
git remote get-url origin              # show one URL
git remote set-url origin <new url>    # change it
git remote rename origin gerrit        # rename (tracking settings follow)
git remote remove gerrit               # delete it, with its gerrit/* records
git remote show origin                 # the full picture of one remote
```

---

## **Fetch, Pull, Push** {#fetch-pull-push}

> **Refresh:** `origin/main` is a file on your disk. `fetch` downloads commits and updates those records, and doesn't touch HEAD, your branches or your files. `pull` is fetch plus a merge or rebase. `push` uploads and asks the server to move its pointer. The full form is `src:dst`. [Full story]({{ site.posts | where: "slug", "git-part-2" | first.url | relative_url }}#fetch)
{: .prompt-tip}

```bash
git fetch origin                   # update my records from one remote
git fetch --all                    # from every remote
git fetch -p                       # also delete records of removed branches
git fetch --all --prune --tags     # the lot

git pull                           # fetch + integrate the upstream
git pull --ff-only                 # only if I'm simply behind
git pull --rebase                  # replay my commits on top
git pull --no-rebase               # make a merge commit

git push                           # the current branch to its upstream
git push origin main               # say exactly where
git push origin main:release       # my main → their release
git push origin HEAD:refs/heads/x  # where I'm standing → branch x
git push origin --delete x         # delete a server branch
git push origin :x                 # the same, the old spelling
git push origin v1.0               # one tag
git push origin --tags             # all tags

git reset --hard myremote/branch   # drag my current branch to any remote's branch
```

> `reset --hard origin/x` reads a local file and never touches the network, so `fetch` first. It moves your pointer. It does **not** change what the branch tracks. For that: `git branch -u origin/x`.
{: .prompt-warning}

---

## **Tracking (Upstream)** {#upstream}

> **Refresh:** Tracking is two lines in `.git/config` answering "where does a plain `push` or `pull` go?" `merge = refs/heads/x` means **follows x**, not "was merged from x". What a branch tracks and what it was created from are unrelated. [Full story]({{ site.posts | where: "slug", "git-part-2" | first.url | relative_url }}#tracking)
{: .prompt-tip}

```bash
git branch -vv                                  # what does everything track?
git status                                      # just this branch
git branch -u origin/feature-xyz                # set it
git branch --set-upstream-to=origin/feature-xyz # the same, spelled out
git push -u origin feature-xyz                  # first push: push and set
git checkout -b gerrit-work gerrit/master       # create, and track automatically
git branch --unset-upstream                     # remove it

git log --oneline @{u}..                        # what would I push?
git log --oneline ..@{u}                        # what would I pull?
```

**Two repositories in one folder** ([full story]({{ site.posts | where: "slug", "git-part-2" | first.url | relative_url }}#multiple-remotes)):

```bash
git remote add aiprism git@github.com:you/prism-ai.git
git fetch aiprism
git checkout -b prism-ai/main aiprism/main
git branch -vv
```

| Problem | Fix |
|---|---|
| `git push` refuses: *upstream does not match the name* | `git push aiprism HEAD:main`, or `git config push.default upstream` |
| `git checkout dev` fails: *matched multiple remote tracking branches* | `git checkout -b dev --track origin/dev`, or `git config checkout.defaultRemote origin` |
| The other repo's tags keep arriving | `git config remote.aiprism.tagOpt --no-tags` |
| A plain push should only ever send one branch | `git config remote.aiprism.push refs/heads/local:refs/heads/remote` |

---

## **Config** {#config}

> **Refresh:** System, then global (`~/.gitconfig`), then local (`.git/config`), and later wins. `.git/config` is plain text: `[remote]` blocks are nicknames, `[branch]` blocks are tracking. `fetch = +refs/heads/*:refs/remotes/origin/*` is `src:dst`, and the `+` allows a record to jump backwards after a force push.
{: .prompt-tip}

```bash
git config --show-origin --show-scope user.email   # what's set, and where
git config --list --show-scope                     # everything
git config --get remote.origin.url                 # read one value
git config --global pull.ff only                   # no surprise merges on pull
git config --global fetch.prune true               # always prune
git config --global push.autoSetupRemote true      # first push sets the upstream
git config --global credential.helper 'cache --timeout=2592000'  # 30 days, HTTPS only
```

---

## **Author, Committer, Identity** {#identity}

> **Refresh:** The author wrote the change, the committer made this commit object. A plain merge leaves the originals untouched. Rebase, cherry-pick and amend keep the author and change the committer. [Full story]({{ site.posts | where: "slug", "git-part-2" | first.url | relative_url }}#identity)
{: .prompt-tip}

```bash
git config --global user.email "you@personal.example"  # default for all repos
git config user.email "first.last@company.example"     # this repo only
git -c user.name="Name" -c user.email="me@example.com" commit -m "msg"  # one commit
git commit --author="Ravi <ravi@example.com>" -m "msg" # set author; you stay committer
git commit --amend --no-edit --reset-author            # fix the last commit's identity
git rebase HEAD~3 --exec 'git commit --amend --no-edit --reset-author'  # fix the last three
git rebase --root --exec 'git commit --amend --no-edit --reset-author'  # fix them all
git var GIT_AUTHOR_IDENT                               # who am I right now?
git var GIT_COMMITTER_IDENT

# A different identity on one branch
printf '[user]\n\tname = Your Name\n\temail = you@personal.example\n' > ~/.gitconfig-personal
git config --local 'includeIf.onbranch:development.path' '~/.gitconfig-personal'
git config --global user.useConfigOnly true            # never guess an identity

# Check before pushing
git log -5 --format='%h  A: %ae  |  C: %ce'
git log development --format='%ae%n%ce' | grep -v 'you@personal.example'   # empty = clean
git log @{u}.. --format='%h  A: %ae  |  C: %ce'                            # only what I'd push
git log @{u}.. --format='%B' | grep -iE 'change-id|company-name' || echo clean
```

> The `includeIf` must come **after** the `[user]` block in `.git/config`, because later lines win. `git config` appends, so it lands there on its own.
{: .prompt-warning}

---

## **Force Pushing** {#force}

> **Refresh:** Force just rewrites the server's pointer. `--force-with-lease` means "only if the server still matches my record". After `git fetch` your record is fresh, so the lease no longer protects you. [Full story]({{ site.posts | where: "slug", "git-part-2" | first.url | relative_url }}#force)
{: .prompt-tip}

```bash
git push --force-with-lease                       # the normal safe force
git push --force-with-lease --force-if-includes   # refuses if you fetched but didn't integrate
git push --force                                  # avoid

# After "stale info": look, then integrate, then push
git fetch
git log --oneline HEAD..@{u}
git rebase @{u}
git push --force-with-lease
```

---

## **Gerrit** {#gerrit}

> **Refresh:** You push to `refs/for/<branch>`, which isn't a branch, and the server opens a review. Each commit is one change. The `Change-Id:` line (added by a `commit-msg` hook) ties new versions to the same review. [Full story]({{ site.posts | where: "slug", "git-part-2" | first.url | relative_url }}#refs)
{: .prompt-tip}

```bash
git push gerrit HEAD:refs/for/master      # send for review
git push origin HEAD:refs/for/devicehub3  # another target (the remote's name is up to you)
git push gerrit gerrit-work:master        # direct push, no review

# The daily loop
git checkout gerrit-work
git merge --squash --allow-unrelated-histories -X theirs development
git commit -m "Describe what changed"
git push gerrit gerrit-work:refs/for/master
# ...after it's submitted:
git fetch gerrit
git reset --hard gerrit/master
```

To make the branch an **exact** copy instead (`git checkout development -- .` does *not* remove extra files):

```bash
git checkout --no-overlay development -- .                   # or the newer form:
git restore --source=development --staged --worktree -- .
git commit -m "Sync everything from development"
```

---

## **Recipes** {#recipes}

**Make a branch exactly match the server:**

```bash
git fetch origin
git reset --hard origin/main
```

**Make `main` exactly match `development`, with a way back:**

```bash
git checkout main
git tag backup-main-init && git branch backup/main-init
git push origin backup/main-init --tags
git reset --hard development
git push --force-with-lease origin main
git diff --stat main origin/development      # no output = identical

# Rollback
git fetch --all --tags
git checkout main && git reset --hard backup-main-init   # or backup/main-init
git push --force-with-lease origin main
```

**Merge `development` into `main`, carefully:**

```bash
git fetch --all --prune
git merge-base main development              # empty means unrelated histories
git diff --stat main..development
git log --oneline main..development

git checkout main
git pull
git merge --no-ff development
# fix any conflicts, git add ., git commit
# run your tests
git push origin main
```

**Stop tracking something committed by accident:**

```bash
echo ".venv/" >> .gitignore
git rm -r --cached .venv
git add .gitignore && git commit -m "Stop tracking .venv"
```

---

## **What the Error Actually Means** {#errors}

| Message | Meaning | Do this |
|---|---|---|
| `rejected (fetch first)` | the server has commits you've never downloaded | `git fetch`, look, then integrate |
| `rejected (non-fast-forward)` | someone else pushed, or you rewrote your commits | integrate; or, if you rebased your own branch, `--force-with-lease` |
| `rejected (stale info)` | the server moved since your last fetch | `git fetch`, **read what changed**, integrate |
| `refusing to merge unrelated histories` | the two sides share no commit | check it's the right branch; `--allow-unrelated-histories` |
| `You have divergent branches` | pull doesn't know how to combine them | `--rebase`, `--no-rebase` or `--ff-only` |
| `The current branch has no upstream` | nothing set for a plain push | `git push -u origin <branch>` |
| `upstream branch… does not match the name` | local and remote names differ | `git push <remote> HEAD:<name>` |
| `matched multiple remote tracking branches` | two remotes both have that branch | `--track <remote>/<branch>` |
| `a branch is expected, got remote branch` | `git switch` onto your record of a remote (`git checkout` would detach instead) | `git checkout -b x origin/x` |
| `HEAD detached at …` | HEAD holds a hash, not a branch | `git checkout <branch>`, or `git checkout -b new` to keep work |
| `the branch is not fully merged` | it has commits nothing else reaches (a squash causes this) | check, then `git branch -D` |
| `is a merge but no -m option was given` | cherry-pick or revert of a merge | add `-m 1` |
| `Author identity unknown` | no name or email set (or `useConfigOnly` is on) | set `user.name` and `user.email` |
| `refname 'x' is ambiguous` | a branch and a tag share that name | use the full `refs/heads/x` |

---

## **Also Worth Knowing** {#also}

```bash
git tag v1.0                          # a lightweight tag: a pointer that doesn't move
git tag -a v1.0 -m "first release"    # an annotated tag: its own object, with a message
git tag -d v1.0                       # delete locally

git bisect start <bad> <good>         # binary-search for the commit that broke things
git bisect good                       # or: git bisect bad, as you test each step
git bisect run ./test.sh              # let a script decide
git bisect reset                      # finish

git worktree add ../hotfix -b hotfix  # a second working folder on another branch, same .git
git worktree list
git worktree remove ../hotfix
```
