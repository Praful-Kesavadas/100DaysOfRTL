import math

# Parameters matching RTL
DEPTH = 16  # Number of phase steps (360 degrees / 16 = 22.5 deg per step)
DATA_WIDTH = 8  # Q1.7 signed 8-bit format (-128 to +127)


def generate_sine_hex():
    # Maximum positive amplitude for signed Q1.7 (127)
    max_amp = (1 << (DATA_WIDTH - 1)) - 1

    with open("sine_table.hex", "w") as f:
        print(f"Generating sine_table.hex for DEPTH={DEPTH}, DATA_WIDTH={DATA_WIDTH}...\n")

        for i in range(DEPTH):
            # Calculate angle in radians: theta = 2 * pi * i / DEPTH
            theta = 2.0 * math.pi * i / DEPTH

            # Floating-point sine amplitude scaled to signed integer range
            val = round(math.sin(theta) * max_amp)

            # Convert negative numbers to Two's Complement equivalent bit pattern
            if val < 0:
                val = (1 << DATA_WIDTH) + val

            # Format as uppercase 2-digit hex (e.g., 0 -> '00', -127 -> '81')
            hex_str = f"{val:0{DATA_WIDTH // 4}X}"

            f.write(f"{hex_str}\n")
            print(f"Addr [{i:2d}] | Angle: {i * 360.0 / DEPTH:5.1f}° | Hex: {hex_str}")

    print("\nFile 'sine_table.hex' successfully generated!")


if __name__ == "__main__":
    generate_sine_hex()