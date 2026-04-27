# Blender MCP Workflow

Este proyecto usara `ahujasid/blender-mcp` como puente entre el agente y Blender.

## Por que este MCP

- Tiene addon propio para Blender y servidor MCP por `uvx blender-mcp`.
- Permite inspeccionar escenas, tomar screenshots del viewport y ejecutar Python en Blender.
- Es una buena base para crear props, enemigos, armas y piezas del menu, y despues exportarlas a Godot.

## Requisitos locales

Estado actual en esta maquina:

- `uv` y `uvx` ya quedaron instalados en `C:\Users\david\.local\bin`.
- Blender todavia no aparece en `PATH` ni en las rutas estandar consultadas desde terminal.

1. Comprobar `uvx` en una terminal nueva:

```powershell
uvx --version
```

2. Si no aparece, agregar `uv` al PATH del usuario:

```powershell
$localBin = "$env:USERPROFILE\.local\bin"
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
[Environment]::SetEnvironmentVariable("Path", "$userPath;$localBin", "User")
```

3. Resolver Blender con el helper del repo:

```powershell
.\tools\blender-mcp\find-blender.ps1
```

4. Instalar y activar el addon en Blender:

```powershell
.\tools\blender-mcp\install-addon.ps1 -BlenderPath "C:\ruta\a\blender.exe"
```

Si `find-blender.ps1` devuelve una ruta valida, puedes reutilizarla aqui.

El script descarga `addon.py` desde upstream, lo instala, lo habilita y guarda las preferencias de Blender.

5. Abrir Blender con el servidor MCP levantado automaticamente:

```powershell
.\tools\blender-mcp\start-blender-mcp.ps1
```

## Conexion

1. Ejecutar `start-blender-mcp.ps1` o abrir Blender manualmente.
2. Si abriste Blender manualmente: abrir la barra lateral del viewport con `N`.
3. Entrar en la pestana `BlenderMCP`.
4. Verificar que el puerto sea `9876`.
5. Si no arrancaste con el script, pulsar `Connect to Claude`.
6. En VS Code, arrancar el servidor MCP `blender` desde la configuracion del workspace en `.vscode/mcp.json`.

La configuracion usa:

```json
{
  "command": "cmd",
  "args": ["/c", "uvx", "blender-mcp"]
}
```

## Flujo para traer modelos a Godot

1. Crear o modificar el modelo en Blender via MCP.
2. Guardar el archivo `.blend` en `assets/models/source/`.
3. Exportar a `.glb` hacia `assets/models/generated/`.
4. Revisar el `.glb` en Godot.
5. Instanciar el modelo en una escena bajo `scenes/characters/`, `scenes/weapons/` o `scenes/world/`.

## Export recomendado

Usar export headless cuando el modelo este listo, no el MCP, porque exportar GLTF desde MCP puede tardar demasiado.

```powershell
.\tools\blender-mcp\export-glb.ps1 \
  -BlendFile .\assets\models\source\modelo.blend \
  -OutputFile .\assets\models\generated\modelo.glb \
  -BlenderPath "C:\ruta\a\blender.exe"
```

Si quieres evitar pasar la ruta cada vez, define `BLENDER_EXE` en tu entorno de usuario.

## Reglas para assets del juego

- Usar escala realista: 1 unidad de Blender = 1 metro de Godot.
- Nombrar objetos con prefijos claros: `CHR_`, `WPN_`, `ENV_`, `PROP_`.
- Mantener pivots limpios en pies, manos, armas y puntos de montaje.
- Evitar materiales procedurales complejos si deben sobrevivir al GLB; bakear texturas si hace falta.
- Para rigs animados, mantener acciones separadas: `idle`, `walk`, `run`, `attack`, `death`.
- Exportar luces y camaras solo si la escena de Godot realmente las necesita.
