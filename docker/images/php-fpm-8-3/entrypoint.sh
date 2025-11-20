#!/bin/sh
set -e

# Если первый параметр это флаг, то предполагаем,
# что это флаг для команды artisan octane:start
if [ "${1#-}" != "$1" ]; then
    set -- /var/www/review-backend/artisan octane:start "$@"
fi

if echo "$@" | grep -q "octane"; then
    /var/www/review-backend/artisan config:cache
    /var/www/review-backend/artisan route:cache
fi


exec "$@"
