#!/bin/bash
set -e

echo "🚀 开始注入 ImmortalWrt 25.12 优化补丁（修复 APK 与 Golang）"

# ==================================================
# 1. 调整冲突插件清理（严禁直接 rm -rf 整个 feeds 语言目录）
# ==================================================
echo "清理冲突插件..."
rm -rf feeds/luci/themes/luci-theme-argon
rm -rf feeds/luci/applications/luci-app-argon-config
rm -rf feeds/luci/applications/luci-app-lucky
rm -rf feeds/luci/applications/luci-app-openclash
rm -rf feeds/luci/applications/luci-app-homeproxy
rm -rf feeds/packages/net/lucky
rm -rf feeds/packages/utils/lucky
rm -rf feeds/luci/applications/luci-app-passwall
rm -rf feeds/packages/net/xray-core
rm -rf feeds/packages/net/sing-box
rm -rf feeds/packages/net/hysteria
rm -rf feeds/packages/net/tuic-client

# ==================================================
# 2. 安全更新 Golang（不破坏 apk 依赖链）
# ==================================================
echo "更新 Golang 版本..."
if [ -d "feeds/packages/lang/golang" ]; then
    rm -rf feeds/packages/lang/golang
fi
git clone --depth 1 -b 27.x https://github.com/sbwml/packages_lang_golang feeds/packages/lang/golang

# ==================================================
# 3. 自适应网口配置
# ==================================================
BOARD_D_PATH="target/linux/x86/base-files/etc/board.d"
mkdir -p "$BOARD_D_PATH"

cat > "$BOARD_D_PATH/02_network" << "EOF"
#!/bin/sh
. /lib/functions.sh
. /lib/functions/uci-defaults.sh

board_config_update

ALL_ETH=$(ls /sys/class/net/ | grep -E '^eth[0-9]+$' | grep -v '@' | sort -V)
COUNT=$(echo "$ALL_ETH" | wc -l)

if echo "$ALL_ETH" | grep -qwx "eth1"; then
    WAN_PORT="eth1"
    LAN_PORTS=$(echo "$ALL_ETH" | grep -vwx "eth1" | tr '\n' ' ' | sed 's/ $//')
    if [ -n "$LAN_PORTS" ]; then
        ucidef_set_interfaces_lan_wan "$LAN_PORTS" "$WAN_PORT"
    else
        ucidef_set_interface_lan "$WAN_PORT"
    fi
else
    if [ "$COUNT" -ge 2 ]; then
        WAN_PORT=$(echo "$ALL_ETH" | head -n1)
        LAN_PORTS=$(echo "$ALL_ETH" | tail -n +2 | tr '\n' ' ' | sed 's/ $//')
        ucidef_set_interfaces_lan_wan "$LAN_PORTS" "$WAN_PORT"
    elif [ "$COUNT" -eq 1 ]; then
        ucidef_set_interface_lan "$ALL_ETH"
    fi
fi

board_config_flush
exit 0
EOF

chmod +x "$BOARD_D_PATH/02_network"

# ==================================================
# 4. 基础系统属性修改
# ==================================================
echo "修改系统默认配置..."
sed -i 's/192.168.1.1/192.168.5.1/g' package/base-files/files/bin/config_generate
sed -i "s/hostname='ImmortalWrt'/hostname='OpenWrt'/g" package/base-files/files/bin/config_generate
sed -i 's/^root:[^:]*:/root::/' package/base-files/files/etc/shadow

# ==================================================
# 5. 修改固件版本描述
# ==================================================
COMPILE_DATE=$(TZ='Asia/Shanghai' date +%Y.%m.%d)
CUSTOM_VERSION="OpenWrt （${COMPILE_DATE} compiled by thungnoon)"
CUSTOM_REVISION="${COMPILE_DATE} compiled by thungnoon"

if [ -f "include/version.mk" ]; then
    sed --follow-symlinks -i -E "s,VERSION_DIST(:=|=).*本地?,VERSION_DIST:=OpenWrt,g" include/version.mk
    sed --follow-symlinks -i "s,ImmortalWrt,OpenWrt,g" include/version.mk
    sed --follow-symlinks -i "s,VERSION_NUMBER:=.*,VERSION_NUMBER:=${COMPILE_DATE},g" include/version.mk
    sed --follow-symlinks -i "s,VERSION_CODE:=.*,VERSION_CODE:=compiled by thungnoon,g" include/version.mk
    sed --follow-symlinks -i "s,VERSION_REPO:=.*,VERSION_REPO:=OpenWrt,g" include/version.mk
    sed --follow-symlinks -i "s,VERSION_REVISION:=.*,VERSION_REVISION:=${CUSTOM_REVISION},g" include/version.mk
fi

if [ -d "package/base-files/files/etc" ]; then
    if [ -f "package/base-files/files/etc/openwrt_release" ]; then
        sed --follow-symlinks -i "s,DISTRIB_DESCRIPTION='.*',DISTRIB_DESCRIPTION='${CUSTOM_VERSION}',g" package/base-files/files/etc/openwrt_release
        sed --follow-symlinks -i "s,DISTRIB_ID='.*',DISTRIB_ID='OpenWrt',g" package/base-files/files/etc/openwrt_release
        sed --follow-symlinks -i "s,DISTRIB_REVISION='.*',DISTRIB_REVISION='${CUSTOM_REVISION}',g" package/base-files/files/etc/openwrt_release
    fi
    echo "${CUSTOM_REVISION}" > "package/base-files/files/etc/openwrt_version"
fi

# ==================================================
# 6. 修改默认主题
# ==================================================
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile || true

# ==================================================
# 7. 预置正确的 APK 软件源与深度清理 opkg 残留
# ==================================================
echo "正在注入经过实测验证的 25.12 APK 软件源配置并清理 opkg..."

# 物理干掉 opkg 构建目标
rm -rf package/system/opkg 2>/dev/null || true
rm -rf package/base-files/files/etc/opkg 2>/dev/null || true

# 写入带有 packages.adb 结尾以及精确路径的实测标准 repositories 文件
mkdir -p package/base-files/files/etc/apk
cat > package/base-files/files/etc/apk/repositories << 'EOF'
https://downloads.immortalwrt.org/releases/25.12-SNAPSHOT/targets/x86/64/packages/packages.adb
https://downloads.immortalwrt.org/releases/25.12-SNAPSHOT/packages/x86_64/base/packages.adb
https://downloads.immortalwrt.org/releases/25.12-SNAPSHOT/targets/x86/64/kmods/6.12.103-1-0413601b1c3f0490e17f340fe09229ea/packages.adb
https://downloads.immortalwrt.org/releases/25.12-SNAPSHOT/packages/x86_64/luci/packages.adb
https://downloads.immortalwrt.org/releases/25.12-SNAPSHOT/packages/x86_64/packages/packages.adb
https://downloads.immortalwrt.org/releases/25.12-SNAPSHOT/packages/x86_64/routing/packages.adb
https://downloads.immortalwrt.org/releases/25.12-SNAPSHOT/packages/x86_64/telephony/packages.adb
EOF

echo "✅ 全部修复与注入完成！"
