#!/usr/bin/env bats

setup() {
    # Make sure the script is executable
    chmod +x src/hype
}

@test "src/hype has proper shebang" {
    run head -1 src/hype
    [ "$status" -eq 0 ]
    [[ "$output" == "#!/bin/bash" ]]
}

@test "src/hype is executable" {
    [ -x src/hype ]
}

@test "shellcheck passes for src/hype" {
    run shellcheck src/hype
    [ "$status" -eq 0 ]
}

@test "shellcheck passes for install.sh" {
    run shellcheck install.sh
    [ "$status" -eq 0 ]
}

@test "shellcheck passes for .devcontainer/post-create-command.sh" {
    run shellcheck .devcontainer/post-create-command.sh
    [ "$status" -eq 0 ]
}