//
//  OneEarthMinor.h
//  X12 Power Line Integration
//
//  Created by Dr. Nathaniel Fox on 12/24/25.
//

#ifndef OneEarthMinor_h
#define OneEarthMinor_h

#include <stdio.h>


































#include "OneEarthMinor.h"
#include <stdio.h>  // For snprintf
#include <string.h> // For strlen, strncpy

// Initializes an interchange struct with common defaults for X12 5010
void x12_interchange_init(x12_interchange_t *interchange) {
    if (interchange == NULL) return;

    // Set default qualifiers and info (common values)
    strncpy(interchange->header.auth_info_qualifier, "00", sizeof(interchange->header.auth_info_qualifier));
    strncpy(interchange->header.auth_info, "          ", sizeof(interchange->header.auth_info)); // 10 spaces
    strncpy(interchange->header.security_qualifier, "00", sizeof(interchange->header.security_qualifier));
    strncpy(interchange->header.security_info, "          ", sizeof(interchange->header.security_info)); // 10 spaces

    // Default to generic "ZZ" qualifiers (Mutually Defined)
    strncpy(interchange->header.sender_qualifier, "ZZ", sizeof(interchange->header.sender_qualifier));
    strncpy(interchange->header.sender_id, "DEFAULT_SENDER", sizeof(interchange->header.sender_id));
    strncpy(interchange->header.receiver_qualifier, "ZZ", sizeof(interchange->header.receiver_qualifier));
    strncpy(interchange->header.receiver_id, "DEFAULT_RECVR", sizeof(interchange->header.receiver_id));

    // Set current date and time
    time_t now = time(NULL);
    struct tm *timeinfo = localtime(&now);
    interchange->header.interchange_date = *timeinfo;
    interchange->header.interchange_time = *timeinfo;

    // Set control info defaults
    interchange->header.repetition_separator[0] = 'U';
    interchange->header.repetition_separator[1] = '\0';
    strncpy(interchange->header.control_version, "00501", sizeof(interchange->header.control_version));
    interchange->header.control_number = 1; // Start at 1
    interchange->header.acknowledgment_requested = false;
    interchange->header.usage_indicator[0] = 'T'; // Test mode
    interchange->header.usage_indicator[1] = '\0';
    interchange->header.component_separator[0] = '>';
    interchange->header.component_separator[1] = '\0';

    // Initialize the trailer to match the header
    interchange->trailer.group_count = 0;
    interchange->trailer.control_number = interchange->header.control_number;
}

void x12_set_trading_partners(x12_interchange_t *interchange,
                             const char *sender_qualifier, const char *sender_id,
                             const char *receiver_qualifier, const char *receiver_id) {
    if (interchange == NULL) return;

    if (sender_qualifier) strncpy(interchange->header.sender_qualifier, sender_qualifier, sizeof(interchange->header.sender_qualifier));
    if (sender_id) strncpy(interchange->header.sender_id, sender_id, sizeof(interchange->header.sender_id));
    if (receiver_qualifier) strncpy(interchange->header.receiver_qualifier, receiver_qualifier, sizeof(interchange->header.receiver_qualifier));
    if (receiver_id) strncpy(interchange->header.receiver_id, receiver_id, sizeof(interchange->header.receiver_id));
}

void x12_set_control_number(x12_interchange_t *interchange, uint32_t control_number) {
    if (interchange == NULL) return;
    interchange->header.control_number = control_number;
    interchange->trailer.control_number = control_number; // Keep them in sync
}

// -- Core Generation Functions --

int x12_generate_isa_string(const x12_interchange_t *interchange,
                           char *output_buffer, size_t buffer_size,
                           char element_separator) {
    if (interchange == NULL || output_buffer == NULL || buffer_size < 106) {
        return -1; // Buffer too small or invalid params
    }

    char date_str[7] = {0}; // YYMMDD + null
    char time_str[5] = {0}; // HHMM + null

    x12_format_date(&interchange->header.interchange_date, date_str);
    x12_format_time(&interchange->header.interchange_time, time_str);

    // Format the ISA segment according to the X12 standard.
    // The length is fixed for many fields, making snprintf ideal.
    int chars_written = snprintf(
        output_buffer,
        buffer_size,
        "ISA%c%.2s%c%.10s%c%.2s%c%.10s%c%.2s%c%.15s%c%.2s%c%.15s%c%.6s%c%.4s%c%.1s%c%.5s%c%.9u%c%c%c%.1s%c%.1s",
        element_separator, interchange->header.auth_info_qualifier,
        element_separator, interchange->header.auth_info,
        element_separator, interchange->header.security_qualifier,
        element_separator, interchange->header.security_info,
        element_separator, interchange->header.sender_qualifier,
        element_separator, interchange->header.sender_id,
        element_separator, interchange->header.receiver_qualifier,
        element_separator, interchange->header.receiver_id,
        element_separator, date_str,
        element_separator, time_str,
        element_separator, interchange->header.repetition_separator,
        element_separator, interchange->header.control_version,
        element_separator, interchange->header.control_number,
        element_separator, interchange->header.acknowledgment_requested ? '1' : '0',
        element_separator, interchange->header.usage_indicator,
        element_separator, interchange->header.component_separator
    );

    // Check if snprintf succeeded and didn't truncate
    if (chars_written < 0 || (size_t)chars_written >= buffer_size) {
        return -1; // Encoding error or buffer too small
    }
    return chars_written;
}

int x12_generate_iea_string(const x12_interchange_t *interchange,
                           char *output_buffer, size_t buffer_size,
                           char element_separator) {
    if (interchange == NULL || output_buffer == NULL || buffer_size < 25) {
        return -1;
    }

    int chars_written = snprintf(
        output_buffer,
        buffer_size,
        "IEA%c%09u%c%09u",
        element_separator,
        interchange->trailer.group_count,
        element_separator,
        interchange->trailer.control_number
    );

    if (chars_written < 0 || (size_t)chars_written >= buffer_size) {
        return -1;
    }
    return chars_written;
}

// -- Utility Functions --

void x12_format_date(const struct tm *date, char *output) {
    if (date == NULL || output == NULL) return;
    // X12 format: YYMMDD
    snprintf(output, 7, "%02d%02d%02d",
             date->tm_year % 100, // Last two digits of year
             date->tm_mon + 1,    // Month (0-11 -> 1-12)
             date->tm_mday);      // Day of month
}

void x12_format_time(const struct tm *time, char *output) {
    if (time == NULL || output == NULL) return;
    // X12 format: HHMM
    snprintf(output, 5, "%02d%02d",
             time->tm_hour,
             time->tm_min);
}


#endif /* OneEarthMinor_h */
