import errno, importlib.machinery, importlib.util, os, sys
loader = importlib.machinery.SourceFileLoader("hms", sys.argv[1])
hms = importlib.util.module_from_spec(importlib.util.spec_from_loader("hms", loader)); loader.exec_module(hms)
point, argv = sys.argv[2], sys.argv[3:]
target = os.path.realpath(os.environ.get("CRASH_PATH", "")) if os.environ.get("CRASH_PATH") else ""
state = {"after_backup": False, "calls": 0}


def die():
    os._exit(9)


def enospc():
    raise OSError(errno.ENOSPC, "No space left on device")


J = hms.Journal
if point == "after-create":
    o = J.create.__func__
    J.create = classmethod(lambda cls, *a: (o(cls, *a), die()))
elif point == "after-backup":
    o = hms.backup_file
    hms.backup_file = lambda *a: (o(*a), die())
elif point == "after-pending":
    o = J.add
    J.add = lambda self, **k: (o(self, **k), die())
elif point in ("in-config-write", "after-config-write"):
    o = hms.atomic_write

    def w(path, data, mode=0o600):
        if point == "in-config-write" and os.path.realpath(path) == target:
            die()
        o(path, data, mode)
        if point == "after-config-write" and os.path.realpath(path) == target:
            die()
    hms.atomic_write = w
elif point in ("after-config-written", "after-committed", "enospc-config-written"):
    o = J.set
    want = {"after-config-written": "config-written", "after-committed": "manifest-committed",
            "enospc-config-written": "config-written"}[point]

    def s(self, i, st, error=None):
        if point == "enospc-config-written" and st == want:
            enospc()
        o(self, i, st, error)
        if st == want:
            die()
    J.set = s
elif point == "after-manifest":
    o = hms.set_mf

    def m(sd, man, path, value):
        o(sd, man, path, value)
        die()
    hms.set_mf = m
elif point == "before-close":
    J.close = lambda self: die()
elif point in ("invalid-rollback-ok", "invalid-rollback-enospc"):
    ob, op, om = hms.backup_file, hms.parse_config, hms.set_mf

    def b(*a):
        r = ob(*a)
        state["after_backup"] = True
        return r

    def pc(*a):
        if state["after_backup"]:
            raise hms.Refused("injected parse-back failure")
        return op(*a)

    def m(*a):
        if point == "invalid-rollback-enospc":
            enospc()
        return om(*a)
    hms.backup_file, hms.parse_config, hms.set_mf = b, pc, m
elif point == "manifest-enospc-once":
    om = hms.set_mf

    def m(*a):
        state["calls"] += 1
        if state["calls"] == 1:
            enospc()
        return om(*a)
    hms.set_mf = m
elif point == "reconcile-crash":
    hms.set_mf = lambda *a: die()
sys.stdout, sys.stderr = hms.Redactor(sys.stdout), hms.Redactor(sys.stderr)
code = hms.run(argv)
sys.stdout.flush()
sys.exit(code)
