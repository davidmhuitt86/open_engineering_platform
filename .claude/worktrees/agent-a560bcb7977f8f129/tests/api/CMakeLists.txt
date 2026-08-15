add_executable(oep_api_tests oep_api_tests.cpp)
target_link_libraries(oep_api_tests PRIVATE oep_api oep_repository)
add_test(NAME oep_api_tests COMMAND oep_api_tests)
