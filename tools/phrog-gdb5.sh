#!/bin/sh
cat > /tmp/phrog5.gdb <<'EOF'
set pagination off
set debug-file-directory /usr/lib/debug
run
bt 8
frame 6
print task->name
print task->source_tag
print task->source_object
print *(GTypeInstance *)task->source_object
print g_type_name(((GTypeInstance *)task->source_object)->g_class->g_type)
print task->had_error
print task->error
EOF
chmod 644 /tmp/phrog5.gdb
for lib in r10 r0; do
	echo "===== $lib"
	if [ $lib = r0 ]; then L=LD_LIBRARY_PATH=/tmp/r0/usr/lib; else L=; fi
	sudo -u greetd env -i $(cat /tmp/phrog.env | tr '\n' ' ') $L gdb -q -batch -x /tmp/phrog5.gdb /usr/sbin/phrog 2>&1 \
	  | grep -E '^#[0-9]|^\$[0-9]|SIGSEGV' | cut -c1-200
done
