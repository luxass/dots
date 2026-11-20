if status is-interactive; and set -l starship_bin (command -s starship)
    set -l starship_cache "$__fish_cache_dir/starship_init.fish"
    # The generated script embeds the command path. The resolved Homebrew path
    # also includes the Cellar version, so upgrades invalidate the cache.
    set -l starship_cache_key "# starship-init: $starship_bin "(path resolve -- "$starship_bin")
    set -l starship_cached_key
    if test -r "$starship_cache"
        read starship_cached_key <"$starship_cache"
    end
    if test "$starship_cached_key" != "$starship_cache_key"
        if mkdir -p -- "$__fish_cache_dir"; and set -l starship_tmp (mktemp "$starship_cache.XXXXXX")
            # Publish only complete output, even when multiple shells start together.
            if begin
                printf '%s\n' "$starship_cache_key"
                command "$starship_bin" init fish --print-full-init
            end >"$starship_tmp"; and mv -f -- "$starship_tmp" "$starship_cache"
                set starship_cached_key "$starship_cache_key"
            else
                rm -f -- "$starship_tmp"
            end
        end
    end
    if test "$starship_cached_key" = "$starship_cache_key"
        source "$starship_cache"
    else
        command "$starship_bin" init fish | source
    end

    # Starship 1.27.0 forces external Git when core.fsmonitor=true:
    # https://github.com/starship/starship/blob/v1.27.0/src/context/git_repo.rs#L61-L74
    # That path runs git status instead of using the internal gitoxide engine:
    # https://github.com/starship/starship/blob/v1.27.0/src/modules/git_status.rs#L336-L356
    # Revisit after gitoxide adds monitor support and Starship adopts it:
    # https://github.com/GitoxideLabs/gitoxide/pull/3153
    function __starship_prompt_without_fsmonitor --description 'Render Starship with a local Git fsmonitor override'
        set -l git_config_index 0
        if set -q GIT_CONFIG_COUNT
            set git_config_index $GIT_CONFIG_COUNT
        end

        set -lx GIT_CONFIG_COUNT (math $git_config_index + 1)
        set -lx GIT_CONFIG_KEY_$git_config_index core.fsmonitor
        set -lx GIT_CONFIG_VALUE_$git_config_index false
        command $argv
    end

    # Keep Starship's exit-status capture, flags, and transient prompts intact.
    set -l starship_render_command (string escape -- "$starship_bin")' prompt'
    functions fish_prompt fish_right_prompt |
        string replace --all -- "$starship_render_command" "__starship_prompt_without_fsmonitor $starship_render_command" |
        source
end
