# Fetch a remote branch and create a detached worktree for reviewing it.
function wtd -d "Create a detached Git worktree for a remote branch"
  argparse 'h/help' -- $argv
  or return 1

  if set -q _flag_help; or test (count $argv) -lt 1; or test (count $argv) -gt 2
    echo "Usage: wtd branch [directory]"
    return 1
  end

  set -l branch $argv[1]
  set -l directory $argv[2]
  if test -z "$directory"
    set directory (__wt.slug "$branch")
    or return 1
  end

  set -l worktree_dir (__wt.dir)
  or return 1
  set -l worktree "$worktree_dir/$directory"

  if test -e "$worktree"
    echo "wtd: $worktree already exists" >&2
    return 1
  end

  mkdir -p "$worktree_dir"
  or return 1

  command git fetch origin "$branch"
  and command git worktree add --detach "$worktree" FETCH_HEAD
end
