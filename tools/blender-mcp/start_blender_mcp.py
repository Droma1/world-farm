import sys

import bpy
import addon


def parse_port(argv: list[str]) -> int:
    if "--" not in argv:
        return 9876

    index = argv.index("--") + 1
    if index >= len(argv):
        return 9876

    try:
        return int(argv[index])
    except ValueError:
        return 9876


port = parse_port(sys.argv)

bpy.ops.preferences.addon_enable(module="addon")
bpy.context.scene.blendermcp_port = port

if not hasattr(bpy.types, "blendermcp_server") or not bpy.types.blendermcp_server:
    bpy.types.blendermcp_server = addon.BlenderMCPServer(host="localhost", port=port)

bpy.types.blendermcp_server.start()
bpy.context.scene.blendermcp_server_running = True

print(f"Blender MCP server started on port {port}")