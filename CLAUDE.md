# Claude Code Instructions - DGX Spark FellowOS Image

## At Session Start
Read `~/Claude/sysadmin/claude-notes.md` before doing any work. Follow those rules.

## Key Rules (from ~/CLAUDE.md)

1. **EXPLICIT CONSENT before new work** - When starting any new project, deployment, installation, or significant change, OR when making a recommendation, explain what you plan to do and WAIT for explicit written agreement before executing. Do not assume approval. Once approved, execute fully — do NOT ask for permission at each step. Approval is a green light to complete the work. When hitting a blocker during execution: (1) Stop and explain the blocker. (2) Present options and wait for the user's decision. (3) Execute only the approach the user chooses. Never route around problems autonomously.
2. **Never give multi-line commands to paste** - Always write to a script file first
3. **Long single-line commands break too** - Write to script, chmod +x, then run
4. **Save working scripts** to ~/Claude/sysadmin/scripts/
5. **When user says "wait"** - Stop immediately, do not proceed
6. **Confirm approach** before non-trivial changes
7. **ASK USER for credentials when needed** - DO NOT CHANGE COURSE without ASKING PERMISSION

## Command Output
Normal command output is fine — visibility into results is worth the tokens.

**Only redirect/suppress output for high-volume commands:**
- Backup progress (kopia snapshot, rsync with per-file output)
- Bulk file operations (find/xargs on large trees)
- Any command producing continuous streaming progress

## Daily Work Log
Maintain a record of work completed at: `~/Claude/sysadmin/work-log.md`
- Add entries at session end summarizing what was accomplished
- Include: date, tasks completed, scripts saved, issues discovered
- Group by machine/context (e.g., DGX Spark, TrueNAS, Mac)

---

## Lessons Learned (from claude-notes.md)

### NEVER use sed to edit config files (YAML, JSON, etc.)
- sed corrupts structured config files
- **ALWAYS use Python with proper parsing libraries:**
  - YAML: `import yaml` → `yaml.safe_load()` / `yaml.dump()`
  - JSON: `import json` → `json.load()` / `json.dump()`

### Script-first approach
```bash
# WRONG - giving user a command to paste:
/some/long/command --flag1=value --flag2=value --flag3=value

# RIGHT - write to script, make executable, then run:
Write to /tmp/task.sh
chmod +x /tmp/task.sh
User runs: /tmp/task.sh
```

### ZFS mount shadowing
- **NEVER create a child ZFS dataset at a path that already has data on the parent**
- The child mount hides (shadows) the parent's data at that path
- Data is NOT deleted, just invisible until child is unmounted/destroyed

---

## Project Context

This is the **base layer** for FellowOS on NVIDIA DGX Spark hardware. It handles:
- Disk partitioning and ZFS layout
- DGX OS 7.4.0 installation
- CUDA environment configuration
- System-level services (OOM protection, etc.)

FellowOS itself (the AI operating system with web GUI, model management, templates) sits on top of this layer.

## Target Hardware

- **NVIDIA DGX Spark** - ARM64 (aarch64), Grace CPU + Blackwell GB10 GPU
- **GPU Architecture:** SM 12.1 (Blackwell)
- **Memory:** 128GB unified CPU/GPU
- **Storage:** 2TB or 4TB NVMe SSD
- **CUDA:** 13.0, Driver 580.x

## Script Conventions

### Bash Scripts
- Use `set -e` for fail-fast
- Include colored output functions: `log_info`, `log_warn`, `log_error`
- Provide `usage()` function and help command
- Support both interactive and non-interactive modes
- Check for root when needed: `if [[ $EUID -ne 0 ]]; then`

### Service Scripts (based on service-template.sh)
- Standard commands: `serve`, `stop`, `status`, `logs`, `restart`
- PID file in `/var/run/fellowos/`
- Logs in `/var/log/fellowos/`
- Service files in `/opt/fellowos/services/`

### Path Conventions
- AI models: `/ai/models/`
- Training data: `/ai/data/`
- Cache: `/ai/cache/`
- FellowOS services: `/opt/fellowos/`

## Testing Notes

**Cannot test locally** - these scripts require:
- Actual DGX Spark hardware (ARM64 + Blackwell GPU)
- Real NVMe disk for partition scripts
- DGX OS environment for CUDA detection

**Validation approach:**
- Syntax check: `bash -n script.sh`
- ShellCheck: `shellcheck script.sh`
- Dry-run flags where possible
- Test on actual hardware before release

## Key References

### NVIDIA Documentation
- [DGX OS 7 User Guide](https://docs.nvidia.com/dgx/dgx-os-7-user-guide/)
- [DGX Spark User Guide](https://docs.nvidia.com/dgx/dgx-spark/)
- [DGX Spark Release Notes](https://docs.nvidia.com/dgx/dgx-spark/release-notes.html)

### Community Resources
- [NVIDIA/dgx-spark-playbooks](https://github.com/NVIDIA/dgx-spark-playbooks) - Official playbooks
- [natolambert/dgx-spark-setup](https://github.com/natolambert/dgx-spark-setup) - OOM protection patterns
- [eelbaz/dgx-spark-vllm-setup](https://github.com/eelbaz/dgx-spark-vllm-setup) - Service script patterns

### Related Projects
- [FellowOS](https://github.com/walkyri/FellowOS) - AI operating system (sits on this base layer)

## ZFS Layout

Single pool with datasets:
```
rpool
├── ROOT/dgxos     (/, 500GB quota)
├── ai/models      (/ai/models)
├── ai/data        (/ai/data)
└── home           (/home)
```

Key properties: `compression=lz4`, `atime=off`, `recordsize=1M` for model files.

## SSH Access (from context.md)
- `ssh alfred` — DGX Spark, User: dgxuser, key auth

## Common Tasks

### Adding a New Service Script
1. Copy `scripts/service-template.sh` to `scripts/<service>.sh`
2. Edit CONFIGURATION section (name, port, paths)
3. Implement `start_service()` function
4. Test: `./scripts/<service>.sh status`

### Updating for New DGX OS Version
1. Check [release notes](https://docs.nvidia.com/dgx/dgx-os-7-user-guide/release_notes.html)
2. Update versions in `README.md` and `docs/dgx-stack-install.md`
3. Verify CUDA paths in `cuda-env-setup.sh` still work
4. Test on hardware

## Do Not

- Don't assume x86 paths - this is ARM64 (aarch64)
- Don't use `sudo` in scripts without checking `$EUID` first
- Don't hardcode CUDA versions - use detection where possible
- Don't test partition scripts on real disks without explicit user confirmation
- Don't use sed to edit structured config files (YAML, JSON) - use Python
- Don't give multi-line commands to paste - write scripts instead
