# WORBI

WORBI is a local worldbuilding app packaged as an installable Nymph module for NymphsCore Manager.

This repo is intentionally simple:

- `nymph.json` describes WORBI to the Manager.
- `scripts/` contains stable Manager-facing wrapper scripts.
- `packages/` contains the current packaged WORBI archive.
- `docs/WORBI_GIT_MODULE_HOSTING_HANDOFF.md` explains the Rauty/NymphsCore integration plan.

Manager v1 should treat WORBI as a launcher/status module:

- install or repair WORBI
- start WORBI
- open WORBI
- stop WORBI
- show status and logs

WORBI itself owns the deeper app controls inside its browser UI.

## Rauty Handoff

The current integration handoff lives here:

[docs/WORBI_GIT_MODULE_HOSTING_HANDOFF.md](docs/WORBI_GIT_MODULE_HOSTING_HANDOFF.md)

This handoff explains how WORBI fits the NymphsCore Manager registry/module system and what the Manager needs from this repo.

## Local Runtime

Default install root:

```text
~/worbi
```

Default URLs:

```text
App:    http://localhost:8082
Health: http://localhost:8082/api/health
```

## Scripts

```bash
bash scripts/install_worbi.sh
bash scripts/worbi_start.sh
bash scripts/worbi_status.sh
bash scripts/worbi_stop.sh
bash scripts/worbi_logs.sh
```
