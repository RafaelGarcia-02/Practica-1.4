#!/bin/bash
set -ex

# 1. Importar variables del archivo .env
source .env

# 2. Generar el certificado autofirmado sin pedir datos por teclado (-subj)
openssl req \
  -x509 \
  -nodes \
  -days 365 \
  -newkey rsa:2048 \
  -keyout /etc/ssl/private/apache-selfsigned.key \
  -out /etc/ssl/certs/apache-selfsigned.crt \
  -subj "/C=$OPENSSL_COUNTRY/ST=$OPENSSL_PROVINCE/L=$OPENSSL_LOCALITY/O=$OPENSSL_ORGANIZATION/OU=$OPENSSL_ORGUNIT/CN=$OPENSSL_COMMON_NAME/emailAddress=$OPENSSL_EMAIL"

# 3. Copiar los archivos de configuración virtuales personalizados de Apache
cp ../conf/default-ssl.conf /etc/apache2/sites-available/default-ssl.conf
cp ../conf/000-default.conf /etc/apache2/sites-available/000-default.conf

# 4. Habilitar el sitio SSL en Apache
a2ensite default-ssl.conf

# 5. Habilitar los módulos necesarios: SSL y Rewrite (para la redirección)
a2enmod ssl
a2enmod rewrite

# 6. Reiniciar Apache para aplicar todos los cambios de forma segura
systemctl restart apache2

echo "¡Certificado SSL configurado y Apache securizado con éxito!"