#!/bin/bash

if [[ $EUID -ne 0 ]]; then
	echo -e "Sorry, you need to run this as root"
	exit 1
fi

# Versions
NGINX_MAINLINE_VERSION="1.25.3"
NGINX_STABLE_VERSION="1.24.0"
LIBRESSL_VERSION="3.8.2"
OPENSSL_VERSION="3.2.1"

# Define NGINX compilation options
NGINX_COMPILATION_OPTIONS=${NGINX_COMPILATION_OPTIONS:-"
	--prefix=/etc/nginx \
	--sbin-path=/usr/sbin/nginx \
	--conf-path=/etc/nginx/nginx.conf \
	--error-log-path=/var/log/nginx/error.log \
	--http-log-path=/var/log/nginx/access.log \
	--pid-path=/var/run/nginx.pid \
	--lock-path=/var/run/nginx.lock \
	--http-client-body-temp-path=/var/cache/nginx/client_temp \
	--http-proxy-temp-path=/var/cache/nginx/proxy_temp \
	--http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
	--user=nginx \
	--group=nginx \

    --with-threads \
	--with-file-aio \
	--with-http_ssl_module \
	--with-http_v2_module \
	--with-http_mp4_module \
	--with-http_auth_request_module \
	--with-http_slice_module \
	--with-http_stub_status_module \
	--with-http_realip_module \
	--with-http_sub_module
"}

# Main menu
function main_menu {
    echo "*************************************************"
    echo "*                                               *"
    echo "* NGINX Installer - Bodybuilded nginx installer *"
    echo "*                                               *"
    echo "*************************************************"
    echo ""
    echo "    1) Install or update NGINX"
    echo "    2) Uninstall NGINX"
    echo "    3) Update this script"
    echo "    4) Exit"
    echo ""

    while [[ $MODE != "1" && $MODE != "2" && $MODE != "3" && $MODE != "4" ]]; do
        read -rp "Choose an option to start: [1-5]: " -e -i "1" MODE
    done

    echo ""
    echo "*************************************************"
}

# Nginx version menu
function nginx_version {
    echo ""
    echo "NGINX versions available:"
    echo ""
    echo "    1) $NGINX_MAINLINE_VERSION (mainline)"
    echo "    2) $NGINX_STABLE_VERSION (stable)"
    echo ""

    while [[ $NGINX_VERSION != "1" && $NGINX_VERSION != "2" ]]; do
        read -rp "Choice: [1-2]: " -e -i "2" NGINX_VERSION
    done

    case $NGINX_VERSION in
    1)
        NGINX_VERSION=$NGINX_MAINLINE_VERSION
        ;;
    2)
        NGINX_VERSION=$NGINX_STABLE_VERSION
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
    esac
}

# Modules menu
function modules_menu {
    echo ""
    echo "Choose modules to install with NGINX:"
    echo ""

    # Header more
    while [[ $HEADER_MORE != "y" && $HEADER_MORE != "n" ]]; do
        read -rp "    Header more: [y/n]: " -e -i "n" HEADER_MORE
    done

    # OpenSSL package to use
    echo ""
    echo "OpenSSL package to use:"
    echo ""
    echo "    1) OpenSSL 3.2.1"
    echo "    2) LibreSSL 3.8.2"
    echo ""

    while [[ $OPENSSL != "1" && $OPENSSL != "2" ]]; do
        read -rp "Choice: [1-2]: " -e -i "1" OPENSSL
    done

    case $OPENSSL in
    1)
        OPENSSL=openssl
        ;;
    2)
        OPENSSL=libressl
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
    esac
}

