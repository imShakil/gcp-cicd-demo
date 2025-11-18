FROM nginx:alpine

COPY nginx.conf.template /etc/nginx/templates/default.conf.template
COPY index.html /usr/share/nginx/html

CMD [ "nginx", "-g", "daemon off;" ]
