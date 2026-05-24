# Práctica 1.2 - Despliegue de Aplicación Web con LAMP

## Descripción General

Este proyecto contiene scripts automatizados para el despliegue de una aplicación web basada en la stack **LAMP** (Linux, Apache, MySQL/MariaDB, PHP). El proceso está dividido en dos fases principales:

1. **Instalación del entorno LAMP**: Configura el servidor con todos los servicios necesarios
2. **Despliegue de la aplicación**: Descarga, configura y pone en marcha la aplicación web

---

## Estructura del Proyecto

```
Practica1.2/
├── README.md                 # Este archivo - guía de despliegue
├── conf/
│   ├── 000-default.conf      # Configuración de Apache VirtualHost (HTTP)
│   └── default-ssl.conf      # [NUEVO] Configuración de Apache VirtualHost (HTTPS)
├── img/
│   ├── 1.png
│   ├── 2.png
│   ├── 3.png
│   └── 4.png
└── scripts/
    ├── install_lamp.sh       # Script de instalación del stack LAMP
    ├── deploy.sh             # Script de despliegue de la aplicación
    ├── setup_selfsigned_certificate.sh  # [NUEVO] Script para generar certificados SSL
    └── .env                  # Archivo de configuración (variables de entorno)
```

---

## Requisitos Previos

- Servidor Linux con acceso root o permisos sudo ( en nuestro caso uso de AWS EC2)
![alt text](img/1.png)
![alt text](img/2.png)
- Conexión a internet para descargar paquetes
- Git instalado (si no está, el script install_lamp.sh lo instala)

---

## Guía Paso a Paso

### Paso 1: Preparación del Archivo de Configuración

Antes de ejecutar cualquier script, debes crear un archivo `.env` en la carpeta `scripts/` con las siguientes variables:

```bash
# Ejemplo de .env
DB_ROOT_PASS="tu_contraseña_root_mysql"      # Contraseña para el usuario root de MySQL
DB_NAME="nombre_base_datos"                    # Nombre de la base de datos a crear
DB_USER="usuario_bd"                          # Usuario para acceder a la BD
DB_PASS="contraseña_usuario_bd"               # Contraseña del usuario
REPO_URL="https://github.com/usuario/repo"    # URL del repositorio de la aplicación
DIR_TEMP="/tmp/app-temp"                      # Directorio temporal para clonar el repo
```

**Nota importante**: Guarda las contraseñas en un lugar seguro. El archivo `.env` contiene credenciales sensibles.

---

### Paso 2: Ejecución del Script de Instalación LAMP

El script `install_lamp.sh` prepara el servidor instalando todos los componentes necesarios.

#### Comando:
```bash
cd scripts
bash install_lamp.sh
```

#### ¿Qué hace este script?

1. **Actualizar el sistema**
   - `apt-get update -y`: Actualiza la lista de paquetes disponibles
   - `apt-get upgrade -y`: Actualiza los paquetes instalados a sus últimas versiones

2. **Instalar paquetes necesarios**
   - `apache2`: Servidor web HTTP
   - `mariadb-server`: Base de datos (equivalente open-source a MySQL)
   - `php`: Lenguaje de programación para backend
   - `libapache2-mod-php`: Módulo para ejecutar PHP en Apache
   - `php-mysql`: Conector PHP para bases de datos MySQL/MariaDB
   - `git`: Control de versiones (para clonar repositorios)
   - `unzip`: Utilidad para descomprimir archivos

3. **Configurar MySQL**
   - Establece la contraseña del usuario root de MySQL usando la variable `DB_ROOT_PASS` del archivo `.env`
   - Ejecuta `FLUSH PRIVILEGES` para aplicar los cambios

4. **Configurar Apache**
   - Copia el archivo de configuración personalizado `000-default.conf` a `/etc/apache2/sites-available/`
   - Reinicia Apache para aplicar la configuración

#### Opciones de ejecución:

```bash
# Ejecución con output detallado (muestra cada comando)
bash -x install_lamp.sh

# Ejecución normal (recomendado)
bash install_lamp.sh
```

---

### Paso 3: Ejecución del Script de Despliegue

