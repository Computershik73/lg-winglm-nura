import sys, os
p = os.path.join(sys.argv[1], "translate.c")
s = open(p).read()
old = '''	read_fw_path_from_sysfs(fw_sysfs_path, sizeof(fw_sysfs_path));

	class_fd = open("/sys/class/remoteproc", O_RDONLY | O_DIRECTORY);
	if (class_fd < 0) {
		warn("failed to open remoteproc class");
		return -1;
	}
'''
new = '''	read_fw_path_from_sysfs(fw_sysfs_path, sizeof(fw_sysfs_path));

	class_fd = open("/sys/class/remoteproc", O_RDONLY | O_DIRECTORY);
	if (class_fd < 0) {
		/*
		 * Downstream (PIL based) kernels have no remoteproc class:
		 * look in the firmware directory itself, the one given to the
		 * kernel through firmware_class.path or else /lib/firmware.
		 */
		if (strlen(fw_sysfs_path) > 0 &&
		    strlen(fw_sysfs_path) + 1 + strlen(file) + 1 < sizeof(path)) {
			strcpy(path, fw_sysfs_path);
			strcat(path, "/");
			strcat(path, file);
			fd = open_maybe_compressed(path);
			if (fd >= 0)
				return fd;
		}
		if (strlen(FIRMWARE_BASE) + strlen(file) + 1 < sizeof(path)) {
			strcpy(path, FIRMWARE_BASE);
			strcat(path, file);
			fd = open_maybe_compressed(path);
			if (fd >= 0)
				return fd;
		}
		warn("failed to open %s without remoteproc class", file);
		return -1;
	}
'''
assert s.count(old) == 1
s = s.replace(old, new)
open(p, "w").write(s)
print("patched tqftpserv")
