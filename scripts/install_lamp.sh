#!/bin/bash

# Salir inmediatamente si un comando falla y mostrar los comandos ejecutados (para depuración)
set -ex

# Importar las variables del archivo .env (asumiendo que se ejecuta desde la carpeta scripts)
source .env

# 1. Actualizar el sistema
apt-get update -y
apt-get upgrade -y

# 2. Instalar Apache, MySQL, PHP y herramientas necesarias
apt-get install apache2 mariadb-server php libapache2-mod-php php-mysql git unzip -y

# 3. Asegurar/Configurar MySQL de forma automatizada
# (Establece la contraseña de root de MySQL usando la variable de .env)
# Intentar cambiarla usando la variable. Si ya se cambió antes, no dará error crítico.
mysql -u root -p"$DB_ROOT_PASS" -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$DB_ROOT_PASS'; FLUSH PRIVILEGES;" || mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$DB_ROOT_PASS'; FLUSH PRIVILEGES;"

# 4. Copiar configuración personalizada de Apache si fuera necesario
cp ../conf/000-default.conf /etc/apache2/sites-available/000-default.conf
systemctl restart apache2