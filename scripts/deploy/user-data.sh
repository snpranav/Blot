#!/bin/sh
set -x
set -e

# This script assumes we start from a running, bare Amazon Linux instance
# When built it contains secrets!

# Name of the unix user responsible for Blot server
USER={{user}}
BLOT_REPO={{blot_repo}}
NVM_URL=https://raw.githubusercontent.com/creationix/nvm/v0.32.1/install.sh
LUAROCKS_URL=http://luarocks.org/releases/luarocks-2.0.13.tar.gz
REDIS_URL=http://download.redis.io/redis-stable.tar.gz
PANDOC_URL=https://github.com/jgm/pandoc/releases/download/2.9.1.1/pandoc-2.9.1.1-linux-amd64.tar.gz
OPENRESTY_URL=https://openresty.org/package/amazon/openresty.repo

mkdir -p $(dirname {{environment_file}})
cat > {{environment_file}} <<EOL
{{#env}}
{{key}}={{value}}
{{/env}}
EOL

# Updates installed packages
# yum with 'y' flag means answer 'yes' to all questions
yum -y update

# Install required packages
yum -y install git fail2ban ntp

# Create a user for Blot
id -u $USER &>/dev/null || useradd -m $USER

# Install Redis
# gcc and tcl are required to run the tests
# todo: re-enable next line to run tests (tests are slow in developing this script)
yum install -y gcc tcl
wget $REDIS_URL
tar xvzf redis-stable.tar.gz
cd redis-stable
make

# Install NGINX/Openresty
yum install -y yum-utils
yum-config-manager --add-repo $OPENRESTY_URL
yum install -y openresty

# Install Luarocks (required by auto-ssl)
wget $LUAROCKS_URL
tar -xzvf luarocks-2.0.13.tar.gz
cd luarocks-2.0.13/
./configure --prefix=/usr/local/openresty/luajit \
    --with-lua=/usr/local/openresty/luajit/ \
    --lua-suffix=jit \
    --with-lua-include=/usr/local/openresty/luajit/include/luajit-2.1
make
make install
cd ../

# Todo install this package:
/usr/local/openresty/luajit/bin/luarocks install lua-resty-auto-ssl
mkdir /etc/resty-auto-ssl


# todo: re-enable next line to run tests (tests are slow in developing this script)
# make test
cp src/redis-server {{redis.server}}
cp src/redis-cli {{redis.cli}}
cd ../

# Install node
curl -o- $NVM_URL | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install {{node.version}}
node -e "console.log('Running Node.js ' + process.version)"

# Generate SSL fallback cert for NGINX
mkdir -p $(dirname {{fallback_certificate_key}})
openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
	-subj '/CN=sni-support-required-for-valid-ssl' \
	-keyout {{fallback_certificate_key}} \
	-out {{fallback_certificate}}

# Install Pandoc
mkdir pandoc
wget $PANDOC_URL
tar xvzf pandoc-2.9.1.1-linux-amd64.tar.gz --strip-components 1 -C pandoc
cp pandoc/bin/pandoc /usr/bin

# Install Blot
git clone $BLOT_REPO {{directory}}
cd Blot
npm ci

node scripts/deploy/build

# Run redis as blot user
cp scripts/deploy/out/redis.service /etc/systemd/system/redis.service
systemctl enable redis.service
systemctl start redis.service

# Run nginx as blot user
cp scripts/deploy/out/nginx.conf {{nginx.config}}
cp scripts/deploy/out/nginx.service /etc/systemd/system/nginx.service
mkdir -p $(dirname {{log_file}})
systemctl enable nginx.service
systemctl start nginx.service

# Run nginx as blot user
cp scripts/deploy/out/blot.service /etc/systemd/system/blot.service
systemctl enable blot.service
systemctl start blot.service

# Logrotate
yum install logrotate

# Monit