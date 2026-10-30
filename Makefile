# SPDX-License-Identifier: GPL-2.0-only
obj-m += c778_lt6911uxe.o
KDIR ?= /lib/modules/$(shell uname -r)/build
DTC ?= dtc

.PHONY: all modules overlay clean
all: modules overlay

modules:
	$(MAKE) -C $(KDIR) M=$(CURDIR) modules

overlay: overlays/c778-csi0.dtbo

overlays/c778-csi0.dtbo: overlays/c778-csi0.dts
	$(DTC) -@ -I dts -O dtb -o $@ $<

clean:
	$(MAKE) -C $(KDIR) M=$(CURDIR) clean
	rm -f overlays/c778-csi0.dtbo
