install() {
if [ ! -f "/usr/bin/sing-box" ]; then
echo "安装sbox"
curl -LO https://github.com/SagerNet/sing-box/releases/download/v1.8.0/sing-box_1.8.0_linux_amd64.deb && dpkg -i sing-box_1.8.0_linux_amd64.deb
fi
}

restart() {
echo "重启sbox"
systemctl restart sing-box
}

main() {
read -p "输入host: " host

echo "host为: $host"

read -p "输入ws path（回车随机）: " path

if [ -z "$path" ]; then
   path=$(cat /dev/urandom | tr -dc 'a-z' | fold -w 5 | head -n 1)
fi
echo "path为: $path"

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
        },
        {
            "type": "vless",
            "listen": "127.0.0.1",
            "listen_port": 8001,
            "users": [
                {
                    "uuid": "$uuid"
                }
            ],
            "transport": {
                "type": "grpc",
                "service_name": "$host" 
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
套cdn：
vless://$uuid@ip.sb:80/?type=ws&encryption=none&host=$host&path=%2F$path%3Fed%3D1024
vless://$uuid@127.0.0.1:8001/?type=grpc&encryption=none&serviceName=$host
EOF

restart
}
install
main