Una vez el servidor LAMP está instalado, ejecuta el script de despliegue para instalar tu aplicación.

#### Comando:
```bash
cd scripts
bash deploy.sh
```

#### ¿Qué hace este script?

1. **Limpiar y clonar el repositorio**
   ```bash
   rm -rf $DIR_TEMP                  # Elimina directorio temporal si existe
   git clone $REPO_URL $DIR_TEMP     # Clona el repositorio con la aplicación
   ```
   - Obtiene el código más reciente de tu aplicación web

2. **Crear la base de datos**
   ```sql
   CREATE DATABASE IF NOT EXISTS $DB_NAME;
   CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
   GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
   FLUSH PRIVILEGES;
   ```
   - Crea una nueva base de datos con el nombre especificado
   - Crea un usuario específico para la aplicación (con permisos limitados, más seguro que usar root)
   - Otorga todos los permisos necesarios para que la aplicación acceda a la BD

3. **Importar datos de la base de datos**
   ```bash
   mysql -u root -p"$DB_ROOT_PASS" $DB_NAME < $DIR_TEMP/db/database.sql
   ```
   - Importa la estructura y datos iniciales desde el archivo `database.sql` del repositorio

4. **Configurar la aplicación**
   ```bash
   sed -i "s/database_name_here/$DB_NAME/g" /var/www/html/config.php
   sed -i "s/username_here/$DB_USER/g" /var/www/html/config.php
   sed -i "s/password_here/$DB_PASS/g" /var/www/html/config.php
   ```
   - Reemplaza los placeholders en `config.php` con las credenciales reales de la BD
   - Usa `sed` (stream editor) para hacer sustituciones automáticas

5. **Mover archivos a la raíz web**
   ```bash
   rm -rf /var/www/html/*              # Limpia contenido anterior
   cp -r $DIR_TEMP/src/* /var/www/html # Copia aplicación al directorio público
   ```
   - Coloca los archivos de la aplicación en el directorio que Apache sirve (`/var/www/html`)

6. **Ajustar permisos**
   ```bash
   chown -R www-data:www-data /var/www/html    # www-data es el usuario de Apache
   chmod -R 755 /var/www/html                  # Permisos para lectura y ejecución
   ```
   - Garantiza que Apache (usuario `www-data`) puede leer y ejecutar los archivos
   - `755` significa: propietario (rwx), grupo (r-x), otros (r-x)

---

## Configuración de Apache - 000-default.conf

Este archivo configura cómo Apache sirve tu aplicación web.

### Contenido y explicación:

```apache
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html
```
- `<VirtualHost *:80>`: Escucha en todas las interfaces de red, puerto 80 (HTTP estándar)
- `ServerAdmin`: Correo del administrador (usado en páginas de error)
- `DocumentRoot`: Directorio raíz desde donde Apache sirve archivos (donde está tu aplicación)

```apache
    <Directory /var/www/html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
```
- `Options Indexes FollowSymLinks`: 
  - `Indexes`: Permite listar directorios si no hay archivo index
  - `FollowSymLinks`: Permite seguir enlaces simbólicos
- `AllowOverride All`: Permite archivos `.htaccess` (importante para reescrituras de URLs)
- `Require all granted`: Permite acceso a todos los usuarios

```apache
    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
```
- `ErrorLog`: Archivo donde Apache registra errores (útil para debugging)
- `CustomLog`: Archivo de log de accesos (quién accede, cuándo, qué pide)

---

## Verificar que el Despliegue Fue Exitoso

Después de ejecutar ambos scripts, verifica que todo funciona:

1. **Verificar que Apache está corriendo**
   ```bash
   systemctl status apache2
   ```
   Debe mostrar: `active (running)`

2. **Verificar que MySQL está corriendo**
   ```bash
   systemctl status mariadb
   ```
   Debe mostrar: `active (running)`

3. **Acceder a la aplicación**
   ```bash
   abre en navegador: http://tu-servidor-ip
   ```
   ![alt text](img/3.png)

4. **Ver logs si hay problemas**
   ```bash
   tail -f /var/log/apache2/error.log      # Errores de Apache
   tail -f /var/log/apache2/access.log     # Accesos a Apache
   ```

