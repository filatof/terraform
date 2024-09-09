#!/bin/bash -xe
sudo apt update -y
sudo apt install nginx -y
sudo systemctl start nginx
sudo echo 1 > /proc/sys/net/ipv4/ip_forward
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo iptables -A FORWARD -i eth0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i eth0 -o eth0 -j ACCEPT

sudo cat << EOF > /etc/nginx/sites-available/infrastruct.ru
server {
    listen 80;
    server_name www.infratruct.ru;

    location / {
        proxy_pass http://192.168.1.101;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

server {
    listen 80;
    server_name monitor.infrastruct.ru;

    location / {
        proxy_pass http://192.168.1.102;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

server {
    listen 80;
    server_name grafana.infrastruct.ru;

    location / {
        proxy_pass http://192.168.1.103;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

server {
    listen 80;
    server_name ca.infrastruct.ru;

    location / {
        proxy_pass http://192.168.1.104;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/infrastruct.ru /etc/nginx/sites-enabled/
sudo sed -i -- "s/nginx/PROXY/" /var/www/html/index.nginx-debian.html
sudo systemctl reload nginx





# exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
# cd /home/ubuntu/
# git clone https://gitlab.com/entsupml/skillbox-deploy-blue-green
# curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
# echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
# sudo apt update -y && sudo apt install yarn -y
# cd /home/ubuntu/skillbox-deploy-blue-green/
# sudo apt install nodejs -y
# sudo apt install npm -y
# npm install
# # We can get the IP address of instance
# myip=`curl http://169.254.169.254/latest/meta-data/local-ipv4`
# npm install pm2 -g
# export PORT=80
# sed -i 's|Test of revert|'$myip'|g' src/App.js
# yarn start &%                                      
