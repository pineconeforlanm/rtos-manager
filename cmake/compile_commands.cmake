# ============================================================================
#  compile_commands.cmake — export compile_commands.json and expose it at the
#  source root so clangd / other LSP servers index the project regardless of
#  the active preset.
# ============================================================================

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Re-create the link every configure so switching presets (debug <-> release,
# which point the link at different build dirs) never trips CREATE_LINK on an
# already-existing symlink.
file(REMOVE "${CMAKE_SOURCE_DIR}/compile_commands.json")
file(CREATE_LINK "${CMAKE_BINARY_DIR}/compile_commands.json"
     "${CMAKE_SOURCE_DIR}/compile_commands.json" SYMBOLIC)
