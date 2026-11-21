import sys, os
p = os.path.join(sys.argv[1], "gio", "glocalfile.c")
s = open(p).read()
old = '''  else if G_UNLIKELY (errno == EINVAL)
    {
      g_critical ("g_local_file_query_exists: faccessat doesn't support supplied flags");
    }

  return FALSE;'''
new = '''  else if G_UNLIKELY (errno == EINVAL)
    {
      /* musl's faccessat() only accepts AT_EACCESS and fails with EINVAL
       * when AT_SYMLINK_NOFOLLOW is passed. Answer the question with
       * lstat() instead, like the fallback implementation does. */
      GStatBuf buf;

      return g_lstat (local->filename, &buf) == 0;
    }

  return FALSE;'''
assert s.count(old) == 1, "pattern"
open(p, "w").write(s.replace(old, new))
print("patched", p)
