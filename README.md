# TagSync

** PLEASE NOTE: This software is in pre-alpha

TagSync is a "just works" 1-to-1 Linux filesystem backup tool with per-path tracking.

Unlike traditional backup tools, TagSync does not require you to move files to a specific folder or maintain a file list. You just tag/untag what you want, and the tool do the rest.

## Workflow Example:
You tag a file: it gets backed up.
You move the file: the backup moves it, too.
You tag a directory: the whole dir gets backed up.
You move an untagged file outside of a tagged dir: poof, gone from the backup.

## Spirit of this Software:
- "Just work": always as expected.
- Low maintenance: simple configuration, clear choices, reversable decisions.
- Never break: Any Ctrl+C will never leave backups in a confused state.
- Pause & Resume: Everything can be paused, resumed, and safely interrupted.

## Features
- **Flag any object for backup**: files, directories, special files, etc.
- **Symlinks are NEVER followed**: no loops, no surprises.
- **Arbitrary Granulatiy:** Tag individual files, or entire directories.
- **Path Tracking:** Paths are intelligently preserved on a per-file basis.
- **Self-exclusion:** A backup being beformed will never traverse into its own target.
- **Per-filesystem design:** IDs only persist on their original filesystem.
- **Simple CLI tools** to set, unset, and show tags, and to browse for tagged / untagged objects.
- **Fast:** By default, just compares sizes and timestamps between source and target (paranoid mode is coming soon).
- **Backup Groups:** Objects can be labelled such that a backup can be run independently (eg, files labelled 'personal', 'work', 'system', etc).

## Upcoming Features
- **Incremental Backups**: Keep X number of backups, or Y maximum size, or after Z date - or any combination of the three. Select to store incremental backups as hardlinks inside dated directories (/my/backup/20250731/file.txt), or dated file extensions instead (/my/backup/file.txt.ts-20250731). Optionally toggle between method. Since toggling from one method to another is a mere matter of renaming files/dirs, a toggle operation can be paused and resumed later, even with a backup being run in the interim. All to work as expected (since this is just renames).
- **Manifesting**: store size, date, path, and timestamps of objects at the backup target.
- **Path Tracking:** if an object is moved to a different path, this will propagate properly to to target.
- **Smart Mode:** automatically determine whether md5sums should be compared, on a per-object basis. For example, ISO/disk images will me md5sum'd, but office documents will not. This will use a combination of checking file extensions as well as file headers, depending on certain file aspects (eg, if the file word.doc is 8gb in size, the script will check the header just to make sure that the extnesion isn't lying to us).
- **Paranoid Mode:** Optionally configurable to always check & manifest md5sums for ALL files always.
- **Chunking:** Splits large files at target (by a configurable size). An object will then be composed of multiple chunks. For space efficiency, identical chunks of disparate objects are hard-linked at backup target, while retaining each object's unique id. Hard links are created when chunks becomes identical, and properly broken when they diverge.
- **Pause & Resume:** Large file chunks are preserved after paused/canceled runs, as long as source file hasn't changed (based on which smart/paranoid mode is selected)
- **Revision Control:** optional git for text-based files within the backup target. This will automatically create a new add+commit each time a file is backed up, with no help needed from the user, nor will any .git files be created at the source. (todo: work this into sync as well - prior to over-writing the older file, commit as an alternate branch). The cut-off size for files to be under revision control will be permanently tied to the size at which chunking is allowed (ie, revision control will be unavailable for files that are chunkable)
- **Synchronize:** A target can be arbitrarily toggled as a sync (two-way) of any number of sources, or as a backup (one-way). When switching to sync, any objects with revision control now become a git remote at the target, and a git clone at the source(s). Syncing will disable chunking and hard-linking (objects at target will be un-chunked and un-hard-linked on subsequent runs), and will delete .git dir of source objects (only if managed by TagSync!).
- **GUI Front-end**

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



