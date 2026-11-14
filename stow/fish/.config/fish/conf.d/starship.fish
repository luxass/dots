if status is-interactive; and command -q starship
    starship init fish | source

    # Avoid fsmonitor forcing Starship's external Git fallback.
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
