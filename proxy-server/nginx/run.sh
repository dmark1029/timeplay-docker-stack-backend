echo "$PM_FRONT_CONFIG" > /usr/share/nginx/frontend/playlist-manager/config.json
echo "$GPS_FRONT_CONFIG" > /usr/share/nginx/frontend/gs-package-service/config.json
echo "$REG_FORM_CONFIG" > /usr/share/nginx/frontend/registration-form/config.json
echo "$USER_DASHBOARD_CONFIG" > /usr/share/nginx/frontend/user-dashboard/config.json
echo "$ADMIN_SERVICE_CONFIG" > /usr/share/nginx/frontend/admin-service/config.json
echo "$TP3_OPCON_CONFIG" > /usr/share/nginx/frontend/tp3-opcon/config.json
echo "$DOND_CONTROLLER_CONFIG" > /usr/share/nginx/frontend/dond/config.json
echo "$LOTTERY_CONTROLLER_CONFIG" > /usr/share/nginx/frontend/lottery/config.json
echo "$GS_LITE_CONFIG" > /usr/share/nginx/frontend/gs-lite/assets/assets/json/config.json

sed -i "s/@{NGINX_WORKER_PROCESSES}/$NGINX_WORKER_PROCESSES/g" /etc/nginx/nginx.conf
sed -i "s/@{NGINX_WORKER_CONNECTIONS}/$NGINX_WORKER_CONNECTIONS/g" /etc/nginx/nginx.conf
sed -i "s/@{NGINX_AUTO_UPGRADE_DOMAINS}/$NGINX_AUTO_UPGRADE_DOMAINS/g" /etc/nginx/nginx.conf
sed -i "s/@{RMB_WEBSOCKET_PORT}/$RMB_WEBSOCKET_PORT/g" /etc/nginx/nginx.conf
sed -i "s/@{CATCH_ALL_SERVICE}/$CATCH_ALL_SERVICE/g" /etc/nginx/nginx.conf

nginx -g "daemon off;"
