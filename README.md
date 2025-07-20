# Scripts de Automatización para Aulas

Este repositorio contiene un conjunto de scripts diseñados para automatizar la configuración y el mantenimiento de ordenadores en aulas de informática. Las tareas automatizadas incluyen la creación de cuentas de usuario, la instalación desatendida de software y la configuración de la red.

## Características Principales

*   **Gestión de Usuarios:** Creación masiva de cuentas de usuario locales con contraseñas predefinidas y carpetas personales seguras en la unidad `D:`.
*   **Instalador de Software:** Sistema de instalación de aplicaciones modular y desatendido, controlado por un fichero de configuración `aplicaciones.json`.
*   **Configuración de Red:** Asignación de una dirección IP estática, máscara de subred, puerta de enlace y servidores DNS. La IP se calcula dinámicamente a partir del nombre del equipo.
*   **Flexibilidad:** Fácil de adaptar y extender. Puedes modificar la lista de usuarios, el catálogo de software y los parámetros de red directamente en los ficheros de configuración.
*   **Logging:** Genera un registro detallado (`installation.log`) de todo el proceso de instalación de software.

## Estructura del Proyecto

```
aulascript-1/
├── repo/                     # Carpeta para los instaladores (.exe, .msi)
├── 1-crear-cuentas-instalar-aplicaciones.bat  # Script principal de configuración
├── 2-cambiar-ip.bat          # Script para configurar la red estática
├── 3-wsl-post-restart.bat    # Script para tareas post-reinicio (ej. WSL)
├── aplicaciones.json         # Fichero de configuración de software
├── cuentas-usuario.ps1       # Lógica para crear usuarios y carpetas
├── instalar-aplicaciones.ps1 # Lógica para instalar el software
└── README.md                 # Este fichero
```

## Instrucciones de Uso

### 1. Preparar el Repositorio de Software

Coloca todos los instaladores de las aplicaciones que deseas instalar dentro de la carpeta `repo/`.

### 2. Configurar las Aplicaciones a Instalar

Edita el fichero `aplicaciones.json` para definir qué software se instalará.

*   **`name`**: Debe coincidir con el nombre del fichero instalador (sin la extensión y sin información de versión si varía). El script buscará un fichero que *comience* con este nombre.
*   **`parameters`**: Argumentos para la instalación silenciosa/desatendida.
*   **`install`**: `true` para instalar la aplicación, `false` para omitirla.
*   **`postscript`**: (Opcional) Nombre de un script de PowerShell a ejecutar después de la instalación.

#### Ejemplo de `aplicaciones.json`

```json
[
  {
    "name": "7z2301-x64",
    "parameters": "/S",
    "install": true
  },
  {
    "name": "vlc",
    "parameters": "/L=1034 /S",
    "install": true
  },
  {
    "name": "VSCodeUserSetup",
    "parameters": "/VERYSILENT /MERGETASKS=!runcode",
    "install": false
  }
]
```

### 3. Configurar los Usuarios (Opcional)

Si necesitas cambiar la lista de usuarios a crear, edita la variable `$usuarios` al principio del fichero `cuentas-usuario.ps1`.

### 4. Ejecutar los Scripts

**Importante:** Todos los scripts `.bat` deben ejecutarse con privilegios de administrador.

1.  **Configuración Inicial:** Haz clic derecho sobre `1-crear-cuentas-instalar-aplicaciones.bat` y selecciona **"Ejecutar como administrador"**. Este script creará los usuarios e instalará el software definido en `aplicaciones.json`.
    *   **Nota sobre WSL:** La instalación de Windows Subsystem for Linux (WSL) se inicia en este paso pero requiere un reinicio para completarse.

2.  **Configuración de Red:** Haz clic derecho sobre `2-cambiar-ip.bat` y selecciona **"Ejecutar como administrador"** para configurar la red estática del equipo.

3.  **Reiniciar el Equipo:** Reinicia el ordenador para que se apliquen todos los cambios, especialmente la activación de la característica WSL.

4.  **Finalizar Instalación de WSL (Si aplica):** Si has instalado WSL, tras el reinicio, haz clic derecho sobre `3-wsl-post-restart.bat` y selecciona **"Ejecutar como administrador"**. Este script finalizará la configuración de WSL, instalando la distribución de Ubuntu y preparando el entorno para herramientas como Docker.

## Funcionamiento de la Configuración de Red

El script `2-cambiar-ip.bat` lanza un script de PowerShell (`2-cambiar-ip.ps1`) que está diseñado para aulas donde los equipos siguen un patrón de nomenclatura, como `AULA1-PC01`, `AULA1-PC02`, etc.

*   **Cálculo Automático:** El script calcula automáticamente la dirección IP basándose en los dos últimos dígitos numéricos del nombre del equipo.
    *   *Ejemplo:* Si el `hostname` es `AULA1-PC07` y la configuración base es `192.168.150.50`, la IP resultante será `192.168.150.57` (50 + 7).
*   **Confirmación Interactiva:** Antes de aplicar cualquier cambio, el script muestra la configuración que va a aplicar y pide una confirmación rápida (S/N).
*   **Flexibilidad:** Los valores de red por defecto (IP base, puerta de enlace, DNS) se pueden modificar fácilmente al principio del fichero `2-cambiar-ip.ps1`.
*   **Uso Avanzado (Automatización):** El script de PowerShell puede ejecutarse con parámetros para anular la configuración por defecto, lo que permite su uso en escenarios de despliegue totalmente automatizados.

Puedes modificar los valores por defecto directamente en el fichero `2-cambiar-ip.ps1` para adaptarlo a tu red.