
---

## **todo.md**

```markdown
# Project Backup — TODO

## Core Features

- [x] Flag/unflag objects for backup with a unique xattr (`user.backup_id`)
- [x] CLI tools for setting, unsetting, and showing IDs
- [x] Backup script:
  - [x] Copies only flagged objects, preserving hierarchy
  - [x] If a directory is flagged, all its contents are backed up (regardless of their own backup flag)
  - [x] Skips symlinks entirely
  - [x] Excludes backup directory from itself (no recursion)
  - [x] Handles both absolute and relative paths safely
- [x] Per-filesystem design (Linux/ext3/ext4 only, no cross-filesystem dedupe)

## Planned Features / Next Steps

- [ ] Unique ID journal:
  - Track all assigned IDs in a journal file
  - On operation, compare and reconcile with backup's journal
  - Merge and dedupe journals if mismatched; fix any ID collisions found
- [ ] GUI integration:
  - File manager plugin (eg, Thunar/Nautilus/Dolphin)
  - Emblems for flagged/in-sync/pending files & directories
  - Optionally, store a backup-time md5sum as another xattr for quick sync status checks
- [ ] Dry-run mode for backup script
- [ ] Logging and error reporting
- [ ] User documentation and manpages
- [ ] Support for restore operations
- [ ] Optional: Exclude certain patterns or files (ignore rules)
- [ ] Optional: Compression/encryption of backups

## Sub-Projects

- [ ] Project Backup Emblems: File manager plugin to display sync/flag status emblems, including offline caching

## Constraints

- Per-filesystem only (IDs and tags are not portable across filesystems)
- Only for Linux systems with xattr support (ext3/ext4)
- Symlinks are always skipped
- Objects = any file, directory, or special file type

## Virgil Integration

- [ ] Virgil AI integration (in future):  
  - Allow Virgil to read, write, and use extended attributes in its own file operations


