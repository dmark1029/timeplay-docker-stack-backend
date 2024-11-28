FROM registry.timeplay.com/docker-virtual/nginx:1.18.0

# copy all frontend pages
ADD ./staging /usr/share/nginx/frontend

# copy nginx config
ADD ./nginx/tp3.conf /etc/nginx/nginx.conf

# run.sh creates all frontend config.json from env vars, then starts nginx
ADD ./nginx/run.sh /usr/run.sh
RUN chmod +x /usr/run.sh
CMD ["/bin/bash", "/usr/run.sh"]
