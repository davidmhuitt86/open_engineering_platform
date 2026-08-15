#include "oep/installer/sha256.hpp"

#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

namespace {

int g_failures = 0;

void check(bool condition, const std::string& description) {
    if (!condition) {
        std::cerr << "FAIL: " << description << "\n";
        ++g_failures;
    }
}

std::string hash_text(const std::string& text) {
    return oep::installer::sha256_hex(std::vector<std::uint8_t>(text.begin(), text.end()));
}

// FIPS 180-4 / NIST published test vectors, so correctness is checked
// against a known-good reference rather than only self-consistency.
void test_known_vectors() {
    check(hash_text("") == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
          "sha256_hex('') matches the known empty-input digest");
    check(hash_text("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
          "sha256_hex('abc') matches the known digest");
    check(hash_text("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq") ==
              "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1",
          "sha256_hex of the standard two-block test vector matches the known digest");
}

void test_output_is_64_lowercase_hex_characters() {
    const std::string digest = hash_text("Repository Registry");
    check(digest.size() == 64, "sha256_hex always returns 64 hex characters");
    bool all_lowercase_hex = true;
    for (const char c : digest) {
        const bool is_digit = c >= '0' && c <= '9';
        const bool is_lower_hex = c >= 'a' && c <= 'f';
        if (!is_digit && !is_lower_hex) {
            all_lowercase_hex = false;
            break;
        }
    }
    check(all_lowercase_hex, "sha256_hex output is entirely lowercase hex digits");
}

void test_different_inputs_produce_different_digests() {
    check(hash_text("engineering-demo.oep v1") != hash_text("engineering-demo.oep v2"),
          "different inputs produce different digests");
}

void test_sha256_hex_file_matches_in_memory_hash() {
    const std::filesystem::path scratch =
        std::filesystem::temp_directory_path() / "oep_sha256_tests" / "sample.bin";
    std::filesystem::create_directories(scratch.parent_path());
    {
        std::ofstream file(scratch, std::ios::binary | std::ios::trunc);
        file << "sample archive bytes";
    }

    const std::optional<std::string> from_file = oep::installer::sha256_hex_file(scratch);
    check(from_file.has_value(), "sha256_hex_file succeeds for an existing file");
    if (from_file.has_value()) {
        check(*from_file == hash_text("sample archive bytes"),
              "sha256_hex_file agrees with sha256_hex over the same bytes");
    }

    std::filesystem::remove_all(scratch.parent_path());
}

void test_sha256_hex_file_fails_for_a_missing_file() {
    const std::optional<std::string> result =
        oep::installer::sha256_hex_file(std::filesystem::temp_directory_path() / "oep_sha256_tests_missing.bin");
    check(!result.has_value(), "sha256_hex_file returns nullopt for a nonexistent file");
}

} // namespace

int main() {
    test_known_vectors();
    test_output_is_64_lowercase_hex_characters();
    test_different_inputs_produce_different_digests();
    test_sha256_hex_file_matches_in_memory_hash();
    test_sha256_hex_file_fails_for_a_missing_file();

    if (g_failures == 0) {
        std::cout << "All sha256 tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " sha256 test(s) failed.\n";
    return 1;
}
