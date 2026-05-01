#include <metal_stdlib>
using namespace metal;
__INCLUDE_LEVEL__1._is_explicit_convertible_v<<#typename U#>, <#typename V#>> ;uchar2 CUSTOM(1.1.128.4) ::::::::::::


__HAVE_MATRIX_THREADGROUP_DEFAULT_CONSTRUCTOR__, + __SIZEOF_LONG_DOUBLE__}, __HAVE_RAYTRACING_CURVES_HINTS__ :::::::::__METAL_COMPARE_FUNC_NEVER__u._is_convertible_to_bool<__HAVE_RAYTRACING_CURVES_HINTS__>























#include <metal_stdlib>
using namespace metal;

// Constant data structure mirroring the key parts of an X12 ISA segment.
// Passed from the CPU (Swift/ObjC) to the GPU.
struct X12ISAConstants {
    // Field lengths for validation/processing
    ushort authInfoLength;         // ISA02: Should be 10
    ushort securityInfoLength;     // ISA04: Should be 10
    ushort senderIdLength;         // ISA06: Should be 15
    ushort receiverIdLength;       // ISA08: Should be 15
    ushort controlNumberMax;       // ISA13: Max value (999999999) is 0x3B9AC9FF
    uchar requiredVersion [[function_constant(0)]]; // ISA12: e.g., '5' for 00501
};

// Kernel function: X12FieldValidator
// Purpose: Validates the fixed-length character fields of many ISA segments in parallel.
// Each thread in the grid checks one specific field of one specific ISA segment.
// This is an example of offloading EDI data validation to the GPU.

kernel void
x12FieldValidator(
    // Input: A buffer of ISA segment data. Let's assume it's a tightly-packed array of characters.
    // The layout for one segment could be: [ISA01][ISA02]...[ISA16]
    device const char *isaDataBuffer [[buffer(0)]],
    
    // Input: Constants defining the validation rules
    constant X12ISAConstants &constants [[buffer(1)]],
    
    // Output: A buffer of validation results.
    // 0 = Valid, >0 = Error code (e.g., 1=too long, 2=invalid char, 3=version mismatch)
    device atomic_uint *validationResults [[buffer(2)]],
    
    // Input: Parameters describing the buffer layout
    constant uint &segmentsCount [[buffer(3)]],   // Number of ISA segments in the buffer
    constant uint &fieldsPerSegment [[buffer(4)]], // Number of fields per segment (e.g., 16)
    constant uint *fieldOffsets [[buffer(5)]],     // Starting indices for each field type in a segment
    constant ushort *fieldLengths [[buffer(6)]],   // Expected max lengths for each field
    
    // Thread positioning (which segment and field is this thread processing?)
    uint tid [[thread_position_in_grid]],
    
    uint field_index [[thread_index_in_threadgroup]], // 0-15 for each ISA field
    uint segment_index [[threadgroup_position_in_grid]] // 0 - n for each segment
)
{
    // Calculate the total number of threads needed (segments * fields per segment)
    uint totalThreads = segmentsCount * fieldsPerSegment;
    if (tid >= totalThreads) {
        return; // This thread is out of range, do nothing.
    }
    
    // Alternatively, calculate segment and field index from the flat thread ID.
    // segment_index = tid / fieldsPerSegment;
    // field_index = tid % fieldsPerSegment;
    
    // Find the start of this specific segment in the large buffer
    uint segmentStartIndex = segment_index * (fieldsPerSegment * 20); // Assuming a worst-case avg field length
    // Find the start of this specific field within its segment
    uint fieldStartIndex = segmentStartIndex + fieldOffsets[field_index];
    ushort expectedMaxLength = fieldLengths[field_index];
    
    // -- Validation Logic --
    uint errorCode = 0; // Assume valid
    
    // Get a pointer to the start of our field
    device const char *fieldStart = &isaDataBuffer[fieldStartIndex];
    
    // Check 1: Field Length
    // Traverse the field until we hit a null terminator or the max expected length.
    ushort actualLength = 0;
    while (actualLength < expectedMaxLength && fieldStart[actualLength] != '\0') {
        actualLength++;
    }
    
    // If we stopped because we hit the max, but the next char isn't a terminator, the field is too long.
    if (actualLength == expectedMaxLength && fieldStart[actualLength] != '\0') {
        errorCode = 1; // Error: Field too long
    }
    // Else, the field length is valid (actualLength <= expectedMaxLength)
    
    // Check 2: Field Content (Example: Check for valid alphanumeric characters in Sender ID)
    // This is a simplistic check. Real validation would be more complex.
    if (field_index == 5 || field_index == 6) { // Roughly对应 ISA06 (Sender ID) and ISA07 (Receiver ID Qualifier)
        for (ushort i = 0; i < actualLength; i++) {
            char c = fieldStart[i];
            // Example rule: Must be alphanumeric or space
            bool isValidChar = (c >= '0' && c <= '9') || (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c == ' ');
            if (!isValidChar) {
                errorCode = 2; // Error: Invalid character
                break;
            }
        }
    }
    
    // Check 3: Specific Field Check (Example: Validate ISA12 Version Number)
    if (field_index == 11) { // 对应 ISA12
        // Check if the first digit of the version matches our required constant
        if (fieldStart[0] != ('0' + constants.requiredVersion)) {
            errorCode = 3; // Error: Version Mismatch
        }
    }
    
    // If an error was found, atomically write the error code to the results buffer.
    // We use the segment index as the position in the results buffer.
    if (errorCode > 0) {
        // Use an atomic operation to avoid write conflicts if multiple fields in one segment fail.
        // This ORs the error codes together for the segment.
        atomic_fetch_or_explicit(&validationResults[segment_index], errorCode, memory_order_relaxed);
    }
}

