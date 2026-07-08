# CHANGELOG

## v1.0 (2026-07-08)

- Initial release
- Three-layer state structure: global / project / task
- Snapshot lifecycle with metadata (seq, created_at, based_on_event)
- Project isolation — multi-project state without cross-contamination
- Cold start recovery — state restores after /new
- Model-independent recovery — works across different LLMs
- state-save / state-restore skills for Hermes Agent
- state-switch script for project switching
- Event log isolation per project
- State Reality Drift detection and reconciliation protocol
- Step-by-step setup.sh for one-command deployment