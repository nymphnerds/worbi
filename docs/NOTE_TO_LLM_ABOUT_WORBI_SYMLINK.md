# NOTE TO LLM: WORBI Install Caveats

## Critical: `server/dist` Symlink

WORBI's Express server expects the built frontend at `server/dist/`. The production install uses a **symlink** to avoid duplication:

```
/home/nymph/worbi/server/dist -> /home/nymph/worbi/dist
```

**When updating WORBI:**
- **NEVER** remove or overwrite `server/dist` without recreating the symlink
- The `dist/` directory lives at `$INSTALL_DIR/dist/` (top-level), not inside `server/`
- After copying new files, ensure the symlink exists:
  ```bash
  ln -sf "$INSTALL_DIR/dist" "$INSTALL_DIR/server/dist"
  ```
- Without this symlink, the server logs "Frontend dist/ not found — API-only mode" and returns `Cannot GET /` on root requests.

## Critical: Preserve User Data on Update

User data lives in:

| Path | Contents |
|------|----------|
| `server/src/data/users/` | Per-user directories (29+ users) |
| `server/src/data/users.json` | User registry (usernames, timestamps) |
| `server/src/data/user-settings/` | Per-user settings files |
| `logs/` | Server logs |

**Update procedure (what `installer_from_package.sh` does):**

1. Stop running server (`worbi-stop`)
2. Back up entire `$INSTALL_DIR` to `$INSTALL_DIR.backup.<timestamp>`
3. Remove old `server/`, `bin/`, `dist/`
4. Copy new `dist/`, `server/`, `bin/` from archive
5. Create symlink `server/dist -> dist`
6. Restore user data from latest backup:
   - `users.json`
   - `user-settings/`
   - `users/`

**Do NOT** ship user data inside the package archive. The archive contains empty `data/` directories. User data is preserved on-disk across updates via the backup/restore step.

## Archive Structure

```
worbi/
  dist/                  # Built frontend (Vite production)
  server/
    src/
      data/              # Empty on install (users, user-settings subdirs)
    package.json
  bin/
    worbi-start          # Production start script
    worbi-stop           # Production stop script
    worbi-status         # Status / contract output
  package.json           # Root package.json (version reference)
```

## bin Scripts

- `worbi-start` — starts server as daemon, writes PID file, creates symlink if missing
- `worbi-stop` — stops server via PID file, cleans up orphans
- `worbi-status` — outputs key=value contract for NymphsCore Manager

## Version Marker

After install, write the module version to:
```
$HOME/worbi/.nymph-module-version
```
Example content: `6.2.60` (no trailing newline from installer, `install_worbi.sh` adds `\n` via `printf`).

## npm install

The installer runs `npm install --loglevel=error` in `$INSTALL_DIR/server/` after extracting files. This installs server dependencies (`node_modules/`) which are **not** included in the archive.