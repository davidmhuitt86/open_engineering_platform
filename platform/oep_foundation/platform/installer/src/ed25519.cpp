#include "oep/installer/ed25519.hpp"

#include <cstddef>
#include <string>

#include "oep/installer/sha512.hpp"

namespace oep::installer {

namespace {

// ------------------------------------------------------------------
// 256-bit field elements modulo p = 2^255 - 19, as 8 little-endian
// 32-bit limbs. All arithmetic is plain schoolbook with 64-bit
// intermediate products — slow, portable, and easy to audit; package
// verification runs once per install, so speed is irrelevant.
// ------------------------------------------------------------------

using Fe = std::array<std::uint32_t, 8>;

Fe fe_from_hex(const char* hex) {
    // Big-endian hex string (64 chars) -> little-endian limbs.
    Fe result{};
    for (int i = 0; i < 64; ++i) {
        const char c = hex[i];
        const std::uint32_t nibble = c >= '0' && c <= '9'   ? static_cast<std::uint32_t>(c - '0')
                                     : c >= 'a' && c <= 'f' ? static_cast<std::uint32_t>(c - 'a' + 10)
                                                             : static_cast<std::uint32_t>(c - 'A' + 10);
        const int limb = (63 - i) / 8;
        result[static_cast<std::size_t>(limb)] |= nibble << (((63 - i) % 8) * 4);
    }
    return result;
}

const Fe& fe_p() {
    static const Fe p = fe_from_hex("7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffed");
    return p;
}

const Fe& fe_d() {
    static const Fe d = fe_from_hex("52036cee2b6ffe738cc740797779e89800700a4d4141d8ab75eb4dca135978a3");
    return d;
}

const Fe& fe_sqrt_minus_one() {
    static const Fe s = fe_from_hex("2b8324804fc1df0b2b4d00993dfbd7a72f431806ad2fe478c4ee1b274a0ea0b0");
    return s;
}

// The group order L = 2^252 + 27742317777372353535851937790883648493.
const Fe& scalar_l() {
    static const Fe l = fe_from_hex("1000000000000000000000000000000014def9dea2f79cd65812631a5cf5d3ed");
    return l;
}

bool fe_greater_equal(const Fe& a, const Fe& b) {
    for (int i = 7; i >= 0; --i) {
        if (a[static_cast<std::size_t>(i)] != b[static_cast<std::size_t>(i)]) {
            return a[static_cast<std::size_t>(i)] > b[static_cast<std::size_t>(i)];
        }
    }
    return true; // equal
}

bool fe_is_zero(const Fe& a) {
    for (const std::uint32_t limb : a) {
        if (limb != 0) return false;
    }
    return true;
}

// a -= b, assuming a >= b.
void fe_sub_raw(Fe& a, const Fe& b) {
    std::int64_t borrow = 0;
    for (std::size_t i = 0; i < 8; ++i) {
        std::int64_t diff = static_cast<std::int64_t>(a[i]) - static_cast<std::int64_t>(b[i]) - borrow;
        borrow = 0;
        if (diff < 0) {
            diff += 0x100000000LL;
            borrow = 1;
        }
        a[i] = static_cast<std::uint32_t>(diff);
    }
}

Fe fe_add(const Fe& a, const Fe& b) {
    Fe r{};
    std::uint64_t carry = 0;
    for (std::size_t i = 0; i < 8; ++i) {
        const std::uint64_t sum = static_cast<std::uint64_t>(a[i]) + b[i] + carry;
        r[i] = static_cast<std::uint32_t>(sum);
        carry = sum >> 32;
    }
    // 2^256 ≡ 38 (mod p): fold any carry back in, then normalize.
    while (carry != 0) {
        std::uint64_t fold = carry * 38;
        carry = 0;
        for (std::size_t i = 0; i < 8 && fold != 0; ++i) {
            const std::uint64_t sum = static_cast<std::uint64_t>(r[i]) + (fold & 0xFFFFFFFFULL);
            r[i] = static_cast<std::uint32_t>(sum);
            fold = (fold >> 32) + (sum >> 32);
        }
        carry = fold;
    }
    while (fe_greater_equal(r, fe_p())) {
        fe_sub_raw(r, fe_p());
    }
    return r;
}

Fe fe_sub(const Fe& a, const Fe& b) {
    // a - b mod p, for a, b already reduced: add p first if a < b.
    Fe r = a;
    if (!fe_greater_equal(r, b)) {
        // r += p (cannot overflow 256 bits since r < p and p < 2^255).
        std::uint64_t carry = 0;
        for (std::size_t i = 0; i < 8; ++i) {
            const std::uint64_t sum = static_cast<std::uint64_t>(r[i]) + fe_p()[i] + carry;
            r[i] = static_cast<std::uint32_t>(sum);
            carry = sum >> 32;
        }
    }
    fe_sub_raw(r, b);
    return r;
}

Fe fe_mul(const Fe& a, const Fe& b) {
    // Schoolbook 8x8 -> 16 limbs, with running carries. Each step
    // computes r + a[i]*b[j] + carry, whose maximum is exactly 2^64 - 1.
    std::array<std::uint32_t, 16> t{};
    for (std::size_t i = 0; i < 8; ++i) {
        std::uint64_t carry = 0;
        for (std::size_t j = 0; j < 8; ++j) {
            const std::uint64_t sum = static_cast<std::uint64_t>(t[i + j]) +
                                       static_cast<std::uint64_t>(a[i]) * b[j] + carry;
            t[i + j] = static_cast<std::uint32_t>(sum);
            carry = sum >> 32;
        }
        t[i + 8] = static_cast<std::uint32_t>(carry);
    }

    // Fold the high half: 2^256 ≡ 38 (mod p).
    Fe r{};
    std::uint64_t carry = 0;
    for (std::size_t i = 0; i < 8; ++i) {
        const std::uint64_t sum = static_cast<std::uint64_t>(t[i]) +
                                   static_cast<std::uint64_t>(t[i + 8]) * 38 + carry;
        r[i] = static_cast<std::uint32_t>(sum);
        carry = sum >> 32;
    }
    while (carry != 0) {
        std::uint64_t fold = carry * 38;
        carry = 0;
        for (std::size_t i = 0; i < 8 && fold != 0; ++i) {
            const std::uint64_t sum = static_cast<std::uint64_t>(r[i]) + (fold & 0xFFFFFFFFULL);
            r[i] = static_cast<std::uint32_t>(sum);
            fold = (fold >> 32) + (sum >> 32);
        }
        carry = fold;
    }
    while (fe_greater_equal(r, fe_p())) {
        fe_sub_raw(r, fe_p());
    }
    return r;
}

// base^exponent mod p, square-and-multiply, most significant bit first.
Fe fe_pow(const Fe& base, const Fe& exponent) {
    Fe result{};
    result[0] = 1;
    for (int bit = 255; bit >= 0; --bit) {
        result = fe_mul(result, result);
        const std::size_t limb = static_cast<std::size_t>(bit / 32);
        if ((exponent[limb] >> (bit % 32)) & 1) {
            result = fe_mul(result, base);
        }
    }
    return result;
}

Fe fe_invert(const Fe& a) {
    // p - 2 = ...ffeb.
    static const Fe p_minus_2 =
        fe_from_hex("7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeb");
    return fe_pow(a, p_minus_2);
}

// ------------------------------------------------------------------
// Curve points in extended twisted-Edwards coordinates (X:Y:Z:T),
// with one unified addition formula used for both add and double.
// ------------------------------------------------------------------

struct Point {
    Fe x{};
    Fe y{};
    Fe z{};
    Fe t{};
};

Point point_identity() {
    Point p;
    p.y[0] = 1;
    p.z[0] = 1;
    return p;
}

const Fe& fe_2d() {
    static const Fe two_d = fe_add(fe_d(), fe_d());
    return two_d;
}

Point point_add(const Point& p, const Point& q) {
    // Unified addition (Hisil et al., a = -1): correct for doubling too.
    const Fe a = fe_mul(fe_sub(p.y, p.x), fe_sub(q.y, q.x));
    const Fe b = fe_mul(fe_add(p.y, p.x), fe_add(q.y, q.x));
    const Fe c = fe_mul(fe_mul(p.t, fe_2d()), q.t);
    const Fe d = fe_add(fe_mul(p.z, q.z), fe_mul(p.z, q.z));
    const Fe e = fe_sub(b, a);
    const Fe f = fe_sub(d, c);
    const Fe g = fe_add(d, c);
    const Fe h = fe_add(b, a);

    Point r;
    r.x = fe_mul(e, f);
    r.y = fe_mul(g, h);
    r.t = fe_mul(e, h);
    r.z = fe_mul(f, g);
    return r;
}

// scalar is 8 little-endian 32-bit limbs (a value < L, so < 2^253).
Point point_scalar_mul(const Fe& scalar, const Point& p) {
    Point result = point_identity();
    for (int bit = 255; bit >= 0; --bit) {
        result = point_add(result, result);
        const std::size_t limb = static_cast<std::size_t>(bit / 32);
        if ((scalar[limb] >> (bit % 32)) & 1) {
            result = point_add(result, p);
        }
    }
    return result;
}

bool point_equal(const Point& p, const Point& q) {
    // Compare affine coordinates without dividing: X1*Z2 == X2*Z1, etc.
    const Fe x_cross_1 = fe_mul(p.x, q.z);
    const Fe x_cross_2 = fe_mul(q.x, p.z);
    const Fe y_cross_1 = fe_mul(p.y, q.z);
    const Fe y_cross_2 = fe_mul(q.y, p.z);
    return fe_is_zero(fe_sub(x_cross_1, x_cross_2)) && fe_is_zero(fe_sub(y_cross_1, y_cross_2));
}

// RFC 8032 §5.1.3 point decompression. Returns false for an invalid
// encoding (y >= p, or no square root exists).
bool point_decompress(const std::array<std::uint8_t, 32>& encoded, Point& out) {
    Fe y{};
    for (std::size_t i = 0; i < 32; ++i) {
        y[i / 4] |= static_cast<std::uint32_t>(encoded[i]) << ((i % 4) * 8);
    }
    const int x_sign = (encoded[31] >> 7) & 1;
    y[7] &= 0x7FFFFFFF;
    if (fe_greater_equal(y, fe_p())) {
        return false;
    }

    Fe one{};
    one[0] = 1;
    const Fe y_squared = fe_mul(y, y);
    const Fe u = fe_sub(y_squared, one);            // y^2 - 1
    const Fe v = fe_add(fe_mul(fe_d(), y_squared), one); // d*y^2 + 1

    // Candidate root: x = u * v^3 * (u * v^7)^((p-5)/8).
    static const Fe p_minus_5_over_8 =
        fe_from_hex("0ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd");
    const Fe v3 = fe_mul(fe_mul(v, v), v);
    const Fe v7 = fe_mul(fe_mul(v3, v3), v);
    Fe x = fe_mul(fe_mul(u, v3), fe_pow(fe_mul(u, v7), p_minus_5_over_8));

    const Fe vxx = fe_mul(v, fe_mul(x, x));
    if (!fe_is_zero(fe_sub(vxx, u))) {
        if (fe_is_zero(fe_add(vxx, fe_sub(fe_p(), u))) || fe_is_zero(fe_sub(vxx, fe_sub(fe_p(), u)))) {
            // v*x^2 == -u: multiply by sqrt(-1).
            x = fe_mul(x, fe_sqrt_minus_one());
        } else {
            return false;
        }
    }
    // Re-check (covers both branches uniformly).
    if (!fe_is_zero(fe_sub(fe_mul(v, fe_mul(x, x)), u))) {
        return false;
    }

    if (fe_is_zero(x) && x_sign == 1) {
        return false;
    }
    if (static_cast<int>(x[0] & 1) != x_sign) {
        x = fe_sub(fe_p(), x);
    }

    out.x = x;
    out.y = y;
    out.z = Fe{};
    out.z[0] = 1;
    out.t = fe_mul(x, y);
    return true;
}

const Point& base_point() {
    // The standard base point B, decompressed once from its canonical
    // encoding (y = 4/5, x sign 0).
    static const Point b = [] {
        std::array<std::uint8_t, 32> encoded{};
        encoded[0] = 0x58;
        for (std::size_t i = 1; i < 32; ++i) {
            encoded[i] = 0x66;
        }
        Point p;
        const bool ok = point_decompress(encoded, p);
        (void)ok; // the canonical encoding always decompresses
        return p;
    }();
    return b;
}

// Reduces a 512-bit little-endian value modulo L by binary long
// division — 512 shift-and-conditionally-subtract steps. Slow and
// obviously correct.
Fe reduce_mod_l(const std::array<std::uint8_t, 64>& wide) {
    Fe r{};
    for (int bit = 511; bit >= 0; --bit) {
        // r = (r << 1) | bit. r stays < 2L < 2^254, so no limb overflow.
        std::uint32_t carry = 0;
        for (std::size_t i = 0; i < 8; ++i) {
            const std::uint32_t next_carry = r[i] >> 31;
            r[i] = (r[i] << 1) | carry;
            carry = next_carry;
        }
        const std::size_t byte = static_cast<std::size_t>(bit / 8);
        if ((wide[byte] >> (bit % 8)) & 1) {
            r[0] |= 1;
        }
        if (fe_greater_equal(r, scalar_l())) {
            fe_sub_raw(r, scalar_l());
        }
    }
    return r;
}

} // namespace

bool ed25519_verify(const std::vector<std::uint8_t>& message, const std::array<std::uint8_t, 32>& public_key,
                     const std::array<std::uint8_t, 64>& signature) {
    // Split the signature: R (encoded point) || S (little-endian scalar).
    std::array<std::uint8_t, 32> r_encoded{};
    Fe s{};
    for (std::size_t i = 0; i < 32; ++i) {
        r_encoded[i] = signature[i];
        s[i / 4] |= static_cast<std::uint32_t>(signature[32 + i]) << ((i % 4) * 8);
    }

    // RFC 8032: reject S >= L (prevents signature malleability).
    if (fe_greater_equal(s, scalar_l())) {
        return false;
    }

    Point r_point;
    if (!point_decompress(r_encoded, r_point)) {
        return false;
    }
    Point a_point;
    if (!point_decompress(public_key, a_point)) {
        return false;
    }

    // k = SHA-512(R || A || M) mod L.
    std::vector<std::uint8_t> to_hash;
    to_hash.reserve(64 + message.size());
    to_hash.insert(to_hash.end(), r_encoded.begin(), r_encoded.end());
    to_hash.insert(to_hash.end(), public_key.begin(), public_key.end());
    to_hash.insert(to_hash.end(), message.begin(), message.end());
    const Fe k = reduce_mod_l(sha512(to_hash));

    // Accept iff [S]B == R + [k]A.
    const Point left = point_scalar_mul(s, base_point());
    const Point right = point_add(r_point, point_scalar_mul(k, a_point));
    return point_equal(left, right);
}

} // namespace oep::installer