function install_nginx {
    # Cleanup previous installations if any
    rm -rf /tmp/nginx-installer
    mkdir -p /tmp/nginx-installer || exit 1
    cd /tmp/nginx-installer || exit 1

    # Install dependencies
    apt update || exit 1
    apt-get install -y build-essential ca-certificates wget curl libpcre3 libpcre3-dev autoconf unzip automake libtool tar git libssl-dev zlib1g-dev uuid-dev lsb-release libxml2-dev libxslt1-dev cmake || exit 1

    # Download header more
    if [[ $HEADER_MORE == "y" ]]; then
        cd /tmp/nginx-installer || exit 1
        git clone https://github.com/openresty/headers-more-nginx-module.git
        cd /tmp/nginx-installer/headers-more-nginx-module || exit 1
    fi

    # Download OpenSSL
    cd /tmp/nginx-installer || exit 1
    if [[ $OPENSSL == "openssl" ]]; then
        git clone -b openssl-3.2.1 https://github.com/openssl/openssl
        cd /tmp/nginx-installer/openssl || exit 1
        ./config || exit 1
    else
        git clone -b v3.8.2 https://github.com/libressl/portable
        cd /tmp/nginx-installer/portable || exit 1
        cd ../ && mv portable libressl && cd libressl || exit 1
        ./autogen.sh || exit 1
        ./configure \
			LDFLAGS=-lrt \
			CFLAGS=-fstack-protector-strong \
			--prefix=/tmp/nginx-installer/libressl/.openssl/ \
			--enable-shared=no \
            || exit 1
        make install-strip -j "$(nproc)" || exit 1
    fi

    # Apply modules to NGINX compilation options
    if [[ $HEADER_MORE == 'y' ]]; then
		NGINX_COMPILATION_OPTIONS=$(
			echo "$NGINX_COMPILATION_OPTIONS"
			echo "--add-module=/tmp/nginx-installer/headers-more-nginx-module"
		)
	fi

    if [[ $OPENSSL == "openssl" ]]; then
        NGINX_COMPILATION_OPTIONS=$(
			echo "$NGINX_COMPILATION_OPTIONS"
			echo --with-openssl=/tmp/nginx-installer/openssl
		)
    else
        NGINX_COMPILATION_OPTIONS=$(
            echo "$NGINX_COMPILATION_OPTIONS"
            echo --with-openssl=/tmp/nginx-installer/libressl
        )
    fi

    # Download NGINX from sources
    cd /tmp/nginx-installer || exit 1
    git clone -b release-$NGINX_VERSION https://github.com/nginx/nginx.git
    cd /tmp/nginx-installer/nginx || exit 1

    ./auto/configure $NGINX_COMPILATION_OPTIONS || exit 1
    make -j$(nproc) || exit 1
    make install || exit 1

    # remove debugging symbols
	strip -s /usr/sbin/nginx

    # Create NGINX service if not exists
    if [[ ! -e /lib/systemd/system/nginx.service ]]; then
		cd /lib/systemd/system/ || exit 1
		wget https://raw.githubusercontent.com/Angristan/nginx-autoinstall/master/conf/nginx.service -O nginx.service || exit 1
		systemctl enable nginx
	fi

    # Create NGINX log rotation if not exists
    if [[ ! -e /etc/logrotate.d/nginx ]]; then
		cd /etc/logrotate.d/ || exit 1
		wget https://raw.githubusercontent.com/Angristan/nginx-autoinstall/master/conf/nginx-logrotate -O nginx
	fi

    # Create NGINX cache folder if not exists
    if [[ ! -d /var/cache/nginx ]]; then
		mkdir -p /var/cache/nginx
	fi

    # Create NGINX config folder if not exists
    if [[ ! -d /etc/nginx/sites-available ]]; then
		mkdir -p /etc/nginx/sites-available
	fi
	if [[ ! -d /etc/nginx/sites-enabled ]]; then
		mkdir -p /etc/nginx/sites-enabled
	fi
	if [[ ! -d /etc/nginx/conf.d ]]; then
		mkdir -p /etc/nginx/conf.d
	fi

    systemctl restart nginx

    # Block installation via apt
    if [[ $(lsb_release -si) == "Debian" ]] || [[ $(lsb_release -si) == "Ubuntu" ]]; then
		cd /etc/apt/preferences.d/ || exit 1
		echo -e 'Package: nginx*\nPin: release *\nPin-Priority: -1' > nginx-block
	fi

    # Cleanup
    rm -rf /tmp/nginx-installer

    echo "NGINX installed successfully!"
}

# Define variables if script is in headless mode
if [[ $1 == "--headless" ]]; then
    HEADLESS=true

    MODE=${MODE:-1}
    NGINX_VERSION=${NGINX_VERSION:-$NGINX_STABLE_VERSION}
    HEADER_MORE=${HEADER_MORE:-"y"}
    OPENSSL=${OPENSSL:-"libressl"}
else
    main_menu
    nginx_version
    modules_menu
fi

case $MODE in
1)
    install_nginx
    ;;
*)
    echo "Invalid mode"
    exit 1
    ;;
esac