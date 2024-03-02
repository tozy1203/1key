install() {
if [ ! -f "/usr/bin/sing-box" ]; then
echo "安装sbox"
curl -s https://github.com/SagerNet/sing-box/releases/download/v1.8.0/sing-box_1.8.0_linux_amd64.deb|dpkg -i
fi
}

restart() {
echo "重启sbox"
systemctl restart sing-box
}

main() {
read -p "输入host（回车获取ip）: " ip

if [ -z "$ip" ]; then
   ip=$(curl https://api.myip.la)
    echo "外网ip为: $ip"
else
    echo "输入的内容为: $ip"
fi

read -p "输入ws path（回车随机）: " path

if [ -z "$path" ]; then
   path=$(cat /dev/urandom | tr -dc 'a-z' | fold -w 5 | head -n 1)
    echo "生成的5位随机字符串为: $path"
else
    echo "输入的内容为: $path"
fi

echo "生成uuid"
uuid=$(sing-box generate uuid)
cat > /etc/sing-box/config.json <<EOF
 {
    "inbounds": [
        {
            "type": "vless",
            "listen": "::",
            "listen_port": 8080,
            "users": [
                {
                    "uuid": "$uuid",
                    "flow": ""
                }
            ],
            "transport": {
                "type": "ws",
                "path": "/$path",
                "max_early_data": 2048,
                "early_data_header_name": "Sec-WebSocket-Protocol"
            }
        }
    ],
    "outbounds": [
        {
            "type": "direct"
        }
    ]
}
EOF
cat <<EOF
vless://$uuid@$ip:8080/?type=ws&encryption=none&host=$ip&path=%2F$path%3Fed%3D2048
EOF

restart
}
install
main
