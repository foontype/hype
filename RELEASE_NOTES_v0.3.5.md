# HYPE v0.3.5 Release Notes

## 🚀 New Features

### Template State-Value Subcommand
- **New subcommand**: `hype <name> template state-value <configmap-name>`
- Allows users to inspect the actual YAML content that would be passed to helmfile as state-value-file from a StateValueConfigmap
- Validates that the specified ConfigMap exists and is of StateValueConfigmap type
- Extracts and displays YAML content from the `data.values` key
- Provides helpful error messages for debugging state-value configurations

## 🔧 Improvements

### Enhanced Debugging Capabilities
- Users can now view and verify state-value content before helmfile execution
- Better visibility into the YAML structure being passed to helmfile
- Improved troubleshooting for state-value related issues

### Backward Compatibility
- The original `template` command remains unchanged
- All existing functionality is preserved

## 📝 Usage Examples

```bash
# View state-value content from a ConfigMap
hype myapp template state-value my-state-configmap

# The original template command still works as before
hype myapp helmfile template
```

## 🐛 Bug Fixes

- Improved error handling for missing or invalid ConfigMaps
- Enhanced validation for StateValueConfigmap type checking

## 📊 Changes Summary

- **Files changed**: 1
- **Lines added**: +140
- **Lines removed**: -19
- **Net change**: +121 lines

---

**Full Changelog**: [v0.3.4...v0.3.5](https://github.com/foontype/hype/compare/v0.3.4...v0.3.5)

This release focuses on improving the debugging experience for users working with state-value configurations, making it easier to troubleshoot and verify ConfigMap content before deployment.