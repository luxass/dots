# Convert a branch/ref name into a safe single path component.
function __wt.slug -d "Slugify a worktree directory name" -a name
  if test -z "$name"
    return 1
  end

  set -l slug (string replace -a / - -- "$name")
  set slug (string replace -a ' ' - -- "$slug")
  set slug (string replace -ra -- '[^A-Za-z0-9._-]' - "$slug")
  set slug (string replace -ra -- '-+' - "$slug")
  set slug (string trim -c - -- "$slug")

  if test -z "$slug"
    return 1
  end

  echo "$slug"
end
