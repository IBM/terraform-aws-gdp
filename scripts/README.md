# Scripts Directory

## Files

- **`wait_for_guardium_ready.sh`** - Source of truth for the Guardium readiness polling script
- **`sync-to-modules.sh`** - Synchronizes the script to all module directories

## Script Distribution

Each module contains its own copy of `wait_for_guardium_ready.sh` to ensure self-contained modules that work when sourced from the Terraform Registry. When users reference a module like `source = "IBM/gdp/aws//modules/central-manager"`, Terraform only downloads that specific module directory—not the entire repository. By including the script in each module, they remain fully independent and functional.

**Source (edit here):**
- `scripts/wait_for_guardium_ready.sh`

**Distributed to:**
- `modules/collector/scripts/wait_for_guardium_ready.sh`
- `modules/central-manager/scripts/wait_for_guardium_ready.sh`
- `modules/aggregator/scripts/wait_for_guardium_ready.sh`

## Synchronizing Changes

After editing `wait_for_guardium_ready.sh`, run the sync script to copy it to all modules:

```bash
./sync-to-modules.sh
```

The script verifies all copies match via MD5 checksum.

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