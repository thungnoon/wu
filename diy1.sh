#!/bin/bash
set -e

echo "========================================="
echo "ImmortalWrt DIY1"
echo "========================================="

# 移除 IP 电话源（用不到，省下 feeds 拉取时间）
sed -i '/telephony/d' feeds.conf.default

# kenzok8/small —— 提供 daed 本体（自带 init.d/daed + /etc/config/daed）
echo 'src-git small https://github.com/kenzok8/small' >> feeds.conf.default

# packages / luci feed 换成 jjm2473 fork（iStoreOS 25.12 官方同款）
sed -i 's#^src-git packages .*#src-git packages https://github.com/jjm2473/packages.git;istoreos-25.12#' feeds.conf.default
sed -i 's#^src-git luci .*#src-git luci https://github.com/jjm2473/luci.git;istoreos-25.12#' feeds.conf.default

# iStore 全家桶（linkease 官方三件套，x86_64 完整支持）
echo 'src-git istore https://github.com/linkease/istore;main' >> feeds.conf.default
echo 'src-git nas https://github.com/linkease/nas-packages.git;master' >> feeds.conf.default
echo 'src-git nas_luci https://github.com/linkease/nas-packages-luci.git;main' >> feeds.conf.default

echo "===== 当前 feeds.conf.default ====="
cat feeds.conf.default

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

# openclash
git clone --depth 1 https://github.com/vernesong/OpenClash.git package/luci-app-openclash

# homeproxy
git clone --depth 1 https://github.com/sbwml/homeproxy.git package/luci-app-homeproxy

# OpenWrt-nikki
git clone --depth 1 https://github.com/nikkinikki-org/OpenWrt-nikki.git package/luci-app-nikki

# partexp
git clone --depth 1 https://github.com/sirpdboy/luci-app-partexp.git package/luci-app-partexp

# luci-app-daede
# git clone --depth 1 https://github.com/kenzok8/openwrt-daede.git package/luci-app-daede

echo "========================================="
echo "DIY1 完成"
echo "========================================="
