# Resolve the best base ref for a new Git worktree branch.
function __wt.default_branch -d "Resolve the repository default branch or remote ref"
  command git rev-parse --git-dir >/dev/null 2>&1
  or return 1

  set -l origin_head (command git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)
  if test -n "$origin_head"
    set -l local_branch (string replace -r '^origin/' '' -- "$origin_head")
    if command git show-ref --verify --quiet "refs/heads/$local_branch"
      echo "$local_branch"
    else
      echo "$origin_head"
    end
    return 0
  end

  for branch in main master
    if command git show-ref --verify --quiet "refs/heads/$branch"
      echo "$branch"
      return 0
    end
    if command git show-ref --verify --quiet "refs/remotes/origin/$branch"
      echo "origin/$branch"
      return 0
    end
  end

  set -l current_branch (command git symbolic-ref --quiet --short HEAD 2>/dev/null)
  if test -n "$current_branch"
    echo "$current_branch"
    return 0
  end

  echo main
end
