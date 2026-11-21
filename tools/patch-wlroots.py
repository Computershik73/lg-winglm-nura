import sys, os
root = sys.argv[1]  # wlroots tree
which = sys.argv[2]

if which == "refresh":
    p = os.path.join(root, "backend", "drm", "util.c")
    s = open(p).read()
    old = '''int32_t calculate_refresh_rate(const drmModeModeInfo *mode) {
	int32_t refresh = (mode->clock * 1000000LL / mode->htotal +
		mode->vtotal / 2) / mode->vtotal;
'''
    new = '''/* Qualcomm downstream (SDE) kernels flag DSI command mode panels with bit 30
 * (DRM_MODE_FLAG_CMD_MODE_PANEL). Their mode clock is the DSI link pixel
 * clock, not one that matches the timings: the panel refreshes on its TE
 * signal at mode->vrefresh. Computing the rate from the clock gives
 * e.g. 24.3 Hz for a 60 Hz panel. */
#define MSM_DRM_MODE_FLAG_CMD_MODE_PANEL (1 << 30)

int32_t calculate_refresh_rate(const drmModeModeInfo *mode) {
	if ((mode->flags & MSM_DRM_MODE_FLAG_CMD_MODE_PANEL) && mode->vrefresh > 0) {
		return mode->vrefresh * 1000;
	}

	int32_t refresh = (mode->clock * 1000000LL / mode->htotal +
		mode->vtotal / 2) / mode->vtotal;
'''
    assert s.count(old) == 1, "refresh"
    open(p, "w").write(s.replace(old, new))
elif which == "finish":
    p = os.path.join(root, "render", "gles2", "pass.c")
    s = open(p).read()
    old = '''	} else {
		glFlush();
	}

	ok = true;'''
    new = '''	} else {
		/* Without a timeline the buffer goes to KMS relying on implicit
		 * sync. Qualcomm KGSL (turnip/zink) attaches no implicit fences to
		 * exported dma-bufs, so the display engine scanned out frames the
		 * GPU had not finished: black, staircase-shaped bins during
		 * animations. Wait for the GPU instead. */
		glFinish();
	}

	ok = true;'''
    assert s.count(old) == 1, "finish"
    open(p, "w").write(s.replace(old, new))
print("patched", which)
