# Repository.sh Modification Plan for Sandbox Compatibility

## Overview

Modify repository.sh functions to support sandbox environments by changing working directory handling approach. Instead of taking work directory as a parameter, functions will internally resolve the working directory using `get_work_dir_for_hype`.

## Current Issues

1. `exec_in_work_dir` and `exec_commands_in_work_dir` functions receive work directory as first argument `$1`
2. `change_to_working_directory` function exists but is ineffective in sandbox environments
3. main.sh cmd_xxx calls do not use working directory wrapper functions

## Solution Plan

### 1. Modify repository.sh Functions

#### A. Update `exec_in_work_dir` Function
```bash
# Current implementation (line 414-425)
exec_in_work_dir() {
    local work_dir="$1"
    shift
    
    if [[ ! -d "$work_dir" ]]; then
        error "Working directory does not exist: $work_dir"
        return 1
    fi
    
    debug "Executing command in working directory: $work_dir"
    (cd "$work_dir" && "$@")
}

# New implementation
exec_in_work_dir() {
    local hype_name="$1"
    shift
    local work_dir
    
    work_dir=$(get_work_dir_for_hype "$hype_name")
    
    if [[ ! -d "$work_dir" ]]; then
        error "Working directory does not exist: $work_dir"
        return 1
    fi
    
    debug "Executing command in working directory: $work_dir (for $hype_name)"
    (cd "$work_dir" && "$@")
}
```

#### B. Update `exec_commands_in_work_dir` Function
```bash
# Current implementation (line 428-439)
exec_commands_in_work_dir() {
    local work_dir="$1"
    local command_string="$2"
    
    if [[ ! -d "$work_dir" ]]; then
        error "Working directory does not exist: $work_dir"
        return 1
    fi
    
    debug "Executing commands in working directory: $work_dir"
    (cd "$work_dir" && bash -c "$command_string")
}

# New implementation
exec_commands_in_work_dir() {
    local hype_name="$1"
    local command_string="$2"
    local work_dir
    
    work_dir=$(get_work_dir_for_hype "$hype_name")
    
    if [[ ! -d "$work_dir" ]]; then
        error "Working directory does not exist: $work_dir"
        return 1
    fi
    
    debug "Executing commands in working directory: $work_dir (for $hype_name)"
    (cd "$work_dir" && bash -c "$command_string")
}
```

#### C. Remove `change_to_working_directory` Function
- Delete lines 471-477 (legacy function, no longer needed)

### 2. Update Function Calls within repository.sh

#### A. Fix `sync_repository` Function Call (line 211)
```bash
# Current call
exec_commands_in_work_dir "$clone_dir" "
    git fetch origin &&
    (git checkout \"$branch\" 2>/dev/null || git checkout -b \"$branch\" \"origin/$branch\") &&
    git pull origin \"$branch\" &&
    rsync -av --exclude='.git' ./ \"$branch_dir/\"
"

# New approach: Use a dedicated helper or modify to work with hype_name
# Since this is during sync operation, we need to work with clone_dir directly
# Keep this call as-is with work_dir parameter, or create a separate function
```

### 3. Modify main.sh Command Routing

#### A. Wrap cmd_xxx Calls with exec_in_work_dir

Update the following command cases in main.sh (lines 114-157):

```bash
# Before
"init")
    check_dependencies
    cmd_init "$hype_name"
    ;;

# After
"init")
    check_dependencies
    exec_in_work_dir "$hype_name" cmd_init "$hype_name"
    ;;
```

Apply this pattern to these commands:
- init (line 116)
- deinit (line 120)  
- check (line 124)
- template (line 128)
- parse (line 132)
- trait (line 136)
- task (line 140)
- helmfile (line 144)
- up (line 148)
- down (line 152)
- restart (line 156)

#### B. Repository Commands (No Change Needed)
These commands already handle their own working directory logic:
- use repo (line 161)
- unuse (line 168)

### 4. Impact Analysis

#### A. Files to Modify
1. `src/core/repository.sh` - Function signature changes
2. `src/main.sh` - Command routing updates

#### B. Functions Affected
- `exec_in_work_dir()` - Signature change
- `exec_commands_in_work_dir()` - Signature change  
- `change_to_working_directory()` - Remove completely

#### C. Potential Issues
- Need to check if any plugins directly call these functions
- Ensure sync_repository still works correctly
- Verify all cmd_xxx functions accept being called via exec_in_work_dir

### 5. Testing Plan

After implementation:
1. Run `task build` to verify build success
2. Run `task test` to ensure all tests pass
3. Test basic commands: init, template, parse
4. Verify working directory handling in sandbox environment

## Benefits

1. **Sandbox Compatibility**: Commands will execute in correct working directory
2. **Cleaner API**: Functions no longer need work_dir parameter
3. **Consistent Behavior**: All commands use same working directory resolution
4. **Reduced Complexity**: Eliminates need to pass work_dir around

## Implementation Order

1. Update `exec_in_work_dir` function
2. Update `exec_commands_in_work_dir` function  
3. Remove `change_to_working_directory` function
4. Update main.sh command routing
5. Handle sync_repository special case if needed
6. Test and verify functionality