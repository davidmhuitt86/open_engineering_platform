add_executable(oep_acquisition
  main.cpp
)

target_link_libraries(oep_acquisition
  PRIVATE
    oep_acquisition_common
    oep_acquisition_database
    oep_acquisition_registry
    oep_acquisition_jobs
    oep_acquisition_connectors
    oep_acquisition_downloads
    oep_acquisition_integrity
    oep_acquisition_metadata
    oep_acquisition_api
)

target_compile_features(oep_acquisition PRIVATE cxx_std_23)
