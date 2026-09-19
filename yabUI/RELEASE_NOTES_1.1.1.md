# yabUI 1.1.1

This release restores the configuration and keyboard shortcut workflow:

- adds the recovered Yabai configuration controls to Settings
- persists managed settings to `~/.config/yabai/yabairc` while preserving user content
- launches the bundled runtime with the managed configuration file
- uses the bundled runtime directly so a separate system installation is not required
- restores the documented skhd focus, movement, layout, and space shortcuts
- preserves existing skhd bindings and reloads skhd after installing the managed block
- adds live refresh and save controls for configuration changes
