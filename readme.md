# Project Backup

**Project Backup** is a Linux-only backup tool that uses extended attributes (`xattrs`) to flag files, directories, or special files ("objects") for backup.  
Unlike traditional backup tools, Project Backup does not require you to move files to a specific folder or maintain an external list—just tag what you want, and let the tool do the rest.

## Features

- **Flag any object for backup** by setting a unique extended attribute (`user.backup_id`).
- **Backup script copies only flagged objects**, preserving their full directory hierarchy from the source.
- **Symlinks are never followed** (no loops, no surprises).
- **Self-exclusion:** The script never backs up its own output directory, even if you try to trick it with relative paths.
- **Per-filesystem design:** xattr IDs and flags only persist on their original filesystem. Copying or moving files across filesystems creates new objects with new IDs (by design).
- **Simple CLI tools** to set, unset, and show backup flags.

## Requirements

- Linux (ext3 or ext4 filesystem with user xattrs enabled)
- `bash`
- `rsync` (with xattr support)
- `setfattr`, `getfattr`
- `uuidgen`

## Usage

Flag a file or directory for backup:
```bash
./set_backup_id.sh myfile.txt      # Set a backup ID
./set_backup_id.sh myfile.txt unset # Remove backup ID
./show_backup_id.sh file1 dir1 ... # See which files are flagged:
./backup.sh /source/path /backup/dest  # Run a backup. This will copy all flagged objects (and, if a directory is flagged, all its contents) into /backup/dest, preserving full source paths.
```

## Notes
- Objects = any file, directory, or special file type (block device, etc).
- Moving files with mv within the same filesystem retains the backup flag. Copying with cp does not (this is intentional).
- Not cross-filesystem: IDs are only meaningful per-filesystem.
- For best results, always use absolute paths (though relative paths are supported).



