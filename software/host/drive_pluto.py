import iio

ctx = iio.Context("ip:192.168.1.2")
phy = ctx.find_device("ad9361-phy")

if phy is None:
    raise RuntimeError("ad9361-phy not found")

rx_lo = phy.find_channel("altvoltage0", True)
tx_lo = phy.find_channel("altvoltage1", True)
rx0 = phy.find_channel("voltage0", False)

rx_lo.attrs["frequency"].value = str(int(2.4e9))
tx_lo.attrs["frequency"].value = str(int(2.4e9))

rx0.attrs["sampling_frequency"].value = str(int(30720000))
rx0.attrs["rf_bandwidth"].value = str(int(2.0e6))
rx0.attrs["gain_control_mode"].value = "manual"
rx0.attrs["hardwaregain"].value = "30"

phy.attrs["ensm_mode"].value = "fdd"

print("Configured AD9361 RX path")
print("ENSM:", phy.attrs["ensm_mode"].value)
print("RX LO:", rx_lo.attrs["frequency"].value)
print("Sample rate:", rx0.attrs["sampling_frequency"].value)