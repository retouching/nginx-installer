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
CURRENT_SCRIPT_VERSION="0.1"

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
    --with-http_sub_module \
    --with-stream_ssl_module \
    --with-debug \
    --with-stream
"}

# Main menu
function main_menu {
    NEWEST_SCRIPT_VERSION=$(curl -s https://raw.githubusercontent.com/retouching/nginx-installer/master/VERSION)

    echo "*************************************************"
    echo "*                                               *"
    echo "* NGINX Installer - Bodybuilded nginx installer *"
    echo "*                                               *"
    echo "*************************************************"
    echo ""
    echo "    1) Install or update NGINX"
    echo "    2) Uninstall NGINX"

    if [[ $CURRENT_SCRIPT_VERSION != $NEWEST_SCRIPT_VERSION ]]; then
        echo "    3) Update this script [New version available!]"
    else
        echo "    3) Update this script"
    fi

    echo "    4) Exit"
    echo ""

    while [[ $MODE != "1" && $MODE != "2" && $MODE != "3" && $MODE != "4" ]]; do
        read -rp "Choose an option to start: [1-5]: " -e -i "1" MODE
    done

    echo ""
    echo "*************************************************"
}

# Nginx version menu function
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

    echo ""
    echo "*************************************************"
}

# Modules menu function
function modules_menu {
    echo ""
    echo "Choose modules to install with NGINX:"
    echo ""

    # Header more
    while [[ $HEADER_MORE != "y" && $HEADER_MORE != "n" ]]; do
        read -rp "    Header more: [y/n]: " -e -i "n" HEADER_MORE
    done

    # SSL fingerprint
    while [[ $SSL_FINGERPRINT != "y" && $SSL_FINGERPRINT != "n" ]]; do
        read -rp "    SSL fingerprint: [y/n]: " -e -i "n" SSL_FINGERPRINT
    done

    if [[ $SSL_FINGERPRINT == "y" ]]; then
        OPENSSL=openssl
    else
        echo ""
        echo "*************************************************"

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
    fi

    echo ""
    echo "*************************************************"
}

