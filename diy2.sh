#!/bin/bash
set -e

echo "🚀 开始注入 ImmortalWrt 25.12 稳定版优化补丁（品牌校正、APK 加速与内核底座）"

# ==================================================
# 1. 冲突插件清理
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
# 2. 安全更新 Golang（按需启用）
# ==================================================
echo "检查并更新 Golang 版本..."
if [ -d "feeds/packages/lang/golang" ]; then
    rm -rf feeds/packages/lang/golang
fi
# 提示：如果编译报错，可将 -b 分支调整为对应 25.12 兼容的分支
git clone --depth 1 -b 27.x https://github.com/sbwml/packages_lang_golang feeds/packages/lang/golang || true

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
# 4. 基础系统属性修改（恢复为 ImmortalWrt 正统标识）
# ==================================================
echo "修改系统默认配置..."
sed -i 's/192.168.1.1/192.168.5.1/g' package/base-files/files/bin/config_generate
sed -i "s/hostname='OpenWrt'/hostname='ImmortalWrt'/g" package/base-files/files/bin/config_generate
sed -i 's/^root:[^:]*:/root::/' package/base-files/files/etc/shadow

# ==================================================
# 5. 修改固件版本描述
# ==================================================
COMPILE_DATE=$(TZ='Asia/Shanghai' date +%Y.%m.%d)
CUSTOM_VERSION="ImmortalWrt 25.12 (${COMPILE_DATE} compiled by thungnoon)"
CUSTOM_REVISION="${COMPILE_DATE} compiled by thungnoon"

if [ -f "include/version.mk" ]; then
    sed --follow-symlinks -i -E "s,VERSION_DIST(:=|=).*本地?,VERSION_DIST:=ImmortalWrt,g" include/version.mk
    sed --follow-symlinks -i "s,VERSION_NUMBER:=.*,VERSION_NUMBER:=${COMPILE_DATE},g" include/version.mk
    sed --follow-symlinks -i "s,VERSION_CODE:=.*,VERSION_CODE:=compiled by thungnoon,g" include/version.mk
    sed --follow-symlinks -i "s,VERSION_REVISION:=.*,VERSION_REVISION:=${CUSTOM_REVISION},g" include/version.mk
fi

if [ -d "package/base-files/files/etc" ]; then
    if [ -f "package/base-files/files/etc/openwrt_release" ]; then
        sed --follow-symlinks -i "s,DISTRIB_DESCRIPTION='.*',DISTRIB_DESCRIPTION='${CUSTOM_VERSION}',g" package/base-files/files/etc/openwrt_release
        sed --follow-symlinks -i "s,DISTRIB_ID='.*',DISTRIB_ID='ImmortalWrt',g" package/base-files/files/etc/openwrt_release
        sed --follow-symlinks -i "s,DISTRIB_REVISION='.*',DISTRIB_REVISION='${CUSTOM_REVISION}',g" package/base-files/files/etc/openwrt_release
    fi
    echo "${CUSTOM_REVISION}" > "package/base-files/files/etc/openwrt_version"
fi

# 抹掉残留的 OpenWrt 文本并更正为 ImmortalWrt
find feeds/luci/modules/luci-base/ -type f -exec sed -i 's/OpenWrt/ImmortalWrt/g' {} + 2>/dev/null || true

# ==================================================
# 6. 修改默认主题
# ==================================================
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile || true

# ==================================================
# 7. 清理 opkg 残留与规范 apk 验签依赖
# ==================================================
echo "清理 opkg 残留并规范 apk 验证依赖..."
rm -rf package/system/opkg 2>/dev/null || true
rm -rf package/base-files/files/etc/opkg 2>/dev/null || true
rm -f package/base-files/files/etc/apk/repositories 2>/dev/null || true

# ==================================================
# 8. 智能动态源替换与坏源剔除（镜像加速 + 剔除失效 video 源）
# ==================================================
echo "配置 apk 智能动态镜像加速并清理无效源..."
mkdir -p package/base-files/files/etc/apk/repositories.d/

# 8.1 开机首刷自适应替换（捕获系统生成的源，转镜像并彻底剔除 video 坏源）
INIT_SCRIPT="package/base-files/files/etc/uci-defaults/99-fix-apk-vsean-mirror"
cat > "$INIT_SCRIPT" << 'EOF'
#!/bin/sh
for file in /etc/apk/repositories.d/*.list /etc/apk/repositories; do
    if [ -f "$file" ]; then
        sed -i 's#https://downloads.immortalwrt.org#https://mirrors.vsean.net/openwrt#g' "$file"
        sed -i '/video/d' "$file"
    fi
done
exit 0
EOF
chmod +x "$INIT_SCRIPT"

# 8.2 自动清理锁文件，避免后台锁卡死 apk update
LOCK_CLEAN_SCRIPT="package/base-files/files/etc/uci-defaults/98-clean-apk-locks"
cat > "$LOCK_CLEAN_SCRIPT" << 'EOF'
#!/bin/sh
rm -f /var/lock/apk* /etc/apk/lock 2>/dev/null
exit 0
EOF
chmod +x "$LOCK_CLEAN_SCRIPT"

echo "✅ diy2 优化补丁注入完成！"
