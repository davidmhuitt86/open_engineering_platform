add_library(oep_acquisition_jobs STATIC
  acquisition_job.cpp
  acquisition_job_json.cpp
  validation.cpp
  acquisition_job_service.cpp
  postgres_acquisition_job_repository.cpp
  acquisition_execution.cpp
  acquisition_execution_json.cpp
  acquisition_execution_service.cpp
  postgres_job_execution_history_repository.cpp
)

target_include_directories(oep_acquisition_jobs
  PUBLIC
    ${CMAKE_SOURCE_DIR}/include
)

target_link_libraries(oep_acquisition_jobs
  PUBLIC
    oep_acquisition_common
    oep_acquisition_registry
    nlohmann_json::nlohmann_json
  PRIVATE
    libpqxx::pqxx
)

target_compile_features(oep_acquisition_jobs PUBLIC cxx_std_23)
