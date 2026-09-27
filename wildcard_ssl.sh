#!/bin/bash

# ============================================================
# Wildcard SSL для Synology DSM + AdGuard Home
#
# Let's Encrypt
# DNS API
# Synology DSM
# Optional: AdGuard Home in Docker / Container Manager
#
# Версия: 1.0
# ============================================================

ACME_HOME="$HOME/.acme.sh"
ACME="$ACME_HOME/acme.sh"

# ============================================================
# Цвета
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ============================================================
# Functions
# ============================================================

info() {
    echo -e "[INFO] $1"
}

ok() {
    echo -e "${GREEN}[ OK ]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ============================================================
# Проверка запуска от root
# ============================================================

if [ "$(id -u)" -ne 0 ]; then
    error "Скрипт необходимо запускать от root."
    echo
    echo "Выполните:"
    echo "  sudo -i"
    echo
    exit 1
fi

# ============================================================
# Header
# ============================================================

echo
echo "============================================================"
echo "       WILDCARD SSL ДЛЯ SYNOLOGY DSM"
echo "============================================================"
echo

# ============================================================
# Домен
# ============================================================

read -r -p "Введите домен (например: tkv.su): " DOMAIN

if [ -z "$DOMAIN" ]; then
    error "Домен не указан."
    exit 1
fi

# Убираем протокол
DOMAIN="${DOMAIN#http://}"
DOMAIN="${DOMAIN#https://}"

# Убираем путь
DOMAIN="${DOMAIN%%/*}"

# Убираем завершающую точку
DOMAIN="${DOMAIN%.}"

# Если введён *.domain
if [[ "$DOMAIN" == \*.* ]]; then
    DOMAIN="${DOMAIN#*.}"
fi

# Если введён www.domain
if [[ "$DOMAIN" == www.* ]]; then
    DOMAIN="${DOMAIN#www.}"
fi

WILDCARD_DOMAIN="*.$DOMAIN"

# ============================================================
# Проверка домена
# ============================================================

if [[ ! "$DOMAIN" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?\.[A-Za-z]{2,}$ ]]; then
    error "Некорректный домен: $DOMAIN"
    exit 1
fi

echo
echo "============================================================"
echo "ПРОВЕРКА ДОМЕНА"
echo "============================================================"
echo
echo "Основной домен : $DOMAIN"
echo "Wildcard       : $WILDCARD_DOMAIN"
echo

read -r -p "Всё правильно? Продолжить? [Y/n]: " CONFIRM

if [[ "$CONFIRM" =~ ^[Nn]$ ]]; then
    echo "Отменено."
    exit 0
fi

# ============================================================
# Email
# ============================================================

echo
read -r -p "Email для Let's Encrypt: " EMAIL

if [ -z "$EMAIL" ]; then
    error "Email не указан."
    exit 1
fi

# ============================================================
# DNS provider
# ============================================================

echo
echo "============================================================"
echo "ВЫБОР DNS-ПРОВАЙДЕРА"
echo "============================================================"
echo
echo "1) Reg.ru"
echo "2) Timeweb Cloud"
echo "3) Yandex 360"
echo "4) Beget"
echo "5) Selectel"
echo "6) DNS Exit"
echo "7) Cloudflare"
echo

read -r -p "Ваш выбор (1-7): " PROVIDER

DNS_PLUGIN=""

case "$PROVIDER" in

    1)

        DNS_PLUGIN="dns_regru"

        echo
        echo "----- Reg.ru -----"

        read -r -p "Логин Reg.ru: " REGRU_API_Username
        read -r -s -p "Пароль Reg.ru: " REGRU_API_Password
        echo

        if [ -z "$REGRU_API_Username" ] ||
           [ -z "$REGRU_API_Password" ]; then
            error "Логин или пароль Reg.ru не указан."
            exit 1
        fi

        export REGRU_API_Username
        export REGRU_API_Password
        ;;

    2)

        DNS_PLUGIN="dns_timeweb"

        echo
        echo "----- Timeweb Cloud -----"
        echo
        echo "API JWT Token можно получить в панели Timeweb Cloud."
        echo

        read -r -s -p "Timeweb API Token: " TW_Token
        echo

        if [ -z "$TW_Token" ]; then
            error "Timeweb API Token не указан."
            exit 1
        fi

        export TW_Token
        ;;

    3)

        DNS_PLUGIN="dns_yandex360"

        echo
        echo "----- Yandex 360 -----"

        read -r -s -p "Yandex 360 API Token: " PDD_Token
        echo

        if [ -z "$PDD_Token" ]; then
            error "Yandex 360 API Token не указан."
            exit 1
        fi

        export PDD_Token
        ;;

    4)

        DNS_PLUGIN="dns_beget"

        echo
        echo "----- Beget -----"

        read -r -p "Логин Beget: " Beget_Username
        read -r -s -p "Пароль Beget: " Beget_Password
        echo

        if [ -z "$Beget_Username" ] ||
           [ -z "$Beget_Password" ]; then
            error "Логин или пароль Beget не указан."
            exit 1
        fi

        export Beget_Username
        export Beget_Password
        ;;

    5)

        DNS_PLUGIN="dns_selectel"

        echo
        echo "----- Selectel -----"

        read -r -p "Selectel Account ID: " SL_Login_ID
        read -r -p "Selectel Project Name: " SL_Project_Name
        read -r -p "Selectel Service User Name: " SL_Login_Name
        read -r -s -p "Selectel Service User Password: " SL_Pswd
        echo

        if [ -z "$SL_Login_ID" ] ||
           [ -z "$SL_Project_Name" ] ||
           [ -z "$SL_Login_Name" ] ||
           [ -z "$SL_Pswd" ]; then
            error "Не все параметры Selectel заполнены."
            exit 1
        fi

        export SL_Ver="v2"
        export SL_Login_ID
        export SL_Project_Name
        export SL_Login_Name
        export SL_Pswd
        ;;

    6)

        DNS_PLUGIN="dns_dnsexit"

        echo
        echo "----- DNS Exit -----"

        read -r -s -p "DNS Exit API Key: " DNSEXIT_API_KEY
        echo

        if [ -z "$DNSEXIT_API_KEY" ]; then
            error "DNS Exit API Key не указан."
            exit 1
        fi

        export DNSEXIT_API_KEY
        ;;

    7)

        DNS_PLUGIN="dns_cf"

        echo
        echo "----- Cloudflare -----"

        read -r -s -p "Cloudflare API Token: " CF_Token
        echo

        if [ -z "$CF_Token" ]; then
            error "Cloudflare API Token не указан."
            exit 1
        fi

        export CF_Token
        ;;

    *)

        error "Неверный выбор DNS-провайдера."
        exit 1
        ;;