# Install NGINX function
function install_nginx {
    clear

    echo "Starting installation of NGINX $NGINX_VERSION in 5 seconds..."
    echo "Press CTRL+C to cancel"

    sleep 5

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

    # Download SSL fingerprint
    if [[ $SSL_FINGERPRINT == "y" ]]; then
        cd /tmp/nginx-installer || exit 1
        git clone https://github.com/phuslu/nginx-ssl-fingerprint.git
        cd /tmp/nginx-installer/nginx-ssl-fingerprint || exit 1
    fi

    # Download OpenSSL
    cd /tmp/nginx-installer || exit 1
    if [[ $OPENSSL == "openssl" ]]; then
        git clone -b openssl-3.2.1 https://github.com/openssl/openssl
        cd /tmp/nginx-installer/openssl || exit 1

        if [[ $SSL_FINGERPRINT == "y" ]]; then
            wget https://raw.githubusercontent.com/phuslu/nginx-ssl-fingerprint/master/patches/openssl.openssl-3.2.patch || exit 1
            patch -p1 < openssl.openssl-3.2.patch || exit 1
        fi
        
        ./config || exit 1
    else
        if [[ $SSL_FINGERPRINT == "y" ]]; then
            echo "LibreSSL is not supported with SSL fingerprint"
            exit 1
        fi

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

    if [[ $SSL_FINGERPRINT == 'y' ]]; then
        NGINX_COMPILATION_OPTIONS=$(
            echo "$NGINX_COMPILATION_OPTIONS"
            echo "--add-module=/tmp/nginx-installer/nginx-ssl-fingerprint"
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

    if [[ $SSL_FINGERPRINT == "y" ]]; then
        if [[ $NGINX_VERSION == $NGINX_MAINLINE_VERSION ]]; then
            wget https://raw.githubusercontent.com/phuslu/nginx-ssl-fingerprint/master/patches/nginx-1.25.patch -O nginx.patch || exit 1
        else
            wget https://raw.githubusercontent.com/phuslu/nginx-ssl-fingerprint/master/patches/nginx-1.24.patch -O nginx.patch || exit 1
        fi

        patch -p1 < nginx.patch || exit 1
    fi

    ./auto/configure $NGINX_COMPILATION_OPTIONS \
        --with-cc-opt="-O -fno-omit-frame-pointer -Wno-deprecated-declarations -Wno-ignored-qualifiers" \
        --with-ld-opt="-Wl,-rpath,/usr/local/lib/" || exit 1

    make -j$(nproc) || exit 1
    make install || exit 1

    # remove debugging symbols
    strip -s /usr/sbin/nginx

    # Create NGINX service if not exists
    if [[ ! -e /lib/systemd/system/nginx.service ]]; then
        cd /lib/systemd/system/ || exit 1
        wget https://raw.githubusercontent.com/retouching/nginx-installer/master/configs/nginx.service || exit 1
        systemctl enable nginx
    fi

    # Create NGINX log rotation if not exists
    if [[ ! -e /etc/logrotate.d/nginx ]]; then
        cd /etc/logrotate.d/ || exit 1
        wget https://raw.githubusercontent.com/retouching/nginx-installer/master/configs/nginx-logrotate -O nginx
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

    # Cleanup
    rm -rf /tmp/nginx-installer

    systemctl restart nginx

    SERVICE_STATUS=$(systemctl is-active nginx)

    if [[ $SERVICE_STATUS != "active" ]]; then
        echo "An error occurred while installing NGINX"
        exit 1
    fi

    # Block installation via apt
    if [[ $(lsb_release -si) == "Debian" ]] || [[ $(lsb_release -si) == "Ubuntu" ]]; then
        cd /etc/apt/preferences.d/ || exit 1
        echo -e 'Package: nginx*\nPin: release *\nPin-Priority: -1' > nginx-block
    fi

    echo ""
    echo "NGINX installed successfully!"
}

# Uninstall NGINX function
function uninstall_nginx() {
    while [[ $RM_CONF != "y" && $RM_CONF != "n" ]]; do
        read -rp "Delete configuration: [y/n]: " -e -i "y" RM_CONF
    done

    while [[ $RM_LOGS != "y" && $RM_LOGS != "n" ]]; do
        read -rp "Delete logs: [y/n]: " -e -i "y" RM_LOGS
    done

    SERVICE_STATUS=$(systemctl is-active nginx)
    
    # Stop Nginx
    if [[ $SERVICE_STATUS == "active" ]]; then
        systemctl stop nginx
    fi

	# Removing Nginx files and modules files
	rm -rf /usr/local/src/nginx \
		/usr/sbin/nginx* \
		/usr/local/bin/luajit* \
		/usr/local/include/luajit* \
		/etc/logrotate.d/nginx \
		/var/cache/nginx \
		/lib/systemd/system/nginx.service \
		/etc/systemd/system/multi-user.target.wants/nginx.service

	# Reload systemctl
	systemctl daemon-reload

	# Remove conf files
	if [[ $RM_CONF == "y" ]]; then
		rm -rf /etc/nginx/
	fi

	# Remove logs
	if [[ $RM_LOGS == "y" ]]; then
		rm -rf /var/log/nginx
	fi

	# Remove Nginx APT block
	if [[ $(lsb_release -si) == "Debian" ]] || [[ $(lsb_release -si) == "Ubuntu" ]]; then
		rm -f /etc/apt/preferences.d/nginx-block
	fi
    
    echo ""
    echo "NGINX uninstalled successfully!"
}

# Update script function
function update_script() {
    wget https://raw.githubusercontent.com/retouching/nginx-installer/master/nginx-installer.sh
    chmod +x nginx-autoinstall.sh
    clear
    ./nginx-installer.sh
}

# Define variables if script is in headless mode
if [[ $1 == "--headless" ]]; then
    HEADLESS=true
    
    MODE=${MODE:-1}

    # Installation variables
    NGINX_VERSION=${NGINX_VERSION:-$NGINX_STABLE_VERSION}
    HEADER_MORE=${HEADER_MORE:-"n"}
    SSL_FINGERPRINT=${SSL_FINGERPRINT:-"n"}
    OPENSSL=${OPENSSL:-"openssl"}

    # Uninstallation variables
    RM_CONF=${RM_CONF:-"n"}
    RM_LOGS=${RM_LOGS:-"n"}
else
    HEADLESS=false
    main_menu
fi

clear

case $MODE in
1)
    nginx_version
    modules_menu
    install_nginx
    ;;
2)
    uninstall_nginx
    ;;
3)
    update_script
    ;;
4)
    ;;
*)
    echo "Invalid mode"
    exit 1
    ;;
esac