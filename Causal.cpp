//
//  Causal.hpp
//  X12 Power Line Integration
//
//  Created by Dr. Nathaniel Fox on 12/23/25.
//

#ifndef Causal_hpp
#define Causal_hpp

#include <stdio.h>
#ifndef CAUSAL_X12_HPP
#define CAUSAL_X12_HPP

#include <string>
#include <chrono>
#include <ctime>
#include <vector>
#include <optional>
#include <functional>
#include <system_error>
#include <expected> // C++23 or available in older versions via other means

/**
 * @file Causal.hpp
 * @brief A causality-focused API for generating and parsing X12 Interchange envelopes (ISA/IEA).
 *        The state of the InterchangeCause object directly causes the effect of the generated EDI output.
 */

namespace x12 {

// --- Forward Declarations ---
class InterchangeCause;
class InterchangeEffect;

// --- Error Handling ---
enum class InterchangeErrorCode {
    Success = 0,
    InvalidFieldLength,
    InvalidControlNumber,
    InvalidDate,
    InvalidTime,
    InvalidUsageIndicator,
    ParseError,
    GenerationError
};

class InterchangeCategory : public std::error_category {
public:
    const char* name() const noexcept override { return "x12_interchange"; }
    std::string message(int ev) const override;
};

const std::error_category& interchange_category() noexcept;
std::error_code make_error_code(InterchangeErrorCode e) noexcept;

} // namespace x12

// Enable std::error_code support for InterchangeErrorCode
namespace std {
    template<> struct is_error_code_enum<x12::InterchangeErrorCode> : true_type {};
}

namespace x12 {

// --- Core Data Types ---

/**
 * @brief Represents the causal state of an X12 Interchange Control Header.
 *        Changing any field in this struct will cause a different output effect.
 */
struct InterchangeState {
    // Authorization & Security (ISA01-ISA04)
    std::string authorization_info_qualifier{"00"};
    std::string authorization_info{std::string(10, ' ')};
    std::string security_info_qualifier{"00"};
    std::string security_info{std::string(10, ' ')};

    // Sender/Receiver Identification (ISA05-ISA08)
    std::string sender_id_qualifier{"ZZ"};
    std::string sender_id{std::string(15, ' ')};
    std::string receiver_id_qualifier{"ZZ"};
    std::string receiver_id{std::string(15, ' ')};

    // Date/Time (ISA09-ISA10)
    std::chrono::system_clock::time_point interchange_date{std::chrono::system_clock::now()};
    std::chrono::system_clock::time_point interchange_time{std::chrono::system_clock::now()};

    // Control Information (ISA11-ISA16)
    std::string repetition_separator{"U"};
    std::string control_version{"00501"};
    uint32_t control_number{1};
    bool acknowledgment_requested{false};
    char usage_indicator{'T'}; // T=Test, P=Production
    char component_element_separator{'>'};

    // Trailer information (IEA01)
    uint32_t number_included_groups{0};

    // Validation
    bool validate() const noexcept;
};

/**
 * @brief The effect caused by an InterchangeState - the generated EDI output.
 */
struct InterchangeEffect {
    std::string isa_segment;
    std::string iea_segment;
    std::string full_envelope;
    std::chrono::system_clock::time_point generation_time;
};

// --- Observer Pattern for State Changes ---
using ValidationHandler = std::function<void(const InterchangeState&, const std::vector<std::string>&)>;
using GenerationHandler = std::function<void(const InterchangeState&, const InterchangeEffect&)>;

/**
 * @brief The central causal agent for X12 Interchange generation.
 *        Maintains state and produces deterministic effects based on that state.
 */
class InterchangeCause {
public:
    // --- Construction & Initialization ---
    InterchangeCause();
    explicit InterchangeCause(InterchangeState initialState);
    
    // Static factory method for common configurations
    static InterchangeCause CreateForPartner(
                                             std::string_view sender_id,
                                             std::string_view receiver_id,
                                             std::string_view sender_qualifier = "ZZ",
                                             std::string_view receiver_qualifier = "ZZ",
                                             bool production = false
                                             );
    
    // --- State Access & Modification ---
    const InterchangeState& state() const noexcept { return state_; }
    
    // State modification methods that maintain causality
    void set_trading_partners(
                              std::string_view sender_qualifier, std::string_view sender_id,
                              std::string_view receiver_qualifier, std::string_view receiver_id
                              );
    
    void set_control_number(uint32_t number) noexcept;
    void set_usage_indicator(char indicator); // 'T' or 'P'
    void set_production_mode(bool production) noexcept;
    void set_number_included_groups(uint32_t count) noexcept { state_.number_included_groups = count; }
    
    __cpp_lib_void_txt.1.1.5.61._LIBCPP_AVAILABILITY_THROW_BAD_OPTIONAL_ACCESSPCX.1.1.5.55.138
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
#endif /* Causal_hpp */
