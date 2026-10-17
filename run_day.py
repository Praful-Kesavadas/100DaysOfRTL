#!/usr/bin/env python3
"""
run_day.py - compile and simulate days of the 100DaysofRTL repo with Icarus Verilog.

Examples (run from the repo root, or pass --repo):
    python run_day.py 85                 # run Day 085
    python run_day.py 27                 # runs "Day 027" AND "Day 027 - Bonus"
    python run_day.py 1-10 50 77         # ranges and lists mix freely
    python run_day.py all                # whole repo, summary table at the end
    python run_day.py 85 -v              # also print the full simulation output
    python run_day.py 54 --regen         # re-run the day's gen*.py scripts first
    python run_day.py 77 --keep-waves    # copy dump.vcd back into the day folder
    python run_day.py all --csv out.csv  # save the summary
    python run_day.py --list             # show what the script discovers

How it works
  * Each day is simulated inside a throw-away sandbox, so your repo (dump.vcd,
    out.vvp, generated hex files, ...) is never modified.
  * files.f in a day folder, if present, is used as the compile filelist.
  * Several tb*.v files in one day -> one simulation per testbench.
  * A module that lives in another day (e.g. full_adder from Day 007) is found
    automatically and added to the compile.
  * verify*.py checkers in a day folder (Day 054) run after the simulation.
  * Result = compile status + timeout + exit code + the [PASS]/[FAIL]/ERROR/
    MISMATCH markers your testbenches print.
"""
import argparse
import csv
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

DAY_RE = re.compile(r"^Day (\d+)(?: - (.+))?$")
TB_RE = re.compile(r"^(tb.*|.*_tb)\.(v|sv)$", re.IGNORECASE)
SRC_EXT = {".v", ".sv"}
MODULE_RE = re.compile(r"^\s*module\s+(\w+)", re.MULTILINE)
MISSING_RE = re.compile(r"Unknown module type:\s*(\w+)")
MISSING_LIST_RE = re.compile(r"^\s+(\w+) referenced \d+ times", re.MULTILINE)

# Markers are kept specific on purpose: a test *named* "Framing Error Detection"
# or "Address Mismatch Rejection" must not count as a failure.
FAIL_RE = re.compile(r"\[FAIL\]|\bFAILED\b|\[ERROR\]|\bERROR:|\[MISMATCH\]|\bMISMATCH:", re.IGNORECASE)
PASS_RE = re.compile(r"\[PASS\]|\bPASS(ED)?\b|\bSUCCESS(FUL)?\b|ALL TESTS", re.IGNORECASE)


# ----------------------------------------------------------------- discovery
def find_days(repo: Path):
    """{day_number: [Path, ...]} for every 'Day NNN[ - suffix]' folder."""
    days = {}
    for p in sorted(repo.iterdir()):
        m = DAY_RE.match(p.name)
        if p.is_dir() and m:
            days.setdefault(int(m.group(1)), []).append(p)
    return days


def parse_selection(tokens, available):
    """'85', '1-10', 'all' -> sorted list of day numbers that exist."""
    if not tokens or "all" in [t.lower() for t in tokens]:
        return sorted(available)
    chosen = set()
    for t in tokens:
        if "-" in t:
            lo, hi = t.split("-", 1)
            chosen.update(range(int(lo), int(hi) + 1))
        else:
            chosen.add(int(t))
    missing = sorted(chosen - set(available))
    if missing:
        print(f"[warn] no folder for day(s): {missing}", file=sys.stderr)
    return sorted(chosen & set(available))


def build_module_index(days):
    """module name -> [(day_number, Path to non-testbench source)]"""
    index = {}
    for n, dirs in days.items():
        for d in dirs:
            for f in d.iterdir():
                if f.suffix in SRC_EXT and not TB_RE.match(f.name):
                    try:
                        text = f.read_text(errors="replace")
                    except OSError:
                        continue
                    for name in MODULE_RE.findall(text):
                        index.setdefault(name, []).append((n, f))
    return index


def plan_runs(day_dir: Path):
    """
    What to compile for one day folder -> list of (label, iverilog_args).
      files.f present  -> one run using the filelist
      several tbs      -> one run per testbench, sharing the design files
      otherwise        -> one run with every source file
    """
    sources = sorted(f for f in day_dir.iterdir() if f.suffix in SRC_EXT)
    if (day_dir / "files.f").exists():
        return [("files.f", ["-f", "files.f"])]
    tbs = [f for f in sources if TB_RE.match(f.name)]
    designs = [f.name for f in sources if f not in tbs]
    return [(tb.name if len(tbs) > 1 else "tb", [tb.name] + designs) for tb in tbs]


