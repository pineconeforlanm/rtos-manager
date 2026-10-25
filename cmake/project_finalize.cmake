# ============================================================================
#  project_finalize.cmake — everything that must run after the targets.
#
#  Included as the very last line of the top-level CMakeLists.txt:
#    1. packaging — CPack must see every install() rule declared above
#    2. summary   — reported values are final by now
# ============================================================================

# --- Packaging (systemd unit + CPack DEB) -----------------------------------
include(packaging)

# --- Configure summary ------------------------------------------------------
include(summary)
rtos_print_build_summary()
