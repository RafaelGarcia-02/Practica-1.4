#!/bin/bash
set -ex

# Importar variables
source .env

# 1. Limpiar directorio temporal y clonar el repositorio de la aplicación
rm -rf $DIR_TEMP
git clone $REPO_URL $DIR_TEMP

# 2. Crear la Base de Datos y el Usuario para la aplicación
mysql -u root -p"$DB_ROOT_PASS" <<EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

# 3. Importar el script SQL de la práctica en la base de datos creada
# (Nota: Revisa en el repositorio clonado la ruta exacta del archivo .sql)
mysql -u root -p"$DB_ROOT_PASS" $DB_NAME < $DIR_TEMP/db/database.sql

# 4. Modificar el archivo de configuración de la app web con los datos de nuestra DB
# Normalmente la app tiene un archivo 'config.php' o similar. Usamos 'sed' para reemplazar los valores.
# Ejemplo (ajusta según cómo sea el archivo de configuración de la app de Jose Juan):
# sed -i "s/db_user_placeholder/$DB_USER/g" $DIR_TEMP/src/config.php

# 5. Mover los archivos de la app al directorio web de Apache
rm -rf /var/www/html/*
cp -r $DIR_TEMP/src/* /var/www/html/

# 4. Modificar el archivo de configuración de la app web con los datos de nuestra DB
sed -i "s/database_name_here/$DB_NAME/g" /var/www/html/config.php
sed -i "s/username_here/$DB_USER/g" /var/www/html/config.php
sed -i "s/password_here/$DB_PASS/g" /var/www/html/config.php

# 6. Ajustar permisos para que Apache pueda leer correctamente los archivos
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

echo "¡Despliegue completado con éxito!"