# ----------------------------------------------------------------- sandbox
def make_sandbox(repo: Path, days, day_dir: Path, root: Path):
    """
    root/<every Day folder> : symlink to the real folder (read-only use), except
    root/<day_dir.name>     : real copy (minus big artefacts) that the sim can write to.
    """
    for dirs in days.values():
        for d in dirs:
            link = root / d.name
            if d == day_dir:
                shutil.copytree(d, link, ignore=shutil.ignore_patterns("*.png", "*.vcd", "*.vvp", "__pycache__"))
            else:
                link.symlink_to(d, target_is_directory=True)
    return root / day_dir.name


# ----------------------------------------------------------------- execution
def run_cmd(cmd, cwd, timeout, env=None):
    try:
        r = subprocess.run(cmd, cwd=cwd, capture_output=True, timeout=timeout, env=env)
        return r.returncode, (r.stdout + r.stderr).decode("utf-8", "replace"), False
    except subprocess.TimeoutExpired as e:
        out = e.stdout or b""
        return -1, out.decode("utf-8", "replace") if isinstance(out, bytes) else out, True


def short_errors(text, limit=8):
    """Collapse repeated compiler lines so a missing-module error is not 100 lines long."""
    seen, out = set(), []
    for line in text.strip().splitlines():
        key = re.sub(r"^.*?:\d+:\s*", "", line)
        if key not in seen:
            seen.add(key)
            out.append(line)
    more = f"\n    ... ({len(out) - limit} more)" if len(out) > limit else ""
    return "\n    ".join(out[:limit]) + more


def compile_day(cwd, vvp, args, extra, index, sandbox_root, day_n, timeout):
    """iverilog with auto-resolution of modules defined in other days."""
    added = []
    for _ in range(10):
        extra_files = [f"../{p.parent.name}/{p.name}" for p in added]
        rc, out, _ = run_cmd(["iverilog", "-g2012", "-o", str(vvp), *extra, *args, *extra_files], cwd, timeout)
        if rc == 0:
            return True, out, added
        missing = set(MISSING_RE.findall(out)) | set(MISSING_LIST_RE.findall(out))
        new = []
        for m in sorted(missing):
            cands = [c for c in index.get(m, []) if c[1] not in added]
            if not cands:
                continue
            earlier = [c for c in cands if c[0] <= day_n]
            pick = max(earlier, key=lambda c: c[0]) if earlier else min(cands, key=lambda c: c[0])
            new.append(pick[1])
        if not new:
            return False, out, added
        added.extend(new)
    return False, out, added


def judge(rc, out, timed_out):
    lines = out.splitlines()
    fails = [l for l in lines if FAIL_RE.search(l)]
    passes = [l for l in lines if PASS_RE.search(l)]
    if timed_out:
        return "TIMEOUT", len(passes), len(fails)
    if rc != 0:
        return "SIM-ERROR", len(passes), len(fails)
    if fails:
        return "FAIL", len(passes), len(fails)
    if passes:
        return "PASS", len(passes), 0
    return "RAN-OK", 0, 0   # ran cleanly, but the testbench has no self-check (inspect waveform)


def run_one(cwd, day_n, label, args, tmp, timeout, verbose, extra, index, sandbox_root):
    vvp = tmp / f"{re.sub(r'[^A-Za-z0-9]+', '_', cwd.name + label)}.vvp"
    ok, out, added = compile_day(cwd, vvp, args, extra, index, sandbox_root, day_n, timeout)
    for p in added:
        print(f"    [auto] added {p.parent.name}/{p.name} (module defined in another day)")
    if not ok:
        print("    " + short_errors(out))
        if "sorry:" in out:   # Icarus' wording for SystemVerilog features it lacks
            print("    [note] uses SystemVerilog features Icarus does not support "
                  "(classes/constraints/mailbox); needs Verilator or a commercial simulator")
            return "NEEDS-SV-SIM", 0, 0, ""
        return "COMPILE-ERR", 0, 0, ""
    t0 = time.time()
    rc, out, timed_out = run_cmd(["vvp", str(vvp)], cwd, timeout)
    # Python checkers (e.g. Day 054's verify_sine.py) are part of the day's verification
    checker_crashed = False
    for chk in sorted(cwd.glob("verify*.py")):
        # MPLBACKEND: never open plot windows. PYTHONUTF8/IOENCODING: scripts that print
        # emoji (e.g. verify_sine.py) crash with UnicodeEncodeError on Windows pipes otherwise.
        env = {**os.environ, "MPLBACKEND": "Agg", "PYTHONUTF8": "1", "PYTHONIOENCODING": "utf-8"}
        crc, cout, _ = run_cmd([sys.executable, chk.name], cwd, timeout, env)
        out += f"\n--- {chk.name} ---\n{cout}"
        if crc != 0 and not FAIL_RE.search(cout):
            checker_crashed = True   # non-zero exit with no verdict markers = the script itself broke
        rc = rc or crc
    status, p, f = judge(rc, out, timed_out)
    if status == "SIM-ERROR" and checker_crashed:
        status = "CHECKER-ERR"   # the Python checker crashed (traceback above), not the simulation
    if verbose or status not in ("PASS", "RAN-OK"):
        print("    " + out.strip().replace("\n", "\n    "))
    return status, p, f, f"{time.time() - t0:.2f}s"