esac

echo
ok "DNS plugin: $DNS_PLUGIN"

# ============================================================
# DSM HTTPS PORT
# ============================================================

echo
echo "============================================================"
echo "ПОРТ HTTPS SYNOLOGY DSM"
echo "============================================================"
echo
echo "Стандартный HTTPS-порт DSM: 5001"
echo

read -r -p "Порт DSM HTTPS [5001]: " SYNO_PORT

if [ -z "$SYNO_PORT" ]; then
    SYNO_PORT="5001"
fi

if ! [[ "$SYNO_PORT" =~ ^[0-9]+$ ]]; then
    error "Порт должен содержать только цифры."
    exit 1
fi

if [ "$SYNO_PORT" -lt 1 ] || [ "$SYNO_PORT" -gt 65535 ]; then
    error "Недопустимый порт. Допустимый диапазон: 1-65535."
    exit 1
fi

export SYNO_SCHEME="https"
export SYNO_HOSTNAME="localhost"
export SYNO_PORT

ok "DSM HTTPS: https://localhost:$SYNO_PORT"

# ============================================================
# DSM USER
# ============================================================

echo
echo "============================================================"
echo "ПОЛЬЗОВАТЕЛЬ SYNOLOGY DSM"
echo "============================================================"
echo
echo "Пользователь должен иметь права на управление сертификатами."
echo

