# Scripts Directory

## Files

- **`wait_for_guardium_ready.sh`** - POSIX-compliant script for Guardium readiness polling

## Usage

This script is shared across all Guardium modules (central-manager, aggregator, collector) and is referenced using relative paths:

```hcl
# In modules/collector/main.tf, modules/central-manager/main.tf, modules/aggregator/main.tf
provisioner "local-exec" {
  command = "${path.module}/../../scripts/wait_for_guardium_ready.sh"
}
```

## POSIX Compliance

The script **must remain POSIX-compliant** to work across all Linux distributions.

**Requirements:**
- Use `#!/bin/sh` shebang
- No Bash-specific syntax: `[[`, `&>`, `echo -e`, `local`, arrays
- Test in Alpine Linux before committing

**Prohibited:**
```bash
# ❌ Don't use
[[ $var == "value" ]]    # Use: [ "$var" = "value" ]
echo -e "text\n"         # Use: printf "text\n"
local var="value"        # Use: _function_var="value"
cmd &> /dev/null         # Use: cmd >/dev/null 2>&1
```

## DRY Principle

This directory maintains a single source of truth for the readiness script. All modules reference this shared script to avoid duplication.