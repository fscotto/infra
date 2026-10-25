import configparser
import pathlib
import re
import sys
import xml.etree.ElementTree as ET

root = pathlib.Path(sys.argv[1]).resolve()
home = pathlib.Path.home()
local_filesystems = {
    "btrfs", "ext2", "ext3", "ext4", "xfs", "zfs", "tmpfs", "overlay",
    "ramfs", "ntfs3", "vfat", "exfat",
}
mounts = []
for line in pathlib.Path("/proc/self/mountinfo").read_text().splitlines():
    fields, description = line.split(" - ", 1)
    mount = re.sub(r"\\([0-7]{3})", lambda m: chr(int(m[1], 8)), fields.split()[4])
    mounts.append((pathlib.Path(mount), description.split()[0]))
covering = [(p, kind) for p, kind in mounts if root == p or root.is_relative_to(p)]
if covering:
    selected = max(covering, key=lambda entry: len(entry[0].parts))
    if selected[1] not in local_filesystems:
        raise SystemExit("Media storage is not on a local filesystem; refusing to start")
for mount, kind in mounts:
    if mount.is_relative_to(root) and kind not in local_filesystems:
        raise SystemExit("Non-local mount beneath media storage; refusing to start")
sync_roots = []
nextcloud = home / ".config/Nextcloud/nextcloud.cfg"
if nextcloud.exists():
    configuration = configparser.ConfigParser(interpolation=None, strict=False)
    configuration.read(nextcloud)
    for section in configuration.sections():
        for key, value in configuration.items(section):
            if key.lower().endswith("localpath"):
                sync_roots.append(pathlib.Path(value).expanduser().resolve())
for configuration in (
    home / ".config/syncthing/config.xml",
    home / ".local/state/syncthing/config.xml",
):
    if configuration.exists():
        for folder in ET.parse(configuration).getroot().findall("folder"):
            if folder.get("path"):
                sync_roots.append(pathlib.Path(folder.get("path")).expanduser().resolve())
for path in sync_roots:
    if root == path or root.is_relative_to(path) or path.is_relative_to(root):
        raise SystemExit("Media storage overlaps a Nextcloud/Syncthing folder; refusing to start")
