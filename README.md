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
│   └── 000-default.conf      # Configuración de Apache VirtualHost
└── scripts/
    ├── install_lamp.sh       # Script de instalación del stack LAMP
    ├── deploy.sh             # Script de despliegue de la aplicación
    └── .env                  # Archivo de configuración (variables de entorno)
```

---

## Requisitos Previos

- Servidor Linux con acceso root o permisos sudo
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
   curl http://localhost
   # O abre en navegador: http://tu-servidor-ip
   ```

4. **Ver logs si hay problemas**
   ```bash
   tail -f /var/log/apache2/error.log      # Errores de Apache
   tail -f /var/log/apache2/access.log     # Accesos a Apache
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
3. **Usa HTTPS** en producción (requiere certificado SSL/TLS)
4. **Restringe permisos de archivos** sensibles
5. **Actualiza regularmente** los paquetes del sistema

---

## Variables de Entorno (.env)

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `DB_ROOT_PASS` | Contraseña root de MySQL | `SecurePass123!` |
| `DB_NAME` | Nombre de la base de datos | `mi_aplicacion` |
| `DB_USER` | Usuario para la aplicación | `app_user` |
| `DB_PASS` | Contraseña del usuario | `AppPass456!` |
| `REPO_URL` | URL del repositorio Git | `https://github.com/user/repo.git` |
| `DIR_TEMP` | Directorio temporal | `/tmp/app-temp` |

---

## Referencias Útiles

- [Documentación Apache](https://httpd.apache.org/docs/)
- [Documentación MySQL](https://dev.mysql.com/doc/)
- [Documentación PHP](https://www.php.net/docs.php)
- [Bash scripting guide](https://www.gnu.org/software/bash/manual/)

---

## Contacto y Soporte

Para problemas o preguntas sobre este despliegue, contacta al administrador del sistema.