read -r -p "Пользователь DSM: " SYNO_USERNAME

if [ -z "$SYNO_USERNAME" ]; then
    error "Пользователь DSM не указан."
    exit 1
fi

read -r -s -p "Пароль DSM: " SYNO_PASSWORD
echo

if [ -z "$SYNO_PASSWORD" ]; then
    error "Пароль DSM не указан."
    exit 1
fi

export SYNO_USERNAME
export SYNO_PASSWORD

# Разрешить создание сертификата, если его ещё нет
export SYNO_CREATE="1"

# Название сертификата в DSM
export SYNO_CERTIFICATE="$DOMAIN"

# ============================================================
# ADGUARD
# ============================================================

echo
echo "============================================================"
echo "ADGUARD HOME"
echo "============================================================"
echo

read -r -p "Установить сертификат в AdGuard Home? [Y/n]: " USE_ADGUARD

if [[ "$USE_ADGUARD" =~ ^[Nn]$ ]]; then

    USE_ADGUARD="0"

    info "Установка сертификата в AdGuard отключена."

else

    USE_ADGUARD="1"

    echo
    echo "Путь к папке, куда будут копироваться сертификаты."
    echo "Например: /volume1/docker/AdGuard/certs"
    echo

    read -r -p "Путь к сертификатам [/volume1/docker/AdGuard/certs]: " ADGUARD_CERT_DIR

    if [ -z "$ADGUARD_CERT_DIR" ]; then
        ADGUARD_CERT_DIR="/volume1/docker/AdGuard/certs"
    fi

    echo
    read -r -p "Имя Docker-контейнера [AdGuard]: " ADGUARD_CONTAINER

    if [ -z "$ADGUARD_CONTAINER" ]; then
        ADGUARD_CONTAINER="AdGuard"
    fi

    # --------------------------------------------------------
    # Поиск Docker
    # --------------------------------------------------------

    DOCKER_BIN=""

    if command -v docker >/dev/null 2>&1; then
        DOCKER_BIN="$(command -v docker)"
    else

        POSSIBLE_DOCKER_PATHS=(
            "/usr/local/bin/docker"
            "/usr/bin/docker"
            "/var/packages/ContainerManager/target/usr/bin/docker"
            "/volume1/@appstore/ContainerManager/usr/bin/docker"
        )

        for PATH_TO_DOCKER in "${POSSIBLE_DOCKER_PATHS[@]}"; do

            if [ -x "$PATH_TO_DOCKER" ]; then
                DOCKER_BIN="$PATH_TO_DOCKER"
                break
            fi

        done

    fi

    if [ -z "$DOCKER_BIN" ]; then

        error "Команда docker не найдена."
        echo
        echo "Проверьте:"
        echo "  command -v docker"
        echo
        echo "или:"
        echo "  find / -name docker -type f -executable 2>/dev/null"
        echo

        read -r -p "Продолжить БЕЗ настройки AdGuard? [y/N]: " CONTINUE_NO_DOCKER

        if [[ "$CONTINUE_NO_DOCKER" =~ ^[Yy]$ ]]; then

            USE_ADGUARD="0"

            warn "AdGuard пропущен."

        else

            error "Работа скрипта отменена."
            exit 1

        fi

    fi

    # --------------------------------------------------------
    # Проверяем контейнер
    # --------------------------------------------------------

    if [ "$USE_ADGUARD" = "1" ]; then

        if ! "$DOCKER_BIN" inspect "$ADGUARD_CONTAINER" >/dev/null 2>&1; then

            error "Docker-контейнер '$ADGUARD_CONTAINER' не найден."
            echo
            echo "Список контейнеров:"
            echo

            "$DOCKER_BIN" ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'

            echo
            read -r -p "Продолжить БЕЗ настройки AdGuard? [y/N]: " CONTINUE_NO_CONTAINER

            if [[ "$CONTINUE_NO_CONTAINER" =~ ^[Yy]$ ]]; then

                USE_ADGUARD="0"

                warn "AdGuard пропущен."

            else

                error "Работа скрипта отменена."
                exit 1

            fi

        else

            ok "Docker найден: $DOCKER_BIN"
            ok "Контейнер найден: $ADGUARD_CONTAINER"

        fi

    fi

    # --------------------------------------------------------
    # Каталог сертификатов
    # --------------------------------------------------------

    if [ "$USE_ADGUARD" = "1" ]; then

        if ! mkdir -p "$ADGUARD_CERT_DIR"; then
            error "Не удалось создать каталог:"
            error "$ADGUARD_CERT_DIR"
            exit 1
        fi

        ok "Каталог сертификатов: $ADGUARD_CERT_DIR"

    fi

