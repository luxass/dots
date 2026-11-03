# Keep the Rex CLI available outside Rex. Do not install or start its server.
set -l rex_cli_dir "$HOME/Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app/Contents/MacOS"
if test -x "$rex_cli_dir/rex"
    fish_add_path --global --path "$rex_cli_dir"
end
