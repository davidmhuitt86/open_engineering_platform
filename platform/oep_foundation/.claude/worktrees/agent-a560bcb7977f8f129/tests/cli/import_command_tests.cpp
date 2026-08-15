#include "commands/export_command.hpp"
#include "commands/import_command.hpp"
#include "commands/object_command.hpp"
#include "generator/repository_generator.hpp"

#include <filesystem>
#include <fstream>
#include <functional>
#include <iostream>
#include <sstream>
#include <string>

namespace {

int g_failures = 0;

void check(bool condition, const std::string& description) {
    if (!condition) {
        std::cerr << "FAIL: " << description << "\n";
        ++g_failures;
    }
}

std::string capture_stdout(const std::function<void()>& action) {
    std::ostringstream buffer;
    std::streambuf* original = std::cout.rdbuf(buffer.rdbuf());
    action();
    std::cout.rdbuf(original);
    return buffer.str();
}

std::string capture_stderr(const std::function<void()>& action) {
    std::ostringstream buffer;
    std::streambuf* original = std::cerr.rdbuf(buffer.rdbuf());
    action();
    std::cerr.rdbuf(original);
    return buffer.str();
}

bool contains(const std::string& haystack, const std::string& needle) {
    return haystack.find(needle) != std::string::npos;
}

std::filesystem::path build_repository(const std::filesystem::path& parent, const std::string& name) {
    const oep::cli::generator::GenerationResult result =
        oep::cli::generator::generate_foundation_repository(parent / name, name);
    check(result.success, "generating a sample repository for import command tests succeeds");
    return parent / name;
}

void write_raw(const std::filesystem::path& path, const std::string& contents) {
    std::filesystem::create_directories(path.parent_path());
    std::ofstream file(path, std::ios::binary | std::ios::trunc);
    file << contents;
}

void test_import_round_trips_a_real_export(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path source_repo = build_repository(scratch_dir, "roundtrip-source");

    oep::cli::commands::ObjectCommand object_command;
    capture_stdout([&] {
        object_command.execute(
            {"create", "--type", "Component", "--name", "Coil", "--repository", source_repo.string()});
    });

    const std::filesystem::path archive_path = scratch_dir / "roundtrip.json";
    oep::cli::commands::ExportCommand export_command;
    const int export_exit =
        [&] { return export_command.execute({archive_path.string(), "--repository", source_repo.string()}); }();
    check(export_exit == 0, "export succeeds ahead of the import round-trip test");

    const std::filesystem::path destination = scratch_dir / "roundtrip-destination";
    oep::cli::commands::ImportCommand import_command;
    int import_exit = 0;
    const std::string output = capture_stdout([&] {
        import_exit =
            import_command.execute({archive_path.string(), "--destination", destination.string()});
    });

    check(import_exit == 0, "import succeeds for a valid archive");
    check(contains(output, "Objects:       1"), "import reports the restored object count");
    check(std::filesystem::exists(destination / "repository.json"), "import creates repository.json");

    oep::cli::commands::ObjectCommand list_command;
    const std::string list_output = capture_stdout([&] {
        list_command.execute({"list", "--repository", destination.string()});
    });
    check(contains(list_output, "Coil"), "the imported repository contains the original object");
}

void test_import_requires_archive_file() {
    oep::cli::commands::ImportCommand command;
    int exit_code = 0;
    const std::string error_output = capture_stderr([&] { exit_code = command.execute({}); });

    check(exit_code != 0, "import fails when no archive file is given");
    check(!error_output.empty(), "import reports a descriptive error when no archive file is given");
}

void test_import_rejects_existing_destination_without_overwrite(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path source_repo = build_repository(scratch_dir, "overwrite-source");
    const std::filesystem::path archive_path = scratch_dir / "overwrite.json";

    oep::cli::commands::ExportCommand export_command;
    export_command.execute({archive_path.string(), "--repository", source_repo.string()});

    const std::filesystem::path destination = scratch_dir / "overwrite-destination";
    oep::cli::commands::ImportCommand import_command;
    check(import_command.execute({archive_path.string(), "--destination", destination.string()}) == 0,
          "the first import into a fresh destination succeeds");

    int second_exit = 0;
    const std::string error_output = capture_stderr([&] {
        second_exit = import_command.execute({archive_path.string(), "--destination", destination.string()});
    });
    check(second_exit != 0, "importing into the same destination without --overwrite fails");
    check(contains(error_output, "overwrite"), "the error mentions --overwrite");

    const int overwrite_exit =
        import_command.execute({archive_path.string(), "--destination", destination.string(), "--overwrite"});
    check(overwrite_exit == 0, "importing into the same destination with --overwrite succeeds");
}

void test_import_rejects_invalid_archive(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path bad_archive = scratch_dir / "bad-archive.json";
    write_raw(bad_archive, "not json at all");

    oep::cli::commands::ImportCommand command;
    int exit_code = 0;
    const std::string error_output = capture_stderr([&] {
        exit_code = command.execute({bad_archive.string(), "--destination", (scratch_dir / "bad-dest").string()});
    });

    check(exit_code != 0, "import fails for an invalid archive");
    check(!error_output.empty(), "import reports a descriptive error for an invalid archive");
}

void test_import_rejects_missing_archive_file(const std::filesystem::path& scratch_dir) {
    oep::cli::commands::ImportCommand command;
    int exit_code = 0;
    capture_stderr([&] {
        exit_code = command.execute({(scratch_dir / "does-not-exist.json").string(), "--destination",
                                      (scratch_dir / "missing-dest").string()});
    });

    check(exit_code != 0, "import fails when the archive file does not exist");
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir = std::filesystem::temp_directory_path() / "oep_import_command_tests";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_import_round_trips_a_real_export(scratch_dir);
    test_import_requires_archive_file();
    test_import_rejects_existing_destination_without_overwrite(scratch_dir);
    test_import_rejects_invalid_archive(scratch_dir);
    test_import_rejects_missing_archive_file(scratch_dir);

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All import command tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " import command test(s) failed.\n";
    return 1;
}
