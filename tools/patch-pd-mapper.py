import sys, os

p = os.path.join(sys.argv[1], "pd-mapper.c")
s = open(p).read()


def rep(old, new):
    global s
    assert s.count(old) == 1, old[:60]
    s = s.replace(old, new)


# the directory scan becomes a helper used by both lookups
rep('''static int pd_enumerate_jsons(struct assoc *json_set)
{''',
'''static void add_jsons_from_dir(struct assoc *json_set, DIR *fw_dir, const char *path)
{
	char json_path[PATH_MAX];
	struct dirent *fw_de;
	size_t len;

	while ((fw_de = readdir(fw_dir)) != NULL) {
		int extens_index;
		bool found = false;

		if (!strcmp(fw_de->d_name, ".") || !strcmp(fw_de->d_name, ".."))
			continue;

		len = strlen(fw_de->d_name);

		for (extens_index = 0; known_extensions[extens_index] != NULL; extens_index++) {
			int extens_len = strlen(known_extensions[extens_index]);
			if (len > extens_len &&
			    !strcmp(&fw_de->d_name[len - extens_len], known_extensions[extens_index])) {
				found = true;
				break;
			}
		}

		if (!found)
			continue;

		if (strlen(path) + 1 + strlen(fw_de->d_name) + 1 > sizeof(json_path))
			continue;

		strcpy(json_path, path);
		strcat(json_path, "/");
		strcat(json_path, fw_de->d_name);

		assoc_set(json_set, json_path, NULL);
	}
}

/*
 * Downstream (PIL based) kernels have no remoteproc class: use the jsons in
 * the firmware directory itself, the one given to the kernel through
 * firmware_class.path or else /lib/firmware.
 */
static int pd_enumerate_jsons_flat(struct assoc *json_set)
{
	char path[PATH_MAX];
	DIR *fw_dir;
	ssize_t n;
	int fd;

	fd = open(FIRMWARE_PARAM_PATH, O_RDONLY);
	if (fd >= 0) {
		n = read(fd, path, sizeof(path) - 1);
		close(fd);
		if (n > 0) {
			path[n] = '\\0';
			if (path[n - 1] == '\\n')
				path[n - 1] = '\\0';
			fw_dir = path[0] ? opendir(path) : NULL;
			if (fw_dir) {
				add_jsons_from_dir(json_set, fw_dir, path);
				closedir(fw_dir);
				return 0;
			}
		}
	}

	strcpy(path, "/lib/firmware");
	fw_dir = opendir(path);
	if (!fw_dir)
		return -1;
	add_jsons_from_dir(json_set, fw_dir, path);
	closedir(fw_dir);
	return 0;
}

static int pd_enumerate_jsons(struct assoc *json_set)
{''')

rep('''	class_fd = open("/sys/class/remoteproc", O_RDONLY | O_DIRECTORY);
	if (class_fd < 0) {
		warn("failed to open remoteproc class");
		return -1;
	}''',
'''	class_fd = open("/sys/class/remoteproc", O_RDONLY | O_DIRECTORY);
	if (class_fd < 0) {
		warn("failed to open remoteproc class, using the firmware directory");
		return pd_enumerate_jsons_flat(json_set);
	}''')

rep('''		fw_dir = opendir_firmware(firmware_path, path, sizeof(path));
		if (!fw_dir)
			continue;

		while ((fw_de = readdir(fw_dir)) != NULL) {
			int extens_index;
			bool found = false;

			if (!strcmp(fw_de->d_name, ".") || !strcmp(fw_de->d_name, ".."))
				continue;

			len = strlen(fw_de->d_name);

			for (extens_index = 0; known_extensions[extens_index] != NULL; extens_index++) {
				int extens_len = strlen(known_extensions[extens_index]);
				if (len > extens_len &&
				    !strcmp(&fw_de->d_name[len - extens_len], known_extensions[extens_index])) {
					found = true;
					break;
				}
			}

			if (!found)
				continue;

			if (strlen(path) + 1 + strlen(fw_de->d_name) + 1 > sizeof(json_path))
				continue;

			strcpy(json_path, path);
			strcat(json_path, "/");
			strcat(json_path, fw_de->d_name);

			assoc_set(json_set, json_path, NULL);
		}

		closedir(fw_dir);''',
'''		fw_dir = opendir_firmware(firmware_path, path, sizeof(path));
		if (!fw_dir)
			continue;

		add_jsons_from_dir(json_set, fw_dir, path);

		closedir(fw_dir);''')

# now unused locals
rep('''	char *firmware_path = NULL;
	char json_path[PATH_MAX];
	char firmware_attr[32];
	struct dirent *fw_de;
	char path[PATH_MAX];''',
'''	char *firmware_path = NULL;
	char firmware_attr[32];
	char path[PATH_MAX];''')
rep('''	DIR *fw_dir;
	size_t len;
	size_t n;

	class_fd''',
'''	DIR *fw_dir;
	size_t n;

	class_fd''')
open(p, "w").write(s)
print("patched pd-mapper")
