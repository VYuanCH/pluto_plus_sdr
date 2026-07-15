sudo rm -rf /media/yuan/rootfs/*
sudo tar -xzf images/linux/rootfs.tar.gz -C /media/yuan/rootfs
sudo cp images/linux/image.ub /media/yuan/BOOT
sudo cp images/linux/boot.scr /media/yuan/BOOT
sudo cp images/linux/BOOT.BIN /media/yuan/BOOT
sync
