# Overlays for the BeagleBone platform
dtbo-$(CONFIG_ARCH_OMAP2PLUS) += node-B01.dtbo

targets += dtbs dtbs_install
targets += $(dtbo-y)

always-y	:= $(dtbo-y)
clean-files	:= *.dtbo
