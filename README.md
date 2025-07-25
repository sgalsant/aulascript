# Scripts de Automatización para Aulas

Este repositorio contiene un conjunto de scripts diseñados para automatizar la configuración y el mantenimiento de ordenadores en aulas de informática. Las tareas automatizadas incluyen la creación de cuentas de usuario, la instalación desatendida de software y la configuración de la red.

## Características Principales

*   **Menú Interactivo Centralizado:** Un único script `instalar.bat` que presenta un menú claro para ejecutar todas las tareas, evitando la necesidad de lanzar múltiples ficheros.
*   **Elevación Automática de Privilegios:** El script solicita automáticamente los permisos de administrador necesarios para funcionar.
*   **Instalador de Software Modular:** Sistema de instalación desatendido controlado por un fichero `aplicaciones.json`, que permite definir qué instalar y con qué parámetros.
*   **Gestión de Usuarios:** Creación masiva de cuentas de usuario locales con carpetas personales seguras.
*   **Configuración de Red Dinámica:** Asignación de una dirección IP estática, puerta de enlace y DNS, calculando la IP a partir del nombre del equipo.
*   **Manejo de Reinicios:** Capacidad para programar scripts que se ejecutan automáticamente después de un reinicio, esencial para instalaciones complejas como WSL.
*   **Logging:** Genera un registro detallado (`installation.log`) de todo el proceso de instalación de software.

## Estructura del Proyecto

```
aulascript-1/ 
├── repo/ # Carpeta para alojar los instaladores (.exe, .msi). 
├── script/ # Contiene toda la lógica de PowerShell. 
│ ├── cambiar-ip.ps1
│ ├── configurar-psremoting.ps1
│ ├── cuentas-usuario.ps1
│ ├── instalar-aplicaciones.ps1
│ └── utils.ps1
├── postscript/ # Scripts a ejecutar tras una instalación específica. 
│ ├── docker.ps1
│ ├── wsl.ps1 
│ └── wsl-post-restart.ps1
├── instalar.bat # Script principal con menú interactivo. 
├── aplicaciones.json # Fichero de configuración para la instalación de software. 
└── README.md # Este fichero.```

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

### 3. Configurar Scripts (Opcional)
Usuarios: Para cambiar la lista de usuarios a crear, edita el fichero script/cuentas-usuario.ps1.
Red: Para ajustar los valores de red por defecto (IP base, puerta de enlace, DNS), edita el fichero script/cambiar-ip.ps1.

### 4. Ejecutar los Scripts

Haz clic derecho sobre instalar.bat y selecciona "Ejecutar como administrador". El script detectará si no tiene privilegios y los solicitará.
Aparecerá un menú en la consola con las siguientes opciones:
1 - Configurar Sistema (Zona Horaria, PSRemoting)
2 - Configurar direccion de red estatica
3 - Crear cuentas de usuario
4 - Instalar aplicaciones
5 - Ejecutar todas las tareas (ejecuta las 4 anteriores en orden)
6 - Salir
Selecciona la opción deseada y presiona ENTER.
Una vez que la tarea finalice, puedes elegir otra opción del menú o salir.

## Funcionamiento de la Configuración de Red

El script `2-cambiar-ip.bat` lanza un script de PowerShell (`2-cambiar-ip.ps1`) que está diseñado para aulas donde los equipos siguen un patrón de nomenclatura, como `AULA1-PC01`, `AULA1-PC02`, etc.

*   **Cálculo Automático:** El script calcula automáticamente la dirección IP basándose en los dos últimos dígitos numéricos del nombre del equipo, más el valor Base indicado
    *   *Ejemplo:* Si el `hostname` es `AULA1-PC07` y la configuración base es `192.168.150.50`, la IP resultante será `192.168.150.57` (50 + 7).
*   **Confirmación Interactiva:** Antes de aplicar cualquier cambio, el script muestra la configuración que va a aplicar y pide una confirmación rápida (S/N).
*   **Flexibilidad:** Los valores de red por defecto (IP base, puerta de enlace, DNS) se pueden modificar fácilmente al principio del fichero `2-cambiar-ip.ps1`.
