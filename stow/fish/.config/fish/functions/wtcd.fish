# Change into a worktree directory under WT_DIR or the inferred repo worktree root.
function wtcd -d "Change into a Git worktree directory" -a directory
  if test -z "$directory"
    echo "Usage: wtcd directory"
    return 1
  end

  set -l worktree_dir (__wt.dir)
  or return 1

  if string match -q '/*' -- "$directory"
    cd "$directory"
  else
    cd "$worktree_dir/$directory"
  end
end
