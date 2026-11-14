if status is-interactive; and command -q starship
    starship init fish | source

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
    set -l starship_render_command (string escape -- (command -s starship))' prompt'
    functions fish_prompt fish_right_prompt |
        string replace --all -- "$starship_render_command" "__starship_prompt_without_fsmonitor $starship_render_command" |
        source
end