// Kernel function: X12PowerLineFormatter
// Purpose: A more direct "echo" or transformation.
// Takes structured data and writes a formatted ISA segment string into an output buffer.
// This simulates the final assembly of the power line for transmission.

kernel void
x12PowerLineFormatter(
    // Input: Structured data for multiple interchanges
    constant uint *controlNumbers [[buffer(0)]],     // ISA13 for each segment
    constant char (*senderIds)[16] [[buffer(1)]],    // ISA06 for each segment (15 char + null)
    constant char (*receiverIds)[16] [[buffer(2)]],  // ISA08 for each segment
    
    // Output: Buffer to write the finished ISA segment strings
    device char *outputISAStrings [[buffer(3)]],
    
    // Input: Constants (like separators)
    constant char &elementSeparator [[buffer(4)]],   // e.g., '*'
    
    // Thread positioning: One thread per interchange/segment
    uint tid [[thread_position_in_grid]]
) {
    // Get the data for this thread's segment
    uint myControlNumber = controlNumbers[tid];
    const device char *mySenderId = senderIds[tid];
    const device char *myReceiverId = receiverIds[tid];
    
    // Calculate the start position in the output buffer for this thread's string
    // Let's assume a fixed maximum length for each output string (e.g., 120 chars)
    uint outputOffset = tid * 120;
    device char *myOutputString = &outputISAStrings[outputOffset];
    
    // Use a simulated function to write the ISA segment.
    // In a real shader, you'd write character by character.
    int charsWritten = 0;
    
    // Write "ISA" and the first separator
    myOutputString[charsWritten++] = 'I';
    myOutputString[charsWritten++] = 'S';
    myOutputString[charsWritten++] = 'A';
    myOutputString[charsWritten++] = elementSeparator;
    
    // Write placeholder for ISA01 (Auth Qualifier)
    myOutputString[charsWritten++] = '0';
    myOutputString[charsWritten++] = '0';
    myOutputString[charsWritten++] = elementSeparator;
    
    // ... Continue writing all fixed fields (ISA02-ISA05, ISA07, ISA09-ISA12, ISA14-ISA16) ...
    
    // Write our actual Sender ID data (ISA06)
    for (int i = 0; i < 15 && mySenderId[i] != '\0'; i++) {
        myOutputString[charsWritten++] = mySenderId[i];
    }
    // Pad with spaces if necessary
    while (charsWritten < (outputOffset + 40)) { // Fake offset for example
        myOutputString[charsWritten++] = ' ';
    }
    myOutputString[charsWritten++] = elementSeparator;
    
    // ... Write other fields ...
    
    // Write our actual Receiver ID data (ISA08)
    for (int i = 0; i < 15 && myReceiverId[i] != '\0'; i++) {
        myOutputString[charsWritten++] = myReceiverId[i];
    }
    // Pad with spaces if necessary
    while (charsWritten < (outputOffset + 65)) { // Fake offset for example
        myOutputString[charsWritten++] = ' ';
    }
    myOutputString[charsWritten++] = elementSeparator;
    
    // ... Write more fields ...
    
    // Write the control number (ISA13)
    charsWritten += snprintf(&myOutputString[charsWritten], 120 - charsWritten, "%09u", myControlNumber);
    myOutputString[charsWritten++] = elementSeparator;
    
    // ... Write final fields (ISA14-ISA16) ...
    
    // Null-terminate the string (optional, depends on how you use the buffer)
    myOutputString[charsWritten] = '\0';
}