---

## [AMPLIACIÓN] Paso 4: Configuración de SSL/HTTPS con Certificado Autofirmado ( Practica 1.4 ) 

### ¿Qué es SSL/HTTPS?

**SSL (Secure Sockets Layer)** y su sucesor **TLS (Transport Layer Security)** son protocolos que cifran la conexión entre el navegador y el servidor, protegiendo datos sensibles como credenciales, información personal, etc.

**HTTPS** es HTTP sobre SSL/TLS. En lugar del puerto 80 (HTTP), usa el puerto 443 (HTTPS).

### ¿Qué son los certificados autofirmados?

Un certificado autofirmado es un certificado que generas tú mismo, sin autoridad certificadora externa. Es útil para desarrollo y testing, pero en producción se recomienda un certificado de autoridad certificadora reconocida.

### Nuevo Script: setup_selfsigned_certificate.sh

He creado un nuevo script que automatiza completamente la configuración de HTTPS.

#### Comando:
```bash
cd scripts
sudo bash setup_selfsigned_certificate.sh
```

#### ¿Qué hace este script paso a paso?

**1. Generar el certificado autofirmado**
```bash
openssl req \
  -x509 \
  -nodes \
  -days 365 \
  -newkey rsa:2048 \
  -keyout /etc/ssl/private/apache-selfsigned.key \
  -out /etc/ssl/certs/apache-selfsigned.crt \
  -subj "/C=$OPENSSL_COUNTRY/ST=$OPENSSL_PROVINCE/L=$OPENSSL_LOCALITY/O=$OPENSSL_ORGANIZATION/OU=$OPENSSL_ORGUNIT/CN=$OPENSSL_COMMON_NAME/emailAddress=$OPENSSL_EMAIL"
```

**Desglose de parámetros:**
- `-x509`: Genera un certificado X.509 (estándar SSL/TLS)
- `-nodes`: No cifra la clave privada (necesario para automatización)
- `-days 365`: Validez de 365 días (1 año)
- `-newkey rsa:2048`: Genera clave RSA de 2048 bits (seguridad estándar)
- `-keyout`: Ruta donde guardar la clave privada
- `-out`: Ruta donde guardar el certificado
- `-subj`: Datos del certificado sin interacción (desde variables del `.env`)

**Archivos generados:**
- `/etc/ssl/private/apache-selfsigned.key` - Clave privada (¡CONFIDENCIAL!)
- `/etc/ssl/certs/apache-selfsigned.crt` - Certificado público

**2. Copiar configuraciones de Apache**
```bash
cp ../conf/default-ssl.conf /etc/apache2/sites-available/default-ssl.conf
cp ../conf/000-default.conf /etc/apache2/sites-available/000-default.conf
```
- Instala la configuración HTTPS en Apache
- Mantiene también la configuración HTTP (puerto 80)

**3. Habilitar el sitio SSL**
```bash
a2ensite default-ssl.conf
```
- Activa el VirtualHost HTTPS en Apache

**4. Habilitar módulos necesarios**
```bash
a2enmod ssl
a2enmod rewrite
```
- `ssl`: Módulo SSL/TLS para Apache
- `rewrite`: Permite reescrituras de URL (usado para redirigir HTTP → HTTPS)

**5. Reiniciar Apache**
```bash
systemctl restart apache2
```
- Aplica todos los cambios de configuración

---

### Nueva Configuración: default-ssl.conf

```apache
<VirtualHost *:443>
    DocumentRoot /var/www/html
    DirectoryIndex index.php index.html

    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/apache-selfsigned.crt
    SSLCertificateKeyFile /etc/ssl/private/apache-selfsigned.key

    <Directory /var/www/html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
```

**Explicación:**
- `<VirtualHost *:443>`: Escucha en puerto 443 (HTTPS estándar)
- `SSLEngine on`: Activa SSL/TLS en este VirtualHost
- `SSLCertificateFile`: Ruta del certificado público
- `SSLCertificateKeyFile`: Ruta de la clave privada
- El resto es igual a la configuración HTTP

---

### Variables de Entorno para OpenSSL