# ----------------------------------------------------------------- main
def main():
    ap = argparse.ArgumentParser(description="Run days of the 100DaysofRTL repo.")
    ap.add_argument("days", nargs="*", help="day numbers, ranges (1-10) or 'all'")
    ap.add_argument("--repo", default=".", help="repo root (default: current dir)")
    ap.add_argument("--timeout", type=int, default=60, help="seconds per step (default 60)")
    ap.add_argument("-v", "--verbose", action="store_true", help="print full simulation output")
    ap.add_argument("--regen", action="store_true", help="re-run each day's gen*.py first")
    ap.add_argument("--keep-waves", action="store_true", help="copy generated *.vcd back to the day folder")
    ap.add_argument("--list", action="store_true", help="show discovered runs and exit")
    ap.add_argument("--csv", metavar="FILE", help="write the summary to a CSV file")
    ap.add_argument("-I", dest="incdirs", action="append", default=[], help="extra include dir")
    a = ap.parse_args()

    repo = Path(a.repo).resolve()
    days = find_days(repo)
    if not days:
        sys.exit(f"No 'Day NNN' folders found in {repo}")
    selected = parse_selection(a.days, days)

    if a.list:
        for n in selected:
            for d in days[n]:
                print(f"{d.name}: {[l for l, _ in plan_runs(d)] or 'no testbench found'}")
        return

    for tool in ("iverilog", "vvp"):
        if shutil.which(tool) is None:
            sys.exit(f"'{tool}' not found on PATH (install Icarus Verilog)")

    index = build_module_index(days)
    run_tmp = repo / ".run_tmp"          # scratch space lives in the repo, not on the C: drive
    run_tmp.mkdir(exist_ok=True)
    extra = [x for inc in a.incdirs for x in ("-I", inc)]
    rows = []
    for n in selected:
        for d in days[n]:
            runs = plan_runs(d)
            if not runs:
                rows.append((d.name, "-", "NO-TB", 0, 0, ""))
                continue
            with tempfile.TemporaryDirectory(dir=run_tmp) as t:
                tmp = Path(t)
                cwd = make_sandbox(repo, days, d, tmp)
                if a.regen:
                    for py in sorted(cwd.glob("gen*.py")):
                        print(f"    [regen] python {py.name}")
                        rc, out, _ = run_cmd([sys.executable, py.name], cwd, a.timeout,
                                              {**os.environ, "MPLBACKEND": "Agg", "PYTHONUTF8": "1", "PYTHONIOENCODING": "utf-8"})
                        if rc != 0:
                            print(out)
                for label, args in runs:
                    print(f"==> {d.name} [{label}]")
                    status, p, f, note = run_one(cwd, n, label, args, tmp, a.timeout,
                                                 a.verbose, extra, index, tmp)
                    rows.append((d.name, label, status, p, f, note))
                if a.keep_waves:
                    for vcd in cwd.glob("*.vcd"):
                        shutil.copy(vcd, d / vcd.name)

    try:
        run_tmp.rmdir()                  # remove the scratch folder again if it is empty
    except OSError:
        pass

    print("\n" + "=" * 68)
    print(f"{'Day':<18}{'Testbench':<22}{'Result':<13}{'pass':>5}{'fail':>5}  time")
    print("-" * 68)
    for r in rows:
        print(f"{r[0]:<18}{r[1][:21]:<22}{r[2]:<13}{r[3]:>5}{r[4]:>5}  {r[5]}")
    count = lambda *st: sum(r[2] in st for r in rows)
    bad = count("FAIL", "SIM-ERROR", "CHECKER-ERR", "TIMEOUT", "COMPILE-ERR")
    print("-" * 68)
    print(f"{len(rows)} runs: {count('PASS')} PASS | {count('RAN-OK')} RAN-OK (no self-check) | "
          f"{count('NEEDS-SV-SIM', 'NO-TB')} skipped | {bad} failed")

    if a.csv:
        with open(a.csv, "w", newline="") as fh:
            w = csv.writer(fh)
            w.writerow(["day", "testbench", "result", "pass_lines", "fail_lines", "time"])
            w.writerows(rows)

    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()