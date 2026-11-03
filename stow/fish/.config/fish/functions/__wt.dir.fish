# Return the configured worktree directory or infer one from the repository layout.
function __wt.dir -d "Resolve the worktree directory"
  if set -q WT_DIR; and test -n "$WT_DIR"
    path normalize "$WT_DIR"
    return 0
  end

  set -l common_dir (command git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
  or begin
    echo "wt: not inside a Git repository and WT_DIR is not set" >&2
    return 1
  end

  # Bare-root layouts commonly keep .bare and all worktrees in the same directory.
  if test (path basename "$common_dir") = .bare
    path dirname "$common_dir"
    return 0
  end

  # Linked worktrees report the primary checkout's .git directory here, so this
  # keeps every worktree for a repo under the same sibling directory.
  if test (path basename "$common_dir") = .git
    set -l primary_checkout (path dirname "$common_dir")
    set -l repo_parent (path dirname "$primary_checkout")
    set -l repo_name (path basename "$primary_checkout")
    path normalize "$repo_parent/$repo_name.worktrees"
    return 0
  end

  set -l top_level (command git rev-parse --show-toplevel 2>/dev/null)
  or return 1
  set -l repo_parent (path dirname "$top_level")
  set -l repo_name (path basename "$top_level")
  path normalize "$repo_parent/$repo_name.worktrees"
end
