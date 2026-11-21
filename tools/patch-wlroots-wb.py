import sys, os
p = os.path.join(sys.argv[1], "backend", "drm", "drm.c")
s = open(p).read()

old_scan = '''void scan_drm_connectors(struct wlr_drm_backend *drm,
		struct wlr_device_hotplug_event *event) {'''
new_scan = '''/* Qualcomm SDE (downstream msm_drm) exposes its writeback block as a
 * "Virtual" connector that always reports connected. It is not a display:
 * creating an output for it only adds a bogus monitor to the settings. */
static bool is_msm_writeback(struct wlr_drm_backend *drm,
		const drmModeConnector *conn) {
	if (conn->connector_type != DRM_MODE_CONNECTOR_VIRTUAL) {
		return false;
	}
	drmVersion *version = drmGetVersion(drm->fd);
	bool msm = version != NULL && strcmp(version->name, "msm_drm") == 0;
	drmFreeVersion(version);
	return msm;
}

void scan_drm_connectors(struct wlr_drm_backend *drm,
		struct wlr_device_hotplug_event *event) {'''
assert s.count(old_scan) == 1, "scan"
s = s.replace(old_scan, new_scan)

old = '''		drmModeConnector *drm_conn = drmModeGetConnector(drm->fd, conn_id);
		if (!drm_conn) {
			wlr_log_errno(WLR_ERROR, "Failed to get DRM connector");
			continue;
		}

		if (!wlr_conn) {'''
new = '''		drmModeConnector *drm_conn = drmModeGetConnector(drm->fd, conn_id);
		if (!drm_conn) {
			wlr_log_errno(WLR_ERROR, "Failed to get DRM connector");
			continue;
		}

		if (!wlr_conn && is_msm_writeback(drm, drm_conn)) {
			drmModeFreeConnector(drm_conn);
			continue;
		}

		if (!wlr_conn) {'''
assert s.count(old) == 1, "body"
s = s.replace(old, new)
open(p, "w").write(s)
print("patched")
