# Remove a worktree, and optionally delete its checked-out local branch.
function wtr -d "Remove a Git worktree and optionally its branch"
  argparse 'h/help' 'k/keep' -- $argv
  or return 1

  if set -q _flag_help; or test (count $argv) -ne 1
    echo "Usage: wtr [-k|--keep] directory"
    return 1
  end

  set -l worktree_dir (__wt.dir)
  or return 1

  set -l directory $argv[1]
  set -l worktree
  if string match -q '/*' -- "$directory"
    set worktree (path normalize "$directory")
  else
    set worktree (path normalize "$worktree_dir/$directory")
  end

  if not test -d "$worktree"
    echo "wtr: $worktree does not exist" >&2
    return 1
  end

  set -l branch (command git -C "$worktree" symbolic-ref --quiet --short HEAD 2>/dev/null)

  command git worktree remove "$worktree"
  or return 1

  if not set -q _flag_keep; and test -n "$branch"
    command git branch -d "$branch"
  end
end
