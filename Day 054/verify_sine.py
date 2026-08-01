import math
import matplotlib.pyplot as plt

DEPTH = 16
DATA_WIDTH = 8


def verify_and_plot():
    # 1. Read Golden Table and Simulation Output Files
    try:
        with open("sine_table.hex", "r") as f:
            golden_hex = [line.strip() for line in f if line.strip()]

        with open("sim_output.hex", "r") as f:
            sim_hex = [line.strip() for line in f if line.strip()]
    except FileNotFoundError as e:
        print(f"[ERROR] File missing: {e}")
        return

    print("====================================================")
    print("   AUTOMATED PYTHON CO-SIMULATION VERIFICATION")
    print("====================================================\n")

    # 2. Bit-Exact Validation
    errors = 0
    signed_values = []

    for idx, sample_hex in enumerate(sim_hex):
        expected_hex = golden_hex[idx % DEPTH]

        # Convert hex to signed decimal (Q1.7 format)
        raw_val = int(sample_hex, 16)
        signed_val = (
            raw_val - 256 if raw_val >= 128 else raw_val
        )  # Two's complement conversion
        signed_values.append(signed_val)

        if sample_hex.upper() != expected_hex.upper():
            print(
                f"❌ [FAIL] Sample {idx:2d} | Addr: {idx % DEPTH:2d} | Got: 0x{sample_hex} | Exp: 0x{expected_hex}"
            )
            errors += 1
        else:
            print(
                f"✅ [PASS] Sample {idx:2d} | Addr: {idx % DEPTH:2d} | Hex: 0x{sample_hex} | Dec: {signed_val:4d}"
            )

    print("\n====================================================")
    if errors == 0:
        print(" 🎉 VERIFICATION PASSED: 100% BIT-EXACT MATCH!")
    else:
        print(f" ❌ VERIFICATION FAILED WITH {errors} ERROR(S)")
    print("====================================================\n")

    # 3. Plot Time-Domain Waveform
    plt.figure(figsize=(10, 4))
    plt.plot(signed_values, "ro-", linewidth=2, markersize=6, label="RTL Output")
    plt.axhline(0, color="black", linestyle="--", alpha=0.5)
    plt.title("Day 54: DDS Sine Wave Output (Python Extracted)")
    plt.xlabel("Sample Index (Clock Cycles)")
    plt.ylabel("Q1.7 Signed Amplitude (-127 to +127)")
    plt.grid(True)
    plt.legend()
    plt.savefig("sine_wave_plot.png")
    print("Plot saved as 'sine_wave_plot.png'!")


if __name__ == "__main__":
    verify_and_plot()