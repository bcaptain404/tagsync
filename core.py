import os
import subprocess

XATTR_NAME = "user.backup_id"

class TagSync:
    def __init__(self, dry_run=False, verbose=False, quiet=False, follow=False):
        self.dry_run = dry_run
        self.verbose = verbose
        self.quiet = quiet
        self.follow = follow

    def log(self, msg):
        if not self.quiet:
            print(msg)
    def vlog(self, msg):
        if self.verbose and not self.quiet:
            print(msg)
    def warn(self, msg):
        print(msg, file=os.sys.stderr)

    def get_xattr(self, path):
        """Returns the xattr value (as str) or '' if not found."""
        try:
            val = os.getxattr(path, XATTR_NAME)
            return val.decode() if isinstance(val, bytes) else val
        except (OSError, AttributeError):
            try:
                res = subprocess.run(
                    ["getfattr", "--only-values", "-n", XATTR_NAME, path],
                    stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True
                )
                return res.stdout.strip() if res.returncode == 0 else ''
            except Exception:
                return ''

    def find_tagged_files(self, src, names=None):
        tagged = []
        abs_src = os.path.abspath(src)
        for dirpath, dirnames, filenames in os.walk(abs_src, followlinks=self.follow):
            for fname in filenames + dirnames:
                fullpath = os.path.join(dirpath, fname)
                if os.path.islink(fullpath):
                    continue
                tag = self.get_xattr(fullpath)
                if tag and tag.startswith('ts/'):
                    if not names:
                        tagged.append(fullpath)
                    else:
                        tag_names = tag.split('/', 2)[-1].split(';') if '/' in tag[3:] else []
                        for name in names:
                            if name in tag_names:
                                tagged.append(fullpath)
                                break
        return tagged

    def backup_object(self, obj, abs_src, abs_dest):
        if os.path.isdir(obj) and not os.path.islink(obj):
            if self.dry_run:
                self.log(f"[DRY-RUN] Would rsync -iauHAX --no-links --relative '{obj}' '{abs_dest}/'")
            else:
                result = subprocess.run([
                    "rsync", "-iauHAX", "--no-links", "--relative", obj, abs_dest + "/"
                ])
                if result.returncode != 0:
                    self.warn(f"rsync failed for {obj}")
                else:
                    self.log(f"Backed up directory: {obj}")
        else:
            rel_path = os.path.relpath(obj, abs_src)
            dest_path = os.path.join(abs_dest, rel_path)
            if self.dry_run:
                self.log(f"[DRY-RUN] Would mkdir -p '{os.path.dirname(dest_path)}'")
                self.log(f"[DRY-RUN] Would rsync -iauHAX --no-links --relative '{obj}' '{abs_dest}/'")
            else:
                try:
                    os.makedirs(os.path.dirname(dest_path), exist_ok=True)
                except Exception:
                    self.warn(f"Failed to create directory for {dest_path}")
                result = subprocess.run([
                    "rsync", "-iauHAX", "--no-links", "--relative", obj, abs_dest + "/"
                ])
                if result.returncode != 0:
                    self.warn(f"rsync failed for {obj}")
                else:
                    self.log(f"Backed up file: {obj}")

    def backup(self, src_list, dest, names=None):
        abs_dest = os.path.abspath(dest)
        for src in src_list:
            if not os.path.isdir(src):
                self.warn(f"Source {src} is not a directory or not found. Skipping.")
                continue
            abs_src = os.path.abspath(src)
            objs = self.find_tagged_files(src, names)
            for obj in objs:
                self.backup_object(obj, abs_src, abs_dest)
