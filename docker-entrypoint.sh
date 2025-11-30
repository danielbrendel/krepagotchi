#!/bin/bash

# Default values for environment variables
DEFAULT_APP_DEBUG=true
DEFAULT_APP_UPDATEDEPS=false
DEFAULT_APP_TIMEZONE="UTC"
DEFAULT_LOG_ENABLE=true
DEFAULT_APP_GAMERESX=360
DEFAULT_APP_GAMERESY=640
DEFAULT_APP_BACKEND="http://localhost:8080"
DEFAULT_APP_MAXCOUNT_PICK=3
DEFAULT_APP_MAXCOUNT_ADD=2
DEFAULT_APP_ALWAYSONTOP=true
DEFAULT_APP_ACCESSTOKEN=$(php -r "echo md5(random_bytes(55) . date('Y-m-d H:i:s'));")

# Use environment variables if provided, otherwise use defaults
APP_DEBUG=${APP_DEBUG:-$DEFAULT_APP_DEBUG}
APP_UPDATEDEPS="${APP_UPDATEDEPS:-$DEFAULT_APP_UPDATEDEPS}"
APP_TIMEZONE="${APP_TIMEZONE:-$DEFAULT_APP_TIMEZONE}"
APP_GAMERESX=${APP_GAMERESX:-$DEFAULT_APP_GAMERESX}
APP_GAMERESY=${APP_GAMERESY:-$DEFAULT_APP_GAMERESY}
APP_BACKEND="${APP_BACKEND:-$DEFAULT_APP_BACKEND}"
APP_MAXCOUNT_PICK=${APP_MAXCOUNT_PICK:-$DEFAULT_APP_MAXCOUNT_PICK}
APP_MAXCOUNT_ADD=${APP_MAXCOUNT_ADD:-$DEFAULT_APP_MAXCOUNT_ADD}
APP_ALWAYSONTOP=${APP_ALWAYSONTOP:-$DEFAULT_APP_ALWAYSONTOP}
APP_ACCESSTOKEN="${APP_ACCESSTOKEN:-$DEFAULT_APP_ACCESSTOKEN}"

# Function to set the desired timezone
configure_timezone() {
    ln -sf /usr/share/zoneinfo/$APP_TIMEZONE /etc/localtime
    echo "$APP_TIMEZONE" > /etc/timezone
    dpkg-reconfigure -f noninteractive tzdata
}

# Function to set PHP error reporting based on APP_DEBUG
configure_php_error_reporting() {
    if [ "$APP_DEBUG" = "false" ]; then
        # Suppress warnings and notices if APP_DEBUG is false
        echo 'error_reporting = E_ALL & ~E_NOTICE & ~E_WARNING & ~E_DEPRECATED' > /usr/local/etc/php/conf.d/errors.ini
        echo 'display_errors = Off' >> /usr/local/etc/php/conf.d/errors.ini
    else
        # Show all errors if APP_DEBUG is true
        echo 'error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT' > /usr/local/etc/php/conf.d/errors.ini
        echo 'display_errors = On' >> /usr/local/etc/php/conf.d/errors.ini
    fi
}

# Function to create the .env file
create_environment_file() {
    rm -f "/var/www/html/.env"

    cat <<-EOF >> /var/www/html/.env

    # App settings
    APP_NAME="Krepagotchi"
    APP_VERSION="1.0"
    APP_AUTHOR="Daniel Brendel"
    APP_CONTACT="www.danielbrendel.com"
    APP_DESCRIPTION="A cozy and wholesome virtual pet sim"
    APP_DEBUG=$APP_DEBUG
    APP_BASEDIR=""
    APP_TIMEZONE="$APP_TIMEZONE"
    APP_GAMERESX=$APP_GAMERESX
    APP_GAMERESY=$APP_GAMERESY
    APP_BACKEND="$APP_BACKEND"
    APP_MAXCOUNT_PICK=$APP_MAXCOUNT_PICK
    APP_MAXCOUNT_ADD=$APP_MAXCOUNT_ADD
    APP_ALWAYSONTOP=$APP_ALWAYSONTOP
    APP_ACCESSTOKEN="$APP_ACCESSTOKEN"

    # Session
    SESSION_ENABLE=true
    SESSION_DURATION=0
    SESSION_NAME=null

    # Database settings
    DB_ENABLE=true
    DB_HOST="$DB_HOST"
    DB_USER="$DB_USERNAME"
    DB_PASSWORD="$DB_PASSWORD"
    DB_PORT=$DB_PORT
    DB_DATABASE="$DB_DATABASE"
    DB_DRIVER=mysql
    DB_CHARSET="$DB_CHARSET"

    # Logging
    LOG_ENABLE=$LOG_ENABLE
EOF
}

set_apache_server_name() {
    if [ -n "$APACHE_SERVER_NAME" ]; then
        echo "ServerName $APACHE_SERVER_NAME" >> /etc/apache2/apache2.conf;
    fi
}

# Function to check DB connection
check_db() {
    mysql -u "$DB_USERNAME" -p"$DB_PASSWORD" -h "$DB_HOST" -P "$DB_PORT" -D "$DB_DATABASE" -N -s -e "SELECT 1;" > /dev/null 2>&1
}

# Function to wait for the database
wait_for_db() {
    local delay=5  # delay in seconds
    local attempt=1

    while ! check_db; do
        echo "Waiting for database to be available... Attempt $attempt"
        attempt=$((attempt+1))
        sleep "$delay"
    done

    echo "Database is available."
}

# Configure timezone
configure_timezone

# Configure PHP error reporting
configure_php_error_reporting

# Create .env configuration file
create_environment_file

# To get rid of apache warnings, you can set the server name with the env var.
set_apache_server_name

# Call the wait_for_db function
wait_for_db

# Copy migration content
cp /tmp/migrations/* /var/www/html/app/migrations

# Set permissions to folder for migrations
chown -R www-data:www-data /var/www/html/app/migrations

# Update dependencies if desired
if [ "$APP_UPDATEDEPS" = "true" ]; then
    composer update
fi

# Run database migrations
php asatru migrate:fresh

# Set permissions to folder for logs
chown -R www-data:www-data /var/www/html/app/logs

# Set permissions to public folder
chown -R www-data:www-data /var/www/html/public
chmod 755 /var/www/html/public

# Print informational message
echo -e "\033[32mThe system is now ready for operation.\033[39m"

# Then exec the container's main process (CMD)
exec "$@"
