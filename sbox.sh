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
read -p "输入ws host: " host
echo "ws host为: $wshost"

read -p "输入reality host(回车为host): " rhost
if [ -z "$rhost" ]; then
   rhost=$wshost
fi
echo "reality host为: $rhost"

read -p "输入httpupgrade path（回车随机）: " path
if [ -z "$path" ]; then
   path=$(cat /dev/urandom | tr -dc 'a-z' | fold -w 5 | head -n 1)
fi
echo "path为: $path"

echo "生成uuid"
uuid=$(sing-box generate uuid)
keys=($(sing-box generate reality-keypair))

prikey=${keys[1]}
pubkey=${keys[3]}
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
            "type": "shadowsocks",
            "tag": "ss-in",
            "listen": "127.0.0.1",
            "listen_port": 60080,
            "method": "none",
            "password": "",
            "multiplex": {
              "enabled": true
            }
        },
        {
          "type": "vless",
          "tag": "vless-in",
          "listen": "127.0.0.1",
          "listen_port": 60081,
          "users": [
            {
              "uuid": "$uuid",
              "flow": "xtls-rprx-vision"
            }
          ],
          "tls": {
            "enabled": true,
            "server_name": "$wshost",
            "alpn": [
              "h2",
              "http/1.1"
            ],
            "reality": {
              "enabled": true,
              "handshake": {
                "server": "$wshost",
                "server_port": 443
              },
              "private_key": "$prikey",
              "short_id": [
                "",
                "0123456789abcdef"
              ]
            }
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
vless://$uuid@ip.sb:80/?type=httpupgrade&encryption=none&host=$wshost&path=%2F$wshost#httpupgrade-$wshost
ss://bm9uZTo@@127.0.0.1:60080#ss-$wshost
vless://$uuid@127.0.0.1:60081/?type=tcp&encryption=none&flow=xtls-rprx-vision&sni=$rhost&fp=chrome&security=reality&pbk=$pubkey#reality-$wshost
出站json：
{
  "type": "vless",
  "tag": "$wshost",
  "server": "www.gco.gov.qa",
  "server_port": 80,
  "uuid": "$uuid",
  "transport": {
    "type": "httpupgrade",
    "path": "/$path",
    "Host": "$wshost"
  }
},
{
  "method": "none",
  "password": "",
  "server": "127.0.0.1",
  "server_port": 60080,
  "type": "shadowsocks",
  "multiplex": {
    "enabled": true,
    "max_streams": 4,
    "padding": false,
    "protocol": "smux"
  },
  "tag": "ss"
},
{
  "type": "vless",
  "server": "127.0.0.1",
  "server_port": 60081,
  "uuid": "$uuid",
  "flow": "xtls-rprx-vision",
  "tls": {
    "enabled": true,
    "insecure": false,
    "reality": {
      "enabled": true,
      "public_key": "$pubkey",
      "short_id": ""
    },
    "server_name": "$rhost",
    "utls": {
      "enabled": true,
      "fingerprint": "chrome"
    }
  },
  "tag": "reality"
}
EOF

restart
}
install
main
