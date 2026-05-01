//
//  OneEarthMinor.c
//  X12 Power Line Integration
//
//  Created by Dr. Nathaniel Fox on 12/24/25.
//

#ifndef ONE_EARTH_MINOR_H
#define ONE_EARTH_MINOR_H

#include <time.h> // For time_t, struct tm
#include <stdint.h> // For uint32_t
#include <stdbool.h> // For bool

// Define a struct to hold the entire ISA segment data (X12 Interchange Control Header)
// This is the "Power Line" header.
typedef struct {
    // ISA01 - ISA04: Authorization & Security
    char auth_info_qualifier[3];
    char auth_info[11]; // 10 chars + null terminator
    char security_qualifier[3];
    char security_info[11]; // 10 chars + null terminator

    // ISA05 - ISA08: Sender & Receiver ID
    char sender_qualifier[3];
    char sender_id[16]; // 15 chars + null terminator
    char receiver_qualifier[3];
    char receiver_id[16]; // 15 chars + null terminator

    // ISA09 - ISA11: Date & Time
    struct tm interchange_date; // Use standard C time struct
    struct tm interchange_time;

    // ISA12 - ISA16: Control Info
    char repetition_separator[2];
    char control_version[6]; // e.g., "00501"
    uint32_t control_number; // ISA13
    bool acknowledgment_requested; // ISA14
    char usage_indicator[2]; // ISA15, 'T' or 'P'
    char component_separator[2]; // ISA16 (e.g., ">")
} x12_isa_segment_t;

// Struct for the IEA segment (X12 Interchange Control Trailer)
typedef struct {
    uint32_t group_count; // IEA01 - Number of included functional groups
    uint32_t control_number; // IEA02 - Must match ISA13
} x12_iea_segment_t;

// Struct representing the full Interchange Envelope
typedef struct {
    x12_isa_segment_t header;
    x12_iea_segment_t trailer;
    // Note: This struct would eventually contain pointers to Functional Groups (GS/GE)
} x12_interchange_t;

// Function prototypes

// Initialization: Creates a new interchange with safe defaults
void x12_interchange_init(x12_interchange_t *interchange);

// Set the core sender/receiver identities
void x12_set_trading_partners(x12_interchange_t *interchange,
                             const char *sender_qualifier, const char *sender_id,
                             const char *receiver_qualifier, const char *receiver_id);

// Sets the control number and syncs it between ISA and IEA
void x12_set_control_number(x12_interchange_t *interchange, uint32_t control_number);

// Core function: Generates the complete ISA segment string into the provided buffer.
// Returns length written, or -1 on error.
int x12_generate_isa_string(const x12_interchange_t *interchange,
                           char *output_buffer, size_t buffer_size,
                           char element_separator);

// Core function: Generates the complete IEA segment string.
int x12_generate_iea_string(const x12_interchange_t *interchange,
                           char *output_buffer, size_t buffer_size,
                           char element_separator);

// Utility: Formats a TM struct into YYMMDD format used by X12
void x12_format_date(const struct tm *date, char *output);
// Utility: Formats a TM struct into HHMM format used by X12
void x12_format_time(const struct tm *time, char *output);

#endif // ONE_EARTH_MINOR_H
