# Repository Preparation Test

This test validates the complete repository preparation workflow using the new `prepare` subcommand.

## Test Commands

### 1. Repository Preparation
Execute the repository preparation with the specified parameters:

```bash
hype my-nginx prepare foontype/hype --path prompts/nginx-example
```

### 2. Validation Commands
After preparation, verify the configuration by running these commands:

```bash
# Check repository configuration
hype my-nginx repo

# Check trait configuration  
hype my-nginx trait

# Check available resources
hype my-nginx resources
```

### 3. Cleanup
Clean up the test environment:

```bash
hype my-nginx down
```

## Expected Results

- The `prepare` command should complete all setup steps successfully
- Repository should be properly configured and accessible
- Trait configuration should be applied correctly
- Resources should be available and properly configured
- Cleanup should remove all deployed resources

## Notes

- This test uses the `prompts/nginx-example` path which should contain the necessary configuration files
- The test validates the complete end-to-end workflow from repository setup to deployment cleanup
- All commands should execute without errors and provide appropriate feedback