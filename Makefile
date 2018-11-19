ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
CROSS_COMPILE=arm-linux-gnueabihf-
KERNELOPS=ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-

UBOOT=u-boot-2017.09-rc4.tar.gz

SSHKEY=outputs/adminsshkey
BROVERLAY=build/broverlay

.PHONY: uboot broverlay buildroot buildroot_config buildroot_source clean upload

all: buildinit buildroot

buildinit:
	mkdir -p build
	mkdir -p outputs

uboot: build/uboot
	$(MAKE) -C $< am335x_boneblack_defconfig
	$(MAKE) -C $< CROSS_COMPILE=$(CROSS_COMPILE)
	cp $</MLO $</u-boot.img outputs/

build/uboot: $(UBOOT)
	rm -rf $@
	mkdir -p $@
	tar xzf $< --strip 1 -C $@

$(BROVERLAY): buildinit $(SSHKEY)
	rm -rf $(BROVERLAY)
	cp -a br2overlay $(BROVERLAY)
	#setup ssh and sudo stuff for adm
	mkdir -p $(BROVERLAY)/home/adm/.ssh/
	cp $(SSHKEY).pub $(BROVERLAY)/home/adm/.ssh/authorized_keys
	mkdir -p $(BROVERLAY)/etc/sudoers.d/
	echo "adm ALL=(ALL) NOPASSWD:ALL" >> $(BROVERLAY)/etc/sudoers.d/adm
	chmod +x $(BROVERLAY)/etc/init.d/*

$(SSHKEY):
	ssh-keygen -t rsa -f $@ -P ""

buildroot: $(BROVERLAY)
	cp buildroot.config buildroot/.config
	$(MAKE) -C buildroot/ BR2_EXTERNAL=../br2external

buildroot_config:
	cp buildroot.config buildroot/.config
	$(MAKE) -C buildroot/ BR2_EXTERNAL=../br2external menuconfig
	cp buildroot/.config buildroot.config

buildroot_source:
	cp buildroot.config buildroot/.config
	$(MAKE) -C buildroot/ BR2_EXTERNAL=../br2external V=0 source

config_linux:
	cp linux.config buildroot/output/build/linux-4.14.13/.config
	$(MAKE) ARCH=arm -C buildroot/output/build/linux-4.14.13/ menuconfig
	cp buildroot/output/build/linux-4.14.13/.config linux.config

clean:
	$(MAKE) -C buildroot/ BR2_EXTERNAL=../br2external clean

upload: buildroot
	scp buildroot/output/images/bbblwgw.fit espressobin2:/srv/tftp/bbbttn.fit
