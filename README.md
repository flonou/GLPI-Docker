# GLPI-Docker
A repository to create GLPI docker images

## compose.yaml

Ths compose.yaml requires the mariadb.env and glpi.env files. You can change some parameters and passwords there. the glpi.env files allows for automatic glpi installation and configuration when first launching the container. The compose script also waits for the mariadb service to be ready before starting the glpi service
The GLPI image also contains phpCAS installation, a 2 minutes cron execution for GLPI.


```yaml
version: "3.9"

services:
#MariaDB Container
  mariadb:
    image: mariadb:10.11
    container_name: mariadb
    hostname: mariadb
    env_file:
      - ./mariadb.env
    restart: unless-stopped
    volumes:
      - ./mariadb.env:/mariadb.env
    # For persistant data
    #  - ./db_data:/var/lib/mysql
    ports:
      - "3306:3306"
    environment:
      - TZ=Europe/Paris
    healthcheck:
      test: ["CMD-SHELL", "mysql -u root -p$$MARIADB_ROOT_PASSWORD" ]
      interval: 5s
      timeout: 5s
      retries: 15

#GLPI Container
  glpi:
    image: flonou/glpi:latest
    container_name : glpi
    hostname: glpi
    depends_on:
      mariadb:
        condition: service_healthy 
    restart: unless-stopped
    #volumes:
    # For persistant data
    # - /config:/config
    # - /files:/files
    # - /marketplace:/var/www/html/marketplace
    # - /plugins:/var/www/html/plugins
    # To use HTTPS
    # - /ssl:/etc/apache2/ssl
    # or
    # - ./ssl-cert.pem:/etc/apache2/ssl/ssl-cert.pem
    # - ./ssl-cert.key:/etc/apache2/ssl/ssl-cert.key
    #  and optionnaly
    # - ./server-ca.crt:/etc/apache2/ssl/server-ca.crt
    ports:
      - "8080:80"
      - "443:443"
    env_file:
      - ./glpi.env
    environment:
      - TIMEZONE=Europe/Paris
    # To use HTTPS
    #  - ENABLE_HTTPS=true
    # To disable HTTP
    #  - DISABLE_HTTP=true
```

Note : It's possible to configure https access with the compose.yaml file. Another solution is to use an Nginx container.

To run the services, type 
```sh
docker compose up -d
```