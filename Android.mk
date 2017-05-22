#Android makefile to build kernel as a part of Android Build
ifeq ($(OBB_PRODUCT_NAME),)
export OBB_PRODUCT_NAME := $(HISI_TARGET_PRODUCT)
endif

kernel_path := kernel/huawei/shine/

ifeq ($(OBB_PRINT_CMD), true)
KERNEL_OUT := vendor/hisi/build/delivery/$(OBB_PRODUCT_NAME)/obj/android
else
KERNEL_OUT := $(TARGET_OUT_INTERMEDIATES)/KERNEL_OBJ
endif
KERNEL_CONFIG := $(KERNEL_OUT)/.config

ifeq ($(TARGET_ARM_TYPE), arm64)
KERNEL_ARCH_PREFIX := arm64
CROSS_COMPILE_PREFIX=aarch64-linux-android-
TARGET_PREBUILT_KERNEL := $(KERNEL_OUT)/arch/arm64/boot/Image
else
KERNEL_ARCH_PREFIX := arm
CROSS_COMPILE_PREFIX=arm-linux-gnueabihf-
TARGET_PREBUILT_KERNEL := $(KERNEL_OUT)/arch/arm/boot/zImage
endif

COMMON_HEAD := $(shell pwd)/$(kernel_path)/drivers/
COMMON_HEAD += $(shell pwd)/$(kernel_path)/mm/
COMMON_HEAD += $(shell pwd)/$(kernel_path)/include/linux/hisi/
COMMON_HEAD += $(shell pwd)/$(kernel_path)/include/linux/hisi/hi3xxx
COMMON_HEAD += $(shell pwd)/$(kernel_path)/include/linux/hisi/pm
COMMON_HEAD += $(shell pwd)/external/efipartition	

ifeq ($(HISI_TARGET_PRODUCT), hi6210sft)
COMMON_HEAD += $(shell pwd)/vendor/hisi/ap/platform/hi6210sft/
endif

ifneq ($(COMMON_HEAD),)
BALONG_INC := $(patsubst %,-I%,$(COMMON_HEAD))
else
BALONG_INC := 
endif
 
export BALONG_INC

KERNEL_N_TARGET ?= vmlinux
UT_EXTRA_CONFIG ?= 

KERNEL_ARCH_ARM_CONFIGS := $(shell pwd)/$(kernel_path)/arch/$(KERNEL_ARCH_PREFIX)/configs
KERNEL_GEN_CONFIG_FILE := shine_defconfig
KERNEL_GEN_CONFIG_PATH := $(KERNEL_ARCH_ARM_CONFIGS)/$(KERNEL_GEN_CONFIG_FILE)

KERNEL_COMMON_DEFCONFIG := $(KERNEL_ARCH_ARM_CONFIGS)/$(KERNEL_DEFCONFIG)

ifeq ($(strip $(TARGET_PRODUCT)), hisi_pilot)
KERNEL_PRODUCT_CONFIGS := $(shell pwd)/device/hisi/customize/config/${TARGET_ARM_TYPE}/hi6220/${TARGET_PRODUCT}/product_config/kernel_config
endif

define DTS_PARSE_CONFIG
@echo generating dtsi files, please wait for minutes!
@cd device/hisi/customize/build_script; ./auto_dts_gen.sh > $(ANDROID_BUILD_TOP)/auto_dts_gen.log 2>&1
endef


GENERATE_DTB := $(KERNEL_OUT)/.timestamp
$(GENERATE_DTB):$(DEPENDENCY_FILELIST) $(KERNEL_CONFIG)
	$(DTS_PARSE_CONFIG)
	make -C $(kernel_path) O=../$(KERNEL_OUT) ARCH=$(KERNEL_ARCH_PREFIX) CROSS_COMPILE=$(CROSS_COMPILE_PREFIX) dtbs;touch $@

$(KERNEL_GEN_CONFIG_PATH): $(KERNEL_COMMON_DEFCONFIG) $(wildcard $(KERNEL_PRODUCT_CONFIGS)/*)
	$(hide) echo GENERATING $(KERNEL_GEN_CONFIG_FILE) ...
	$(APPEND_MODEM_DEFCONFIG)

ifeq ($(OBB_PRINT_CMD), true)
$(KERNEL_CONFIG): MAKEFLAGS :=
$(KERNEL_CONFIG):
	mkdir -p $(KERNEL_OUT)
	$(MAKE) -C $(kernel_path) O=../$(KERNEL_OUT) ARCH=$(KERNEL_ARCH_PREFIX) CROSS_COMPILE=$(CROSS_COMPILE_PREFIX) hisi_$(TARGET_PRODUCT)_defconfig
else
ifeq ($(HISI_PILOT_LIBS), true)
$(KERNEL_CONFIG): $(KERNEL_GEN_CONFIG_PATH) $(HI3XXX_MODEM_DIR) $(HI6XXX_MODEM_DRV_DIR) HISI_PILOT_PREBUILD
else
$(KERNEL_CONFIG): $(KERNEL_GEN_CONFIG_PATH) $(HI3XXX_MODEM_DIR) $(HI6XXX_MODEM_DRV_DIR)
endif
	mkdir -p $(KERNEL_OUT)
	$(MAKE) -C $(kernel_path) O=../$(KERNEL_OUT) ARCH=$(KERNEL_ARCH_PREFIX) CROSS_COMPILE=$(CROSS_COMPILE_PREFIX) $(KERNEL_GEN_CONFIG_FILE)
endif

$(TARGET_PREBUILT_KERNEL): FORCE $(KERNEL_CONFIG)
ifeq ($(OBB_PRINT_CMD), true)
	$(hide) $(MAKE) -C $(kernel_path) O=../$(KERNEL_OUT) ARCH=$(KERNEL_ARCH_PREFIX) CROSS_COMPILE=$(CROSS_COMPILE_PREFIX) $(KERNEL_N_TARGET) $(UT_EXTRA_CONFIG)
	touch $(TARGET_PREBUILT_KERNEL)
else
	$(hide) $(MAKE) -C $(kernel_path) O=../$(KERNEL_OUT) ARCH=$(KERNEL_ARCH_PREFIX) CROSS_COMPILE=$(CROSS_COMPILE_PREFIX)
	touch $(TARGET_PREBUILT_KERNEL)
endif

kernelconfig: $(KERNEL_GEN_CONFIG_PATH)
	mkdir -p $(KERNEL_OUT)
	$(MAKE) -C $(kernel_path) O=../$(KERNEL_OUT) ARCH=$(KERNEL_ARCH_PREFIX) CROSS_COMPILE=$(CROSS_COMPILE_PREFIX) $(KERNEL_GEN_CONFIG_FILE) menuconfig

zImage Image:$(TARGET_PREBUILT_KERNEL)
	@mkdir -p $(dir $(INSTALLED_KERNEL_TARGET))
	@cp -fp $(TARGET_PREBUILT_KERNEL) $(INSTALLED_KERNEL_TARGET)
pclint_kernel: $(KERNEL_CONFIG)
	$(hide) $(MAKE) -C $(kernel_path) O=../$(KERNEL_OUT) ARCH=$(KERNEL_ARCH_PREFIX) CROSS_COMPILE=$(CROSS_COMPILE_PREFIX) pc_lint_all
