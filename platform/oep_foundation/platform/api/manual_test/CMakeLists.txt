# Standalone Public C API manual verification program (Work Package
# 014). Compiled as plain C (not C++) from a translation unit that
# includes only oep_api.h, to demonstrate the Public C API is a real,
# consumable C ABI. The final link step uses the C++ linker because
# oep_api.lib is itself implemented in C++ (its extern "C" symbols are
# C-linkage, but the C++ runtime it depends on must still be linked
# in) — the source remains plain C either way.
add_executable(oep_capi_manual_test capi_manual_test.c)
target_link_libraries(oep_capi_manual_test PRIVATE oep_api)
set_target_properties(oep_capi_manual_test PROPERTIES LINKER_LANGUAGE CXX)
