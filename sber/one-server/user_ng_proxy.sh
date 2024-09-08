#!/bin/bash -xe
sudo apt update -y
sudo apt install nginx -y
sudo systemctl start nginx
sudo cat << EOF > /etc/nginx/sites-available/default
server {
    listen 80;
    server_name www.infra.ru;

    location / {
        proxy_pass http://192.168.1.216:80;  # IP-адрес или хост-сервис www.infra.ru
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

server {
    listen 80;
    server_name monitor.infra.ru;

    location / {
        proxy_pass http://192.168.1.191:80;  # IP-адрес или хост-сервис monitor.infra.ru
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

server {
    listen 80;
    server_name grafana.infra.ru;

    location / {
        proxy_pass http://192.168.1.184:80;  # IP-адрес или хост-сервис grafana.infra.ru
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

server {
    listen 80;
    server_name ca.infra.ru;

    location / {
        proxy_pass http://192.168.1.123:80;  # IP-адрес или хост-сервис ca.infra.ru
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF


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