fi

# ============================================================
# INSTALL ACME.SH
# ============================================================

if [ ! -f "$ACME" ]; then

    info "acme.sh не найден."
    info "Устанавливаем acme.sh..."

    cd "$HOME" || {
        error "Не удалось перейти в HOME."
        exit 1
    }

    if ! curl -fsSL https://get.acme.sh | sh -s email="$EMAIL"; then
        error "Ошибка установки acme.sh."
        exit 1
    fi

fi

if [ ! -f "$ACME" ]; then
    error "acme.sh после установки не найден:"
    error "$ACME"
    exit 1
fi

ok "acme.sh найден."

# ============================================================
# Let's Encrypt
# ============================================================

info "Выбираем Let's Encrypt..."

"$ACME" --set-default-ca --server letsencrypt

if [ $? -ne 0 ]; then
    error "Не удалось выбрать Let's Encrypt."
    exit 1
fi

ok "Let's Encrypt выбран."

# ============================================================
# DNS PLUGIN CHECK
# ============================================================

DNS_PLUGIN_FILE="$ACME_HOME/dnsapi/$DNS_PLUGIN.sh"

if [ ! -f "$DNS_PLUGIN_FILE" ]; then

    error "DNS plugin не найден:"
    error "$DNS_PLUGIN_FILE"

    echo
    echo "Попробуйте обновить acme.sh:"
    echo
    echo "  $ACME --upgrade"
    echo

    exit 1
fi

ok "DNS plugin найден."

# ============================================================
# FINAL CONFIRMATION
# ============================================================

echo
echo "============================================================"
echo "ФИНАЛЬНАЯ ПРОВЕРКА"
echo "============================================================"
echo
echo "Основной домен : $DOMAIN"
echo "Wildcard       : $WILDCARD_DOMAIN"
echo "DNS provider   : $DNS_PLUGIN"
echo "Email          : $EMAIL"
echo
echo "DSM:"
echo "  https://localhost:$SYNO_PORT"
echo "  Пользователь: $SYNO_USERNAME"
echo

if [ "$USE_ADGUARD" = "1" ]; then

    echo "AdGuard Home:"
    echo "  Контейнер : $ADGUARD_CONTAINER"
    echo "  Docker    : $DOCKER_BIN"
    echo "  Каталог   : $ADGUARD_CERT_DIR"
    echo

fi

echo "Запрашиваемые имена:"
echo "  $DOMAIN"
echo "  $WILDCARD_DOMAIN"
echo

read -r -p "Начать получение сертификата? [Y/n]: " START

if [[ "$START" =~ ^[Nn]$ ]]; then
    echo "Отменено."
    exit 0
fi

# ============================================================
# ISSUE CERTIFICATE
# ============================================================

echo
echo "============================================================"
echo "ПОЛУЧЕНИЕ WILDCARD SSL"
echo "============================================================"
echo

info "Создаём DNS challenge..."
info "Ожидание DNS: 180 секунд."
echo

"$ACME" --issue \
    --dns "$DNS_PLUGIN" \
    -d "$DOMAIN" \
    -d "$WILDCARD_DOMAIN" \
    --dnssleep 180 \
    --log

