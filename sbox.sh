install() {
if [ ! -f "/usr/bin/sing-box" ]; then
echo "安装sbox"
curl -LO https://github.com/SagerNet/sing-box/releases/download/v1.9.7/sing-box_1.9.7_linux_amd64.deb && dpkg -i sing-box_1.9.7_linux_amd64.deb
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

read -p "输入cloudflare api token: " token
echo "cloudflare api token为: $token"

echo "生成uuid"
uuid=$(sing-box generate uuid)

cat > /etc/sing-box/config.json <<EOF
{
	"inbounds": [{
		"type": "vless",
		"listen": "::",
		"listen_port": 8080,
		"users": [{
			"uuid": "$uuid",
			"flow": ""
		}],
		"transport": {
			"type": "httpupgrade",
			"path": "/$path"
		},
		"multiplex": {
			"enabled": true
		}
	},
	{
		"type": "vless",
		"tag": "vless-in",
		"listen": "127.0.0.1",
		"listen_port": 60081,
		"users": [{
			"uuid": "$uuid",
			"flow": "xtls-rprx-vision"
		}],
		"tls": {
			"enabled": true,
			"server_name": "$host",
			"acme": {
				"domain": ["$host"],
				"data_directory": "certs",
				"default_server_name": "$host",
				"email": "admin@$host",
				"dns01_challenge": {
					"provider": "cloudflare",
					"api_token": "$token"
				}
			}
		}
	}],
	"outbounds": [{
		"type": "direct"
	}]
}
EOF
cat <<EOF
套cdn：
vless://$uuid@ip.sb:80/?type=httpupgrade&encryption=none&host=$host&path=%2F$host#httpupgrade-$host
vless://$uuid@127.0.0.1:60081/?type=tcp&encryption=none&flow=xtls-rprx-vision&sni=$host&fp=chrome&security=tls#xtls-$host
出站json：
{
	"type": "vless",
	"tag": "$host",
	"server": "www.gco.gov.qa",
	"server_port": 80,
	"uuid": "$uuid",
	"transport": {
		"type": "httpupgrade",
		"path": "/$path",
		"Host": "$host"
	}
},
{
	"type": "vless",
	"server": "127.0.0.1",
	"server_port": 60081,
	"uuid": "$uuid",
	"flow": "xtls-rprx-vision",
	"tls": {
		"enabled": true,
		"server_name": "$host",
		"utls": {
			"enabled": true,
			"fingerprint": "chrome"
		}
	},
	"multiplex": {
		"enabled": true,
		"max_connections": 1,
		"padding": false,
		"protocol": "smux"
	},
	"tag": "xtls"
}
EOF

restart
}
install
main
