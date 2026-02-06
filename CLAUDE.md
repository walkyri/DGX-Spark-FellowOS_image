# Claude Code Instructions - DGX Spark FellowOS Image

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
