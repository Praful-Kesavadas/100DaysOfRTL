#!/usr/bin/env python3
"""
verify_cordic.py - Python co-verification for the Day 044 CORDIC (rotation mode).

The testbench (tb.v) logs every vector it applied and what the RTL returned to
rtl_results.txt  (x_in y_in theta_in x_out y_out, signed decimal). This script then:

  1. BIT-EXACT   : re-computes every vector with an integer Python model of the RTL
                   datapath and requires x_out/y_out to match exactly. Proves the RTL
                   does what the algorithm on paper says (prescale, pre-rotation,
                   truncating shifts, 18-bit guarded registers, LUT).
  2. ACCURACY    : compares the RTL output with floating-point rotation of the same
                   quantised inputs and reports max / mean / rms error in LSBs.
  3. CONVERGENCE : model-only sweep over every angle band, with and without the
                   quadrant pre-rotation, to show the plain datapath breaks beyond
                   ~99.88 deg and the pre-rotation fixes it.
  4. LUT / GAIN  : checks the hard-coded arctan table and gain constant against
                   math.atan / the analytic CORDIC gain.

Usage (from the Day 044 folder):
    python verify_cordic.py            # after the simulation has produced rtl_results.txt
    python verify_cordic.py --run      # compile + simulate with Icarus first
    python verify_cordic.py --plot     # also write cordic_accuracy.png (needs matplotlib)

Exit code 0 = everything passed, 1 = a check failed.
"""
import argparse
import math
import subprocess
import sys
from pathlib import Path

# ----------------------------------------------------------------------------
# Design constants (must mirror cordic_rotation.v)
# ----------------------------------------------------------------------------
DATA_W = 16                 # x, y, theta port width
EXT_W = 18                  # guarded internal register width
ITER = 16
FRAC = 14                   # Q2.14 data (and Q4.14 internal angle)
THETA_SHIFT = 1             # theta port is Q3.13 -> Q4.14 internally
K_Q14 = 9949                # 1/A, A = CORDIC gain, in Q2.14
PI_Q14 = 51472              # round(pi   * 2^14)
HALF_PI_Q14 = 25736         # round(pi/2 * 2^14)
ATAN_LUT = [12868, 7596, 4014, 2037, 1023, 512, 256, 128,
            64, 32, 16, 8, 4, 2, 1, 1]

TOL_LSB = 12.0              # keep in sync with TOL_LSB in tb.v
LSB = 2.0 ** -FRAC
CONVERGENCE_DEG = math.degrees(sum(math.atan(2.0 ** -i) for i in range(ITER)))  # ~99.88


# ----------------------------------------------------------------------------
# Bit-accurate model of the RTL
# ----------------------------------------------------------------------------
def wrap(v, bits):
    """Two's-complement wrap of a Python int to `bits` bits."""
    v &= (1 << bits) - 1
    return v - (1 << bits) if v >> (bits - 1) else v


def cordic_model(x, y, theta, prerotate=True):
    """x, y: Q2.14 ints. theta: Q3.13 int. Returns (x_out, y_out) as signed 16-bit ints.
    prerotate=False removes the quadrant pre-rotation (the original design's behaviour)."""
    # Prescale by 1/A so the CORDIC gain cancels. >> is an arithmetic floor, like Verilog >>>
    xr = wrap((x * K_Q14) >> FRAC, DATA_W)
    yr = wrap((y * K_Q14) >> FRAC, DATA_W)
    z = theta << THETA_SHIFT                       # Q3.13 -> Q4.14

    if prerotate:
        flip = z > HALF_PI_Q14 or z < -HALF_PI_Q14
        if z > HALF_PI_Q14:
            z -= PI_Q14
        elif z < -HALF_PI_Q14:
            z += PI_Q14
        if flip:                                    # rotate the vector by pi
            xr, yr = -xr, -yr

    for i in range(ITER):
        xs, ys = xr >> i, yr >> i
        if z >= 0:
            xr, yr, z = xr - ys, yr + xs, z - ATAN_LUT[i]
        else:
            xr, yr, z = xr + ys, yr - xs, z + ATAN_LUT[i]
        xr, yr, z = wrap(xr, EXT_W), wrap(yr, EXT_W), wrap(z, EXT_W)
    return wrap(xr, DATA_W), wrap(yr, DATA_W)


def float_ref(x, y, theta):
    """Ideal rotation of the quantised inputs, returned in LSBs (Q2.14 counts)."""
    a = theta / 2.0 ** 13
    c, s = math.cos(a), math.sin(a)
    return x * c - y * s, y * c + x * s


# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------
def err_stats(errs):
    n = len(errs)
    return max(errs), sum(errs) / n, math.sqrt(sum(e * e for e in errs) / n)


def load_results(path):
    rows = []
    for ln, line in enumerate(path.read_text().splitlines(), 1):
        parts = line.split()
        if not parts or parts[0].startswith("#"):
            continue
        if len(parts) != 5:
            raise ValueError(f"{path.name}:{ln}: expected 5 integers, got {line!r}")
        rows.append(tuple(int(p) for p in parts))
    return rows


def run_simulation(here):
    """Compile and run the testbench with Icarus Verilog."""
    cmds = [["iverilog", "-g2012", "-o", "cordic.vvp", "tb.v", "cordic_rotation.v"],
            ["vvp", "cordic.vvp"]]
    for cmd in cmds:
        r = subprocess.run(cmd, cwd=here, capture_output=True, text=True)
        if r.returncode != 0:
            print(r.stdout + r.stderr)
            sys.exit(f"[ERROR] '{' '.join(cmd)}' returned {r.returncode}")
    print("[info] simulation finished, checking rtl_results.txt")


# ----------------------------------------------------------------------------
# Checks
# ----------------------------------------------------------------------------
def check_tables():
    ok = True
    for i, v in enumerate(ATAN_LUT):
        ideal = math.atan(2.0 ** -i) * 2 ** FRAC
        if abs(v - ideal) > 0.501:                  # rounding to the nearest LSB (entry 15 is exactly .5)
            print(f"[FAIL] LUT entry {i}: {v} vs ideal {ideal:.3f}")
            ok = False
    gain = 1.0
    for i in range(ITER):
        gain *= math.sqrt(1.0 + 2.0 ** (-2 * i))
    k_ideal = (1.0 / gain) * 2 ** FRAC
    if abs(K_Q14 - k_ideal) > 0.5:
        print(f"[FAIL] gain constant {K_Q14} vs ideal {k_ideal:.3f}")
        ok = False
    if ok:
        print(f"[PASS] arctan LUT within 0.5 LSB of math.atan; 1/K = {K_Q14} "
              f"(ideal {k_ideal:.2f}, gain A = {gain:.6f})")
    return ok


def check_bit_exact(rows):
    mism = 0
    for n, (x, y, t, xo, yo) in enumerate(rows):
        mx, my = cordic_model(x, y, t)
        if (mx, my) != (xo, yo):
            mism += 1
            if mism <= 10:
                print(f"[MISMATCH] vec {n}: in=({x},{y},{t}) rtl=({xo},{yo}) model=({mx},{my})")
    if mism:
        print(f"[FAIL] RTL differs from the Python model on {mism} of {len(rows)} vectors")
        return False
    print(f"[PASS] RTL == Python model, bit-exact on all {len(rows)} vectors")
    return True


def check_accuracy(rows):
    errs, worst = [], (0.0, None)
    for (x, y, t, xo, yo) in rows:
        ex, ey = float_ref(x, y, t)
        e = max(abs(xo - ex), abs(yo - ey))
        errs.append(e)
        if e > worst[0]:
            worst = (e, (x, y, t))
    mx, mean, rms = err_stats(errs)
    x, y, t = worst[1]
    print(f"       RTL vs float: max {mx:.2f} LSB ({mx * LSB:.2e}), mean {mean:.2f} LSB, rms {rms:.2f} LSB "
          f"(~{-math.log2(mx * LSB):.1f} accurate bits)")
    print(f"       worst vector: x={x / 2**FRAC:.4f} y={y / 2**FRAC:.4f} angle={math.degrees(t / 2**13):.2f} deg")
    bad = sum(1 for e in errs if e > TOL_LSB)
    if bad:
        print(f"[FAIL] {bad} of {len(errs)} vectors exceed {TOL_LSB} LSB")
        return False, errs
    print(f"[PASS] all {len(errs)} vectors within {TOL_LSB} LSB of floating point")
    return True, errs