Añade estas variables al archivo `.env` en la carpeta `scripts/`:

```bash
# Variables para el certificado SSL/TLS
OPENSSL_COUNTRY="ES"                                    # País (código ISO 2 letras)
OPENSSL_PROVINCE="Madrid"                               # Provincia/Estado
OPENSSL_LOCALITY="Madrid"                               # Localidad/Ciudad
OPENSSL_ORGANIZATION="Mi Empresa"                       # Nombre de la organización
OPENSSL_ORGUNIT="IT Department"                         # Departamento
OPENSSL_COMMON_NAME="mi-servidor.com"                   # Nombre del servidor (dominio)
OPENSSL_EMAIL="admin@mi-servidor.com"                   # Email del administrador
```

**Importante:** El `OPENSSL_COMMON_NAME` debe coincidir con el dominio o IP de tu servidor.

---

### Tabla de Variables SSL/TLS

| Variable | Significado | Ejemplo |
|----------|-----------|---------|
| `OPENSSL_COUNTRY` | País (código ISO 2 letras) | `ES`, `US`, `MX` |
| `OPENSSL_PROVINCE` | Provincia/Región | `Madrid`, `California` |
| `OPENSSL_LOCALITY` | Ciudad | `Madrid`, `San Francisco` |
| `OPENSSL_ORGANIZATION` | Nombre empresa/organización | `Mi Empresa S.L.` |
| `OPENSSL_ORGUNIT` | Departamento/Unidad | `IT`, `DevOps` |
| `OPENSSL_COMMON_NAME` | **Dominio o IP del servidor** | `www.ejemplo.com`, `192.168.1.1` |
| `OPENSSL_EMAIL` | Email del administrador | `admin@ejemplo.com` |

---

### Verificar que HTTPS está funcionando

Después de ejecutar el script:

1. **Verificar que Apache reinició correctamente**
   ```bash
   systemctl status apache2
   ```

2. **Acceder a través de HTTPS**
   ```bash
   curl -k https://localhost
   # O en navegador: https://tu-servidor-ip
   # Nota: -k ignora la advertencia de certificado no confiable (autofirmado)
   ```

3. **Ver certificado en el navegador**
   ![alt text](img/4.png)
   - Se mostrará una advertencia de seguridad (es normal con certificados autofirmados)
   - El navegador permite continuar sin riesgos reales

4. **Verificar que los puertos están escuchando**
   ```bash
   netstat -tlnp | grep apache2
   # Debe mostrar escucha en 0.0.0.0:80 y 0.0.0.0:443
   ```

---

### Redirigir HTTP → HTTPS (Opcional)

Si quieres forzar que todo tráfico vaya por HTTPS, modifica `000-default.conf`:

```apache
<VirtualHost *:80>
    ServerName tu-dominio.com
    
    # Redirigir todo HTTP a HTTPS
    RewriteEngine On
    RewriteCond %{HTTPS} off
    RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]
</VirtualHost>
```

Luego reinicia Apache:
```bash
systemctl restart apache2
```

---

### Orden de ejecución recomendado

Para un despliegue completo con HTTPS:

1. **Instalar LAMP** (si no está instalado)
   ```bash
   bash install_lamp.sh
   ```

2. **Desplegar la aplicación**
   ```bash
   bash deploy.sh
   ```

3. **Configurar certificados SSL/HTTPS**
   ```bash
   sudo bash setup_selfsigned_certificate.sh
   ```

---

### Problemas comunes con SSL

**Error: "Certificate verification failed"**
- Es normal con certificados autofirmados
- En curl usa: `curl -k https://localhost`
- En navegador: haz clic en "Continuar" o "Aceptar riesgo"

**Error: "SSL_ERROR_RX_RECORD_TOO_LONG"**
- El navegador está accediendo a HTTP en el puerto 443
- Asegúrate de usar `https://` (no `http://`)

**Error: "Permission denied" al ejecutar el script**
```bash
chmod +x scripts/setup_selfsigned_certificate.sh
sudo bash scripts/setup_selfsigned_certificate.sh
```

**Los módulos SSL no se cargan**
```bash
sudo a2enmod ssl
sudo a2enmod rewrite
sudo systemctl restart apache2
```

