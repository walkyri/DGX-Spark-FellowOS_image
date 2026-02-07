# Claude Code Instructions - DGX Spark FellowOS Image

## Key Rules

1. **EXPLICIT CONSENT before new work** - When starting any new project, deployment, installation, or significant change, explain what you plan to do and WAIT for explicit written agreement before executing. Once approved, execute fully — do NOT ask for permission at each step. When hitting a blocker: (1) Stop and explain. (2) Present options. (3) Wait for user's decision.
2. **Never give multi-line commands to paste** - Always write to a script file first
3. **Long single-line commands break too** - Write to script, chmod +x, then run
4. **Save working scripts** to ~/Claude/sysadmin/scripts/
5. **When user says "wait"** - Stop immediately, do not proceed
6. **Confirm approach** before non-trivial changes
7. **ASK USER for credentials when needed** - DO NOT CHANGE COURSE without ASKING PERMISSION

## Command Output

Normal command output is fine. Only redirect/suppress for high-volume commands (backup progress, bulk file ops).

## Daily Work Log

Update `~/Claude/sysadmin/work-log.md` at session end.

---

# Lessons Learned

## NEVER use sed to edit config files (YAML, JSON, etc.)
- sed corrupts structured config files
- **ALWAYS use Python:** `yaml.safe_load()` / `yaml.dump()` or `json.load()` / `json.dump()`

## ZFS Mount Shadowing
- **NEVER create a child ZFS dataset at a path that already has data on the parent**
- Child mount hides (shadows) parent's data at that path
- Data is NOT deleted, just invisible until child is unmounted/destroyed

## Script-first approach
```bash
# WRONG - giving user a command to paste
/some/long/command --flag1=value --flag2=value

# RIGHT - write to script, make executable, then run
Write to /tmp/task.sh
chmod +x /tmp/task.sh
User runs: /tmp/task.sh
```

---

# Project Context

## Purpose

Base layer for FellowOS on NVIDIA DGX Spark. Handles:
- Disk partitioning and ZFS layout
- DGX OS 7.4.0 installation
- CUDA environment configuration
- System-level services (OOM protection, etc.)

FellowOS (AI operating system with web GUI, model management) sits on top of this layer.

## Target Hardware

| Spec | Value |
|------|-------|
| System | NVIDIA DGX Spark |
| CPU | Grace (ARM64/aarch64) |
| GPU | Blackwell GB10 (SM 12.1) |
| Memory | 128GB unified CPU/GPU |
| Storage | 2TB or 4TB NVMe SSD |
| OS | DGX OS 7.4.0 (Ubuntu 24.04) |
| CUDA | 13.0 Update 2 |
| Driver | 580.126.09 |

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

---

# Script Conventions

## Bash Scripts
- Use `set -e` for fail-fast
- Include: `log_info`, `log_warn`, `log_error` functions
- Provide `usage()` function and help command
- Check for root: `if [[ $EUID -ne 0 ]]; then`

## Service Scripts (service-template.sh)
- Standard commands: `serve`, `stop`, `status`, `logs`, `restart`
- PID file: `/var/run/fellowos/`
- Logs: `/var/log/fellowos/`
- Services: `/opt/fellowos/services/`

## Path Conventions
- AI models: `/ai/models/`
- Training data: `/ai/data/`
- Cache: `/ai/cache/`
- FellowOS services: `/opt/fellowos/`

---

# Testing Notes

**Cannot test locally** - requires:
- Actual DGX Spark hardware (ARM64 + Blackwell GPU)
- Real NVMe disk for partition scripts
- DGX OS environment for CUDA detection

**Validation approach:**
- Syntax check: `bash -n script.sh`
- ShellCheck: `shellcheck script.sh`
- Dry-run flags where possible
- Test on actual hardware before release

---

# References

## NVIDIA Documentation
- [DGX OS 7 User Guide](https://docs.nvidia.com/dgx/dgx-os-7-user-guide/)
- [DGX Spark User Guide](https://docs.nvidia.com/dgx/dgx-spark/)
- [Release Notes](https://docs.nvidia.com/dgx/dgx-spark/release-notes.html)

## Community Resources
- [NVIDIA/dgx-spark-playbooks](https://github.com/NVIDIA/dgx-spark-playbooks) - Official playbooks
- [natolambert/dgx-spark-setup](https://github.com/natolambert/dgx-spark-setup) - OOM protection patterns
- [eelbaz/dgx-spark-vllm-setup](https://github.com/eelbaz/dgx-spark-vllm-setup) - Service script patterns

## Related Projects
- [FellowOS](https://github.com/walkyri/FellowOS) - AI operating system (sits on this base layer)

---

# Common Tasks

## Adding a New Service Script
1. Copy `scripts/service-template.sh` to `scripts/<service>.sh`
2. Edit CONFIGURATION section (name, port, paths)
3. Implement `start_service()` function
4. Test: `./scripts/<service>.sh status`

## Updating for New DGX OS Version
1. Check [release notes](https://docs.nvidia.com/dgx/dgx-os-7-user-guide/release_notes.html)
2. Update versions in `README.md` and `docs/dgx-stack-install.md`
3. Verify CUDA paths in `cuda-env-setup.sh` still work
4. Test on hardware

---

# Do Not

- Don't assume x86 paths - this is ARM64 (aarch64)
- Don't use `sudo` in scripts without checking `$EUID` first
- Don't hardcode CUDA versions - use detection where possible
- Don't test partition scripts on real disks without explicit user confirmation
- Don't use sed to edit structured config files (YAML, JSON) - use Python
- Don't give multi-line commands to paste - write scripts instead
