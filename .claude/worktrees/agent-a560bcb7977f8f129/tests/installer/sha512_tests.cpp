#include "oep/installer/sha512.hpp"

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
    const std::array<std::uint8_t, 64> digest =
        oep::installer::sha512(std::vector<std::uint8_t>(text.begin(), text.end()));
    static constexpr char kHexDigits[] = "0123456789abcdef";
    std::string hex;
    hex.reserve(128);
    for (const std::uint8_t byte : digest) {
        hex.push_back(kHexDigits[byte >> 4]);
        hex.push_back(kHexDigits[byte & 0x0F]);
    }
    return hex;
}

// FIPS 180-4 / NIST published test vectors.
void test_known_vectors() {
    check(hash_text("") ==
              "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce"
              "47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e",
          "sha512('') matches the known empty-input digest");
    check(hash_text("abc") ==
              "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a"
              "2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f",
          "sha512('abc') matches the known digest");
    check(hash_text("abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmno"
                     "ijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu") ==
              "8e959b75dae313da8cf4f72814fc143f8f7779c6eb9f7fa17299aeadb6889018"
              "501d289e4900f7e4331b99dec4b5433ac7d329eeb6dd26545e96e55b874be909",
          "sha512 of the standard two-block test vector matches the known digest");
}

void test_different_inputs_produce_different_digests() {
    check(hash_text("a") != hash_text("b"), "different inputs produce different digests");
}

} // namespace

int main() {
    test_known_vectors();
    test_different_inputs_produce_different_digests();

    if (g_failures == 0) {
        std::cout << "All sha512 tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " sha512 test(s) failed.\n";
    return 1;
}
