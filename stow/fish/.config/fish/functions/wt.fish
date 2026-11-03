# Create a worktree and matching branch from the default branch, or an optional base ref.
function wt -d "Create a Git worktree and matching branch"
  argparse 'h/help' -- $argv
  or return 1

  if set -q _flag_help; or test (count $argv) -lt 1; or test (count $argv) -gt 2
    echo "Usage: wt branch [base]"
    return 1
  end

  set -l branch $argv[1]
  set -l base $argv[2]
  if test -z "$base"
    set base (__wt.default_branch)
    or return 1
  end

  set -l worktree_dir (__wt.dir)
  or return 1

  set -l directory (__wt.slug "$branch")
  or return 1
  set -l worktree "$worktree_dir/$directory"

  if test -e "$worktree"
    echo "wt: $worktree already exists" >&2
    return 1
  end

  mkdir -p "$worktree_dir"
  or return 1

  if command git show-ref --verify --quiet "refs/heads/$branch"
    command git worktree add "$worktree" "$branch"
  else
    command git worktree add -b "$branch" "$worktree" "$base"
  end
end
