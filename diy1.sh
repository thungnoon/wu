#!/bin/bash
set -e

echo "========================================="
echo "ImmortalWrt DIY1"
echo "========================================="

# Argon
git clone --depth 1 https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon
git clone --depth 1 https://github.com/jerrykuku/luci-app-argon-config.git package/luci-app-argon-config

# Lucky
git clone --depth 1 https://github.com/gdy666/luci-app-lucky.git package/luci-app-lucky

# PassWall
git clone --depth 1 https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git package/openwrt-passwall-packages
git clone --depth 1 https://github.com/Openwrt-Passwall/openwrt-passwall.git package/luci-app-passwall

# PowerOffDevice 
git clone --depth 1 https://github.com/sirpdboy/luci-app-poweroffdevice.git package/luci-app-poweroffdevice

# ghfu
git clone --depth 1 https://github.com/smallprogram/luci-app-ghfu.git package/luci-app-ghfu

echo "========================================="
echo "DIY1 完成"
echo "========================================="
