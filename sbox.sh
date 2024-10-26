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

read -p "输入httpupgrade path（回车随机）: " path

if [ -z "$path" ]; then
   path=$(cat /dev/urandom | tr -dc 'a-z' | fold -w 5 | head -n 1)
fi
echo "path为: $path"

echo "生成uuid"
uuid=$(sing-box generate uuid)
output=$(sing-box generate reality-keypair)

# 使用awk提取PrivateKey
prikey=$(echo "$output" | awk '/PrivateKey:/ {print $2}')

# 使用awk提取PublicKey
pubkey=$(echo "$output" | awk '/PublicKey:/ {print $2}')
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
                "type": "httpupgrade",
                "path": "/$path"
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
                "service_name": "$path" 
            }
        },
        {
            "type": "vless",
            "listen": "127.0.0.1",
            "listen_port": 8002,
            "users": [
                {
                    "uuid": "$uuid"
                }
            ],
            "tls": {
                "enabled": true,
                "server_name": "$host",
                "reality": {
                    "enabled": true,
                    "handshake": {
                        "server": "127.0.0.1",
                        "server_port": 443
                    },
                    "private_key": "$prikey",
                    "short_id": [
                        ""
                    ]
                }
            },
            "transport": {
                "type": "http",
                "host": []
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
vless://$uuid@ip.sb:80/?type=httpupgrade&encryption=none&host=$host&path=%2F$path%3Fed%3D1024#httpupgrade-$host
vless://$uuid@127.0.0.1:8001/?type=grpc&encryption=none&serviceName=$path#grpc-$host
vless://$uuid@127.0.0.1:8002/?type=http&encryption=none&sni=$host&fp=chrome&security=reality&pbk=$pubkey#x-$host
EOF

restart
}
install
main