---

## Solución de Problemas Comunes

### Los scripts no tienen permisos de ejecución
```bash
chmod +x scripts/install_lamp.sh
chmod +x scripts/deploy.sh
```

### Permiso denegado al ejecutar scripts
```bash
sudo bash scripts/install_lamp.sh
sudo bash scripts/deploy.sh
```

### Error: "No such file or directory" para `.env`
- Verifica que el archivo `.env` existe en la carpeta `scripts/`
- Ejecuta los scripts desde la carpeta `scripts/`

### MySQL rechaza la contraseña
- Verifica que `DB_ROOT_PASS` en `.env` coincide con la contraseña que estableciste
- Si es la primera ejecución, MySQL puede estar sin contraseña

### La aplicación muestra errores de conexión a BD
- Verifica que la BD, usuario y contraseña en `config.php` son correctos
- Ejecuta: `mysql -u root -p"$DB_ROOT_PASS" -e "USE $DB_NAME; SHOW TABLES;"`

---

## Notas de Seguridad

1. **Cambia las contraseñas por defecto** en el archivo `.env`
2. **No commits `.env`** al repositorio (agrega a `.gitignore`)
3. **Usa HTTPS en producción** (certificado SSL/TLS)
   - Este proyecto usa **certificados autofirmados** (útil para desarrollo)
   - En producción, usa certificados de autoridades certificadoras reconocidas (Let's Encrypt, etc.)
4. **Protege la clave privada** (`/etc/ssl/private/apache-selfsigned.key`)
   - Nunca compartas ni subas a repositorios
   - Usa permisos restrictivos: `chmod 600`
5. **Restringe permisos de archivos** sensibles
6. **Actualiza regularmente** los paquetes del sistema
   ```bash
   sudo apt-get update && sudo apt-get upgrade -y
   ```
7. **Monitora los logs** regularmente
   ```bash
   tail -f /var/log/apache2/error.log
   tail -f /var/log/apache2/access.log
   ```

---

## Variables de Entorno (.env)

### Variables de Base de Datos

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `DB_ROOT_PASS` | Contraseña root de MySQL | `SecurePass123!` |
| `DB_NAME` | Nombre de la base de datos | `mi_aplicacion` |
| `DB_USER` | Usuario para la aplicación | `app_user` |
| `DB_PASS` | Contraseña del usuario | `AppPass456!` |
| `REPO_URL` | URL del repositorio Git | `https://github.com/user/repo.git` |
| `DIR_TEMP` | Directorio temporal | `/tmp/app-temp` |

### Variables de Certificado SSL/TLS [NUEVO]

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `OPENSSL_COUNTRY` | País (código ISO 2 letras) | `ES`, `US`, `MX` |
| `OPENSSL_PROVINCE` | Provincia/Región | `Madrid`, `California` |
| `OPENSSL_LOCALITY` | Ciudad | `Madrid`, `San Francisco` |
| `OPENSSL_ORGANIZATION` | Nombre empresa/organización | `Mi Empresa S.L.` |
| `OPENSSL_ORGUNIT` | Departamento/Unidad | `IT`, `DevOps` |
| `OPENSSL_COMMON_NAME` | **Dominio o IP del servidor** | `www.ejemplo.com`, `192.168.1.1` |
| `OPENSSL_EMAIL` | Email del administrador | `admin@ejemplo.com` |

---

## Referencias Útiles

- [Documentación Apache](https://httpd.apache.org/docs/)
- [Documentación Apache - SSL/TLS](https://httpd.apache.org/docs/current/ssl/)
- [Documentación OpenSSL](https://www.openssl.org/docs/)
- [Documentación MySQL](https://dev.mysql.com/doc/)
- [Documentación PHP](https://www.php.net/docs.php)
- [Bash scripting guide](https://www.gnu.org/software/bash/manual/)
- [Let's Encrypt (certificados gratuitos para producción)](https://letsencrypt.org/)
- [Mozilla SSL Configuration Generator](https://ssl-config.mozilla.org/)

---

## Contacto y Soporte

Para problemas o preguntas sobre este despliegue, contacta al administrador del sistema.