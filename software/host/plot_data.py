import numpy as np
import matplotlib.pyplot as plt


FILENAME = "data.bin"

# Set this to your actual sample rate if known.
# Used only for the time axis and FFT plot.
FS = 2.5e6  # Hz


def sign_extend_12bit(x: np.ndarray) -> np.ndarray:
    """
    Convert zero-padded 12-bit two's-complement values into signed int16.

    Input:
        x: uint16 array, lower 12 bits contain signed sample

    Output:
        int16 array in range -2048..2047
    """
    x = x & 0x0FFF
    return ((x ^ 0x0800) - 0x0800).astype(np.int16)


# Read raw 16-bit little-endian words.
# Zynq/ARM is little-endian, so this is usually correct.
raw = np.fromfile(FILENAME, dtype="<u2")

if len(raw) % 4 != 0:
    print(f"Warning: file has {len(raw)} 16-bit words, not divisible by 4.")
    raw = raw[: len(raw) // 4 * 4]

# Reshape into rows:
# [I0, Q0, I1, Q1]
words = raw.reshape((-1, 4))

i0 = sign_extend_12bit(words[:, 0])
q0 = sign_extend_12bit(words[:, 1])
i1 = sign_extend_12bit(words[:, 2])
q1 = sign_extend_12bit(words[:, 3])

ch0 = i0.astype(np.float32) + 1j * q0.astype(np.float32)
ch1 = i1.astype(np.float32) + 1j * q1.astype(np.float32)

print(f"Loaded {len(ch0)} complex samples per channel")
print(f"CH0 I range: {i0.min()} to {i0.max()}")
print(f"CH0 Q range: {q0.min()} to {q0.max()}")
print(f"CH1 I range: {i1.min()} to {i1.max()}")
print(f"CH1 Q range: {q1.min()} to {q1.max()}")


# ------------------------------------------------------------
# Plot time-domain I/Q
# ------------------------------------------------------------

N_PLOT = min(2000, len(ch0))
t = np.arange(N_PLOT) / FS

plt.figure()
plt.plot(t, i0[:N_PLOT], label="CH0 I")
plt.plot(t, q0[:N_PLOT], label="CH0 Q")
plt.xlabel("Time [s]")
plt.ylabel("ADC code")
plt.title("Channel 0 Time Domain")
plt.grid(True)
plt.legend()

plt.figure()
plt.plot(t, i1[:N_PLOT], label="CH1 I")
plt.plot(t, q1[:N_PLOT], label="CH1 Q")
plt.xlabel("Time [s]")
plt.ylabel("ADC code")
plt.title("Channel 1 Time Domain")
plt.grid(True)
plt.legend()


# ------------------------------------------------------------
# Plot constellation
# ------------------------------------------------------------

plt.figure()
plt.plot(ch0[:N_PLOT].real, ch0[:N_PLOT].imag, ".", markersize=2)
plt.xlabel("I")
plt.ylabel("Q")
plt.title("Channel 0 Constellation")
plt.grid(True)
plt.axis("equal")

plt.figure()
plt.plot(ch1[:N_PLOT].real, ch1[:N_PLOT].imag, ".", markersize=2)
plt.xlabel("I")
plt.ylabel("Q")
plt.title("Channel 1 Constellation")
plt.grid(True)
plt.axis("equal")


# ------------------------------------------------------------
# Plot spectrum
# ------------------------------------------------------------

def plot_spectrum(x: np.ndarray, fs: float, title: str):
    n = min(len(x), 65536)
    x = x[:n]

    # Remove DC before FFT
    x = x - np.mean(x)

    window = np.hanning(n)
    X = np.fft.fftshift(np.fft.fft(x * window))
    f = np.fft.fftshift(np.fft.fftfreq(n, d=1 / fs))

    mag_db = 20 * np.log10(np.abs(X) + 1e-12)

    plt.figure()
    plt.plot(f / 1e6, mag_db)
    plt.xlabel("Frequency [MHz]")
    plt.ylabel("Magnitude [dB]")
    plt.title(title)
    plt.grid(True)


plot_spectrum(ch0, FS, "Channel 0 Spectrum")
plot_spectrum(ch1, FS, "Channel 1 Spectrum")

plt.show()