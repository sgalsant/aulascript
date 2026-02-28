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
├── script/ # Contiene toda la lógica de PowerShell centralizada. 
│ ├── cambiar-ip.ps1
│ ├── configurar-psremoting.ps1
│ ├── cuentas-usuario.ps1
│ ├── instalar-aplicaciones.ps1
│ └── utils.ps1 # Herramientas de utilidad compartida (ej. Write-AulaLog).
├── postscript/ # Scripts a ejecutar tras una instalación específica. 
│ ├── docker.ps1
│ ├── virtualbox-ext.ps1
│ └── wsl-post-restart.ps1
├── instalar.bat # Wrapper para solicitar privilegios de administrador.
├── instalar.ps1 # Script principal con el menú interactivo.
├── Start-LabSession.ps1 # Herramienta de despliegue automático hacia la VM.
├── aplicaciones.json # Fichero de configuración para software. 
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

Haz clic derecho sobre `instalar.bat` y selecciona "Ejecutar como administrador". El script detectará si no tiene privilegios, los solicitará, y abrirá una nueva ventana de PowerShell de forma segura.

Aparecerá un menú en la consola con las siguientes opciones:
 1 - Configurar Sistema (Zona Horaria, PSRemoting)
 2 - Configurar dirección de red estática
 3 - Crear cuentas de usuario
 4 - Instalar aplicaciones
 5 - Ejecutar todas las tareas (1-4)
 0 - Salir
=============================================
 6 - Crear menú de arranque con opciones de hyperv (beta)
 7 - Instalar extensión de virtualbox

Selecciona la opción deseada y presiona ENTER.

### 5. Preparar la Máquina Virtual de Pruebas (VM-Aula)

Para utilizar el script de pruebas automatizadas, necesitas configurar previamente una máquina virtual en tu Hyper-V local que cumpla con los requisitos del Orquestador (`Start-LabSession.ps1`).

**1. Instalación y Usuario Administrador**
Instala Windows (idealmente Windows 10 u 11 Pro/Enterprise) en la máquina virtual. Nómbrala en Hyper-V (por ejemplo, `VM-Aula`).
Durante la instalación, crea una cuenta de usuario local que sea Administrador.
*Importante*: Anota bien el nombre de ese usuario y su contraseña, ya que el script Orquestador te los pedirá para poder entrar por la puerta trasera.

**2. Abrir las puertas de PowerShell (Dentro de la VM)**
Inicia sesión en la máquina virtual, abre PowerShell como Administrador y ejecuta este comando para que acepte órdenes desde tu máquina física a través de PowerShell Direct o red:
```powershell
Enable-PSRemoting -Force
```

**3. Habilitar los "Servicios de invitado" (En Hyper-V)**
Esto es vital para que tu máquina física pueda "inyectar" la carpeta de tu proyecto dentro de la VM sin usar red.
1. Apaga la máquina virtual.
2. En el Administrador de Hyper-V, haz clic derecho sobre la VM y ve a **Configuración**.
3. En el menú izquierdo, busca **Servicios de integración**.
4. En la lista de la derecha, marca la casilla **Servicios de invitado (Guest Services)**. Guarda los cambios.

**4. Crear el ancla: El Punto de Control "Base"**
Este es el paso que vuelve a tu VM indestructible.
1. Enciende la máquina virtual y déjala en la pantalla del escritorio, lista para usar.
2. En el Administrador de Hyper-V, haz clic derecho sobre la VM y selecciona **Punto de control (Checkpoint)**.
3. Haz clic derecho sobre el punto de control que se acaba de crear, dale a **Cambiar nombre** y llámalo **explicítamente** `Base`.

¡Y listo! Con esto tienes una cápsula de pruebas perfecta. Cada vez que tu script Orquestador se ejecute, volverá a ese punto Base en segundos, con los puertos de PowerShell abiertos y esperando tus scripts.

### 6. Pruebas Automatizadas en Hyper-V (Laboratorio)

Para probar los scripts en un entorno seguro antes de pasarlos a los ordenadores reales, el proyecto incluye un script de despliegue automatizado para Hyper-V (`Start-LabSession.ps1`). Esta herramienta es ideal para validarlos de la siguiente manera:

1. Abre **PowerShell como Administrador** en tu ordenador anfitrión y navega a la carpeta del proyecto.
2. Ejecuta `.\Start-LabSession.ps1`.
3. El script restaurará un "snapshot" base de tu máquina virtual (por defecto `VM-Aula`), la encenderá, y **copiará automáticamente los scripts recientes** omitiendo la pesada carpeta `repo` usando el VMBus de PowerShell Direct (`C:\aulascript`).
4. Al acabar, abrirá una sesión remota interactiva en la VM (`Invoke-Command`) y ejecutará el menú de instalación (`instalar.ps1`) directamente en tu pantalla, sin necesidad de que interacciones visualmente con la máquina virtual. Todo lo que teclees sucederá directamente como administrador en el invitado remoto de forma transparente.

## Funcionamiento de la Configuración de Red

El script de red interactivo (`script\cambiar-ip.ps1`) está diseñado para aulas donde los equipos siguen un patrón de nomenclatura, como `AULA1-PC01`, `AULA1-PC02`, etc.

*   **Cálculo Automático:** El script calcula automáticamente la dirección IP basándose en los dos últimos dígitos numéricos del nombre del equipo, más el valor Base indicado
    *   *Ejemplo:* Si el `hostname` es `AULA1-PC07` y la configuración base es `192.168.150.50`, la IP resultante será `192.168.150.57` (50 + 7).
*   **Confirmación Interactiva:** Antes de aplicar cualquier cambio, el script muestra la configuración que va a aplicar y pide una confirmación rápida (S/N).
*   **Flexibilidad:** Los valores de red por defecto (IP base, puerta de enlace, DNS) se pueden modificar fácilmente al principio del fichero `2-cambiar-ip.ps1`.
