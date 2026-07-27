
import argparse
import numpy as np


# Sample rate: 30.72 MHz
FS_HZ = 30_720_000

# Output scaling
INT16_MAX = 32767
OUTPUT_SCALE = 0.9 * 0.062   # keep some headroom to avoid clipping, scale it by 0.062 because the dac is 12 bits, not 16


def db_to_power(power_db: float) -> float:
    """Convert dB power to linear power."""
    return 10 ** (power_db / 10.0)


def generate_sine(num_samples: int, freq_hz: float, power_db: float, phase_rad: float = 0.0) -> np.ndarray:
    """
    Generate complex sine wave.

    Power definition:
        average complex power = mean(abs(x)^2)
        power_linear = 10^(power_db/10)
    """
    n = np.arange(num_samples)
    power_linear = db_to_power(power_db)
    amplitude = np.sqrt(power_linear)

    x = amplitude * np.exp(1j * (2 * np.pi * freq_hz * n / FS_HZ + phase_rad))
    return x.astype(np.complex64)


def generate_gaussian_noise(num_samples: int, power_db: float) -> np.ndarray:
    """
    Generate complex Gaussian noise.

    Complex noise power:
        mean(abs(noise)^2) = power_linear

    Real and imaginary parts each get half the total power.
    """
    power_linear = db_to_power(power_db)
    sigma = np.sqrt(power_linear / 2.0)

    noise = sigma * (np.random.randn(num_samples) + 1j * np.random.randn(num_samples))
    return noise.astype(np.complex64)


def scale_to_int16(ch1: np.ndarray, ch2: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """
    Scale both channels together so neither clips int16.
    """
    max_val = max(
        np.max(np.abs(ch1.real)),
        np.max(np.abs(ch1.imag)),
        np.max(np.abs(ch2.real)),
        np.max(np.abs(ch2.imag)),
    )

    if max_val == 0:
        scale = 1.0
    else:
        scale = OUTPUT_SCALE * INT16_MAX / max_val

    ch1_i16 = np.round(ch1.real * scale).astype(np.int16)
    ch1_q16 = np.round(ch1.imag * scale).astype(np.int16)
    ch2_i16 = np.round(ch2.real * scale).astype(np.int16)
    ch2_q16 = np.round(ch2.imag * scale).astype(np.int16)

    return (
        ch1_i16,
        ch1_q16,
        ch2_i16,
        ch2_q16,
    )


def pack_data(ch1: np.ndarray, ch2: np.ndarray) -> np.ndarray:
    """
    Pack two complex channels into int16 interleaved format:

        CH1 real
        CH1 imag
        CH2 real
        CH2 imag
    """
    if len(ch1) != len(ch2):
        raise ValueError("ch1 and ch2 must have the same length")

    ch1_i, ch1_q, ch2_i, ch2_q = scale_to_int16(ch1, ch2)

    packed = np.empty(len(ch1) * 4, dtype="<i2")
    packed[0::4] = ch1_i
    packed[1::4] = ch1_q
    packed[2::4] = ch2_i
    packed[3::4] = ch2_q

    return packed


def write_binary(filename: str, ch1: np.ndarray, ch2: np.ndarray) -> None:
    packed = pack_data(ch1, ch2)
    packed.tofile(filename)
    print(f"Wrote {filename}")
    print(f"Samples per channel: {len(ch1)}")
    print(f"Total int16 words: {len(packed)}")
    print(f"Total bytes: {packed.nbytes}")


def parse_args():
    parser = argparse.ArgumentParser(
        description="Generate 2-channel complex int16 test signal for AD9361/FPGA TX"
    )

    parser.add_argument(
        "num_samples",
        type=int,
        help="Number of complex samples per channel",
    )

    parser.add_argument(
        "output_file",
        help="Output binary filename",
    )

    return parser.parse_args()


def main():
    args = parse_args()

    n = args.num_samples

    # Channel 1: three tones + noise
    ch1 = (
        generate_sine(n, 1e6, 20)
        + generate_sine(n, 5e6, 30)
        + generate_sine(n, 12e6, 40)
        + generate_gaussian_noise(n, 10)
    )

    # Channel 2: same frequencies/powers, different phases
    ch2 = (
        generate_sine(n, 1e6, 20, phase_rad=np.pi / 4)
        + generate_sine(n, 5e6, 30, phase_rad=np.pi / 2)
        + generate_sine(n, 12e6, 40, phase_rad=np.pi)
        + generate_gaussian_noise(n, 10)
    )

    write_binary(args.output_file, ch1, ch2)


if __name__ == "__main__":
    main()