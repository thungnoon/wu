#!/bin/bash
set -e

echo "🚀 开始注入 ImmortalWrt 25.12 优化补丁（修复 APK 与版本描述）"

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
# 5. 修改固件版本描述（已修正：严禁修改 VERSION_REPO）
# ==================================================
COMPILE_DATE=$(TZ='Asia/Shanghai' date +%Y.%m.%d)
CUSTOM_VERSION="OpenWrt （${COMPILE_DATE} compiled by thungnoon)"
CUSTOM_REVISION="${COMPILE_DATE} compiled by thungnoon"

if [ -f "include/version.mk" ]; then
    sed --follow-symlinks -i -E "s,VERSION_DIST(:=|=).*本地?,VERSION_DIST:=OpenWrt,g" include/version.mk
    sed --follow-symlinks -i "s,ImmortalWrt,OpenWrt,g" include/version.mk
    sed --follow-symlinks -i "s,VERSION_NUMBER:=.*,VERSION_NUMBER:=${COMPILE_DATE},g" include/version.mk
    sed --follow-symlinks -i "s,VERSION_CODE:=.*,VERSION_CODE:=compiled by thungnoon,g" include/version.mk
    # 注意：这里绝不能再改 VERSION_REPO，否则会破坏 distfeeds 的 URL 生成！
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
# 7. 清理 opkg 残留，确保 apk 源由系统正常动态管理
# ==================================================
echo "正在清理 opkg 残留..."

# 物理干掉老旧的 opkg 组件
rm -rf package/system/opkg 2>/dev/null || true
rm -rf package/base-files/files/etc/opkg 2>/dev/null || true

# 移除静态源文件，交由系统根据源码和内核哈希自主生成正确的完整 URL 源
rm -f package/base-files/files/etc/apk/repositories 2>/dev/null || true

echo "✅ 全部修复与注入完成！"
