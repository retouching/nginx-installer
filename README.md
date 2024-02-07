<p align="center">
    <a href="https://github.com/retouching/nginx-installer">NGINX installer</a>
    <br/>
    <sup><em>Fast and complete NGINX installer</em></sup>
</p>

## Features

- Mainline or stable version from [source](https://github.com/nginx/nginx)
- Multiples modules and patch available
- Block NGINX installation using APT to avoid conflicts

#### Modules and patches available:

- [LibreSSL v3.8.2](https://github.com/libressl/portable) from source
- [OpenSSL v3.2.1](https://github.com/openssl/openssl) from source
- [OpenSSL v3.1.5+quic](https://github.com/quictls/openssl) from source
- HTTP/3 Support (with LibreSSL or Quic)
- [nginx-ssl-fingerprint](https://github.com/phuslu/nginx-ssl-fingerprint): high performance nginx module for ja3 and http2 fingerprint.
- [ngx_brotli](ngx_brotli): Brotli compression algorithm
- [headers-more-nginx-module](https://github.com/openresty/headers-more-nginx-module): Custom HTTP headers
- [testcookie-nginx-module](https://github.com/kyprizel/testcookie-nginx-module): simple robot mitigation module using cookie based challenge/response
- [nginx_substitutions_filter](https://github.com/yaoweibin/ngx_http_substitutions_filter_module): filter module which can do both reguar expression and fixed string substitutions on response bodies
- [ngx_cache_purge](https://github.com/FRiCKLE/ngx_cache_purge): adds ability to purge content from FastCGI, proxy, SCGI and uWSGI caches.
- [nginx_cookie_flag_module](https://github.com/AirisX/nginx_cookie_flag_module): allows to set the flags "HttpOnly", "secure" and "SameSite" for cookies.
- [NAXSI](https://github.com/wargio/naxsi): open-source, high performance, low rules maintenance WAF for NGINX

And more can be added in the future...

## Usage

```sh
wget https://raw.githubusercontent.com/retouching/nginx-installer/master/nginx-installer.sh -O nginx-installer.sh
chmod +x nginx-installer.sh
./nginx-installer.sh
```

#### You will be able to:

- Install / Update NGINX
- Uninstall NGINX with optional cleanup
- Self-update the script

## Headless use

You can run the script without the prompts. This allows for automated install and scripting.

```sh
./nginx-installer.sh --headless
```

Variables can be set in the environment to configure the script.

```sh
# Script mode
# 1: install / update nginx
# 2: uninstall nginx
# 3: update script
MODE=1

# Installation variables
# 1: mainline
# 2: stable
NGINX_VERSION=2
# y: install
# n: skip
HEADER_MORE=n
# y: install
# n: skip
SSL_FINGERPRINT=n
# 1: get openssl
# 1: get openssl+quic
# 3: get libressl
OPENSSL=1
# y: install
# n: skip
BROTLI=n
# y: install
# n: skip
TEST_COOKIE=n
# y: install
# n: skip
SUBSTITUTIONS_FILTER=n
# y: install
# n: skip
CACHE_PURGE=n
# y: install
# n: skip
HTTP3=n
# y: install
# n: skip
COOKIE_FLAG=n
# y: install
# n: skip
NAXSI=n

# Uninstallation variables
# y: remove configuration
# n: skip
RM_CONF=y
# y: remove logs
# n: skip
RM_LOGS=y
```

#### Example of usage:
*Install NGINX stable with SSL fingerprint and headers-more-nginx-module*

```sh
MODE=1 NGINX_VERSION=2 SSL_FINGERPRINT=y HEADER_MORE=y ./nginx-installer.sh --headless
```

## Credits

- [nginx-autoinstall](https://github.com/angristan/nginx-autoinstall/): Original script to install NGINX with modules and patches