def band_sweep(prerotate):
    """Model-only: max error per angle band for a few vectors. Returns {band: max_err}."""
    bands = [("0 - 90 deg", 0, 90), ("90 - 99.88 deg", 90, CONVERGENCE_DEG),
             ("99.88 - 180 deg", CONVERGENCE_DEG, 180), ("180 - 229 deg", 180, 229)]
    vecs = [(1.0, 0.0), (0.5, 0.5), (-1.2, 0.7), (1.4, -1.0)]
    out = {}
    for name, lo, hi in bands:
        worst = 0.0
        d = lo + 0.05
        while d < hi:
            for sgn in (1, -1):
                t = max(-32768, min(32767, round(sgn * math.radians(d) * 2 ** 13)))
                for vx, vy in vecs:
                    x, y = round(vx * 2 ** FRAC), round(vy * 2 ** FRAC)
                    mx, my = cordic_model(x, y, t, prerotate)
                    ex, ey = float_ref(x, y, t)
                    worst = max(worst, abs(mx - ex), abs(my - ey))
            d += 0.25
        out[name] = worst
    return out


def check_convergence():
    with_pre, without = band_sweep(True), band_sweep(False)
    print(f"       convergence limit = sum(arctan 2^-i) = {CONVERGENCE_DEG:.2f} deg")
    print(f"       {'angle band':<18}{'no pre-rotation':>18}{'with pre-rotation':>20}   (max err, LSB)")
    ok = True
    for band in with_pre:
        print(f"       {band:<18}{without[band]:>18.1f}{with_pre[band]:>20.1f}")
        if with_pre[band] > TOL_LSB:
            ok = False
    if ok:
        print(f"[PASS] with pre-rotation every band is within {TOL_LSB} LSB (model-only sweep)")
    else:
        print(f"[FAIL] a band exceeds {TOL_LSB} LSB even with pre-rotation")
    return ok


def make_plot(rows, errs, path):
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError:
        print("[info] matplotlib not installed, skipping plot")
        return
    angles = [i / 2.0 for i in range(-460, 461)]          # -230 .. +230 deg
    def curve(pre):
        out = []
        for d in angles:
            t = max(-32768, min(32767, round(math.radians(d) * 2 ** 13)))
            x, y = 1 << FRAC, 0
            mx, my = cordic_model(x, y, t, pre)
            ex, ey = float_ref(x, y, t)
            out.append(max(abs(mx - ex), abs(my - ey)))
        return out
    fig, (a1, a2) = plt.subplots(2, 1, figsize=(9, 7))
    a1.semilogy(angles, [max(e, 0.5) for e in curve(False)], label="without pre-rotation", color="tab:red")
    a1.semilogy(angles, [max(e, 0.5) for e in curve(True)], label="with pre-rotation", color="tab:green")
    a1.axhline(TOL_LSB, color="k", ls="--", lw=0.8, label=f"limit {TOL_LSB:g} LSB")
    for s in (-1, 1):
        a1.axvline(s * CONVERGENCE_DEG, color="gray", ls=":", lw=0.8)
    a1.set_xlabel("theta (deg), unit vector (1, 0)")
    a1.set_ylabel("max |error| (LSB, Q2.14)")
    a1.set_title("Error vs angle (dotted = +/-99.88 deg convergence limit)")
    a1.legend()
    a2.hist(errs, bins=60, color="tab:blue")
    a2.set_xlabel("max(|ex|, |ey|) per vector (LSB)")
    a2.set_ylabel("vectors")
    a2.set_title(f"RTL vs floating point, {len(errs)} vectors")
    fig.tight_layout()
    fig.savefig(path, dpi=130)
    print(f"[info] wrote {path.name}")


# ----------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description="Python co-verification for the Day 044 CORDIC")
    ap.add_argument("--run", action="store_true", help="compile and simulate with Icarus first")
    ap.add_argument("--plot", action="store_true", help="write cordic_accuracy.png")
    ap.add_argument("--results", default="rtl_results.txt", help="log written by tb.v")
    a = ap.parse_args()

    here = Path(__file__).resolve().parent
    if a.run:
        run_simulation(here)
    res = here / a.results
    if not res.exists():
        print(f"[ERROR] {res.name} not found - run the testbench first (or use --run)")
        return 1
    rows = load_results(res)
    if not rows:
        print(f"[ERROR] {res.name} is empty")
        return 1

    print("=" * 72)
    print("PYTHON CO-VERIFICATION: CORDIC rotation (Q2.14 data, Q3.13 angle)")
    print("=" * 72)
    ok = check_tables()
    ok &= check_bit_exact(rows)
    acc_ok, errs = check_accuracy(rows)
    ok &= acc_ok
    ok &= check_convergence()
    if a.plot:
        make_plot(rows, errs, here / "cordic_accuracy.png")
    print("=" * 72)
    print("[PASS] ALL PYTHON CHECKS PASSED" if ok else "[FAIL] one or more Python checks did not pass")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())