ISSUE_STATUS=$?

echo

if [ "$ISSUE_STATUS" -ne 0 ]; then

    error "Не удалось получить сертификат."

    echo
    echo "Код ошибки: $ISSUE_STATUS"
    echo
    echo "Лог:"
    echo "$ACME_HOME/acme.sh.log"
    echo

    exit "$ISSUE_STATUS"
fi

ok "Wildcard-сертификат успешно получен."

# ============================================================
# DEPLOY TO SYNOLOGY DSM
# ============================================================

echo
echo "============================================================"
echo "УСТАНОВКА СЕРТИФИКАТА В SYNOLOGY DSM"
echo "============================================================"
echo

"$ACME" --deploy \
    -d "$DOMAIN" \
    --deploy-hook synology_dsm \
    --insecure

DEPLOY_STATUS=$?

echo

if [ "$DEPLOY_STATUS" -ne 0 ]; then

    error "Сертификат получен, но установить его в DSM не удалось."

    echo
    echo "Проверьте:"
    echo
    echo "1. Пользователь имеет права на управление сертификатами."
    echo "2. Пароль DSM указан правильно."
    echo "3. Порт DSM указан правильно: $SYNO_PORT"
    echo "4. DSM доступен по HTTPS."
    echo
    echo "Лог:"
    echo "$ACME_HOME/acme.sh.log"
    echo

    exit "$DEPLOY_STATUS"
fi

ok "Сертификат установлен в Synology DSM."

# ============================================================
# INSTALL CERTIFICATE TO ADGUARD
# ============================================================

if [ "$USE_ADGUARD" = "1" ]; then

    echo
    echo "============================================================"
    echo "НАСТРОЙКА ADGUARD HOME"
    echo "============================================================"
    echo

    info "Копируем сертификат в:"
    echo "$ADGUARD_CERT_DIR"
    echo

    RELOAD_COMMAND="$DOCKER_BIN restart $ADGUARD_CONTAINER"

    "$ACME" --install-cert \
        -d "$DOMAIN" \
        --key-file "$ADGUARD_CERT_DIR/privkey.pem" \
        --fullchain-file "$ADGUARD_CERT_DIR/fullchain.pem" \
        --reloadcmd "$RELOAD_COMMAND"

    ADGUARD_STATUS=$?

    if [ "$ADGUARD_STATUS" -ne 0 ]; then

        error "Не удалось установить сертификат для AdGuard Home."

        echo
        echo "Сертификат в DSM уже установлен."
        echo "Проверьте:"
        echo "  $ADGUARD_CERT_DIR"
        echo

        exit "$ADGUARD_STATUS"
    fi

    chmod 644 "$ADGUARD_CERT_DIR/fullchain.pem"
    chmod 600 "$ADGUARD_CERT_DIR/privkey.pem"

    ok "Сертификат скопирован в AdGuard Home."
    ok "Автоматическое обновление AdGuard настроено."

fi

# ============================================================
# FINISH
# ============================================================

echo
echo "============================================================"
echo "                         ГОТОВО"
echo "============================================================"
echo
echo "Домен       : $DOMAIN"
echo "Wildcard    : $WILDCARD_DOMAIN"
echo "DNS provider: $DNS_PLUGIN"
echo
echo "DSM:"
echo "  https://localhost:$SYNO_PORT"
echo

if [ "$USE_ADGUARD" = "1" ]; then

    echo "AdGuard Home:"
    echo "  Контейнер: $ADGUARD_CONTAINER"
    echo
    echo "Сертификат:"
    echo "  $ADGUARD_CERT_DIR/fullchain.pem"
    echo
    echo "Ключ:"
    echo "  $ADGUARD_CERT_DIR/privkey.pem"
    echo
    echo "После автоматического продления будет выполнено:"
    echo "  $RELOAD_COMMAND"

fi

echo
echo "Автоматическое продление acme.sh настроено."
echo "Параметр --force НЕ используется."
echo
echo "============================================================"
