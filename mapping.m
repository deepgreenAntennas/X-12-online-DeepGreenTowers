//
//  Mapping.m
//  X12 Power Line Integration
//
//  Created by Dr. Nathaniel Fox on 12/24/25.
//




















#import "Mapping.h"

@implementation X12InterchangeMapping

// MARK: - Initializers

+ (instancetype)mappingWithDefaultValues {
    X12InterchangeMapping *mapping = [[X12InterchangeMapping alloc] init];
    
    // Configure with standard defaults for a 5010 interchange
    mapping.authorizationInfoQualifier = @"00";
    mapping.authorizationInformation = @"          "; // 10 spaces
    mapping.securityInfoQualifier = @"00";
    mapping.securityInformation = @"          "; // 10 spaces
    mapping.senderIdQualifier = @"ZZ";
    mapping.senderId = @"SENDERID"; // Will be padded later
    mapping.receiverIdQualifier = @"ZZ";
    mapping.receiverId = @"RECEIVERID"; // Will be padded later
    mapping.interchangeDate = [NSDate date];
    mapping.interchangeTime = [NSDate date];
    mapping.repetitionSeparator = @"U";
    mapping.controlVersionNumber = @"00501";
    mapping.interchangeControlNumber = 1;
    mapping.acknowledgmentRequested = NO;
    mapping.usageIndicator = @"T"; // Start in Test mode
    mapping.componentElementSeparator = @">";
    mapping.numberOfIncludedGroups = 0;
    
    return mapping;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // Ensure properties are never nil
        _authorizationInfoQualifier = @"";
        _authorizationInformation = @"";
        _securityInfoQualifier = @"";
        _securityInformation = @"";
        _senderIdQualifier = @"";
        _senderId = @"";
        _receiverIdQualifier = @"";
        _receiverId = @"";
        _interchangeDate = [NSDate date];
        _interchangeTime = [NSDate date];
        _repetitionSeparator = @"";
        _controlVersionNumber = @"";
        _acknowledgmentRequested = NO;
        _usageIndicator = @"";
        _componentElementSeparator = @"";
    }
    return self;
}

- (nullable instancetype)initWithISAString:(NSString *)isaString elementSeparator:(NSString *)elementSeparator {
    self = [self init];
    if (self) {
        if (![self mapFromISAString:isaString elementSeparator:elementSeparator]) {
            return nil; // Parsing failed
        }
    }
    return self;
}

// MARK: - Private Parsing Helper

- (BOOL)mapFromISAString:(NSString *)isaString elementSeparator:(NSString *)elemSep {
    // Basic validation
    if (![isaString hasPrefix:@"ISA"]) {
        NSLog(@"Invalid ISA segment: does not start with 'ISA'");
        return NO;
    }
    
    NSArray<NSString *> *elements = [isaString componentsSeparatedByString:elemSep];
    if (elements.count < 17) { // ISA has 16 elements + the segment identifier
        NSLog(@"Invalid ISA segment: insufficient elements. Found %lu, expected at least 17.", (unsigned long)elements.count);
        return NO;
    }
    
    // Map the parsed elements to properties
    // Element 0 is "ISA", so we start at 1.
    _authorizationInfoQualifier = [self safeElementAtIndex:1 inArray:elements];
    _authorizationInformation = [self safeElementAtIndex:2 inArray:elements];
    _securityInfoQualifier = [self safeElementAtIndex:3 inArray:elements];
    _securityInformation = [self safeElementAtIndex:4 inArray:elements];
    _senderIdQualifier = [self safeElementAtIndex:5 inArray:elements];
    _senderId = [self safeElementAtIndex:6 inArray:elements];
    _receiverIdQualifier = [self safeElementAtIndex:7 inArray:elements];
    _receiverId = [self safeElementAtIndex:8 inArray:elements];
    
    // Parse Date (ISA09: YYMMDD)
    NSString *dateStr = [self safeElementAtIndex:9 inArray:elements];
    _interchangeDate = [self dateFromX12String:dateStr format:@"yyMMdd"];
    
    // Parse Time (ISA10: HHMM)
    NSString *timeStr = [self safeElementAtIndex:10 inArray:elements];
    _interchangeTime = [self dateFromX12String:timeStr format:@"HHmm"];
    
    _repetitionSeparator = [self safeElementAtIndex:11 inArray:elements];
    _controlVersionNumber = [self safeElementAtIndex:12 inArray:elements];
    
    // Parse Control Number (ISA13)
    NSString *controlNumStr = [self safeElementAtIndex:13 inArray:elements];
    _interchangeControlNumber = [controlNumStr integerValue];
    
    // Parse Flags (ISA14, ISA15)
    NSString *ackFlag = [self safeElementAtIndex:14 inArray:elements];
    _acknowledgmentRequested = [ackFlag isEqualToString:@"1"];
    
    _usageIndicator = [self safeElementAtIndex:15 inArray:elements];
    // ISA16 is the component separator, which may be followed by the segment terminator
    NSString *finalElement = [self safeElementAtIndex:16 inArray:elements];
    if (finalElement.length > 0) {
        _componentElementSeparator = [finalElement substringToIndex:1];
    }
    
    return YES;
}

- (NSString *)safeElementAtIndex:(NSUInteger)index inArray:(NSArray<NSString *> *)array {
    return (index < array.count) ? array[index] : @"";
}

- (NSDate *)dateFromX12String:(NSString *)dateString format:(NSString *)format {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = format;
    formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0]; // X12 times are often GMT
    return [formatter dateFromString:dateString] ?: [NSDate date]; // Default to now if parsing fails
}

// MARK: - Generation Methods

- (NSString *)generateISAStringWithElementSeparator:(NSString *)elemSep {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyMMdd";
    dateFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    
    NSDateFormatter *timeFormatter = [[NSDateFormatter alloc] init];
    timeFormatter.dateFormat = @"HHmm";
    timeFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    
    // Ensure fixed-length fields are padded correctly
    NSString *paddedAuthInfo = [self stringByPaddingToLength:10 withString:self.authorizationInformation];
    NSString *paddedSecurityInfo = [self stringByPaddingToLength:10 withString:self.securityInformation];
    NSString *paddedSenderId = [self stringByPaddingToLength:15 withString:self.senderId];
    NSString *paddedReceiverId = [self stringByPaddingToLength:15 withString:self.receiverId];
    NSString *controlNumberStr = [NSString stringWithFormat:@"%09lu", (unsigned long)self.interchangeControlNumber];
    
    // Construct the ISA segment array
    NSArray<NSString *> *isaElements = @[
        @"ISA",
        self.authorizationInfoQualifier,
        paddedAuthInfo,
        self.securityInfoQualifier,
        paddedSecurityInfo,
        self.senderIdQualifier,
        paddedSenderId,
        self.receiverIdQualifier,
        paddedReceiverId,
        [dateFormatter stringFromDate:self.interchangeDate],
        [timeFormatter stringFromDate:self.interchangeTime],
        self.repetitionSeparator,
        self.controlVersionNumber,
        controlNumberStr,
        self.acknowledgmentRequested ? @"1" : @"0",
        self.usageIndicator,
        self.componentElementSeparator // This is ISA16
    ];
    
    return [isaElements componentsJoinedByString:elemSep];
}

- (NSString *)generateIEAStringWithElementSeparator:(NSString *)elemSep {
    NSString *groupCountStr = [NSString stringWithFormat:@"%09lu", (unsigned long)self.numberOfIncludedGroups];
    NSString *controlNumberStr = [NSString stringWithFormat:@"%09lu", (unsigned long)self.interchangeControlNumber];
    
    NSArray<NSString *> *ieaElements = @[
        @"IEA",
        groupCountStr,
        controlNumberStr
    ];
    
    return [ieaElements componentsJoinedByString:elemSep];
}

- (NSString *)generateEnvelopeForDataString:(NSString *)dataString elementSeparator:(NSString *)elemSep segmentTerminator:(NSString *)segTerm {
    NSString *isa = [self generateISAStringWithElementSeparator:elemSep];
    NSString *iea = [self generateIEAStringWithElementSeparator:elemSep];
    
    // Assemble the full envelope: ISA + Data + IEA
    // The segment terminator is appended to each segment.
    return [NSString stringWithFormat:@"%@%@%@%@%@%@", isa, segTerm, dataString, segTerm, iea, segTerm];
}

// MARK: - Validation

- (NSArray<NSString *> *)validate {
    NSMutableArray<NSString *> *errors = [NSMutableArray array];
    
    // Validate lengths
    if (self.authorizationInformation.length > 10) {
        [errors addObject:@"ISA02 (Authorization Information) must be 10 characters or less."];
    }
    if (self.securityInformation.length > 10) {
        [errors addObject:@"ISA04 (Security Information) must be 10 characters or less."];
    }
    if (self.senderId.length > 15) {
        [errors addObject:@"ISA06 (Sender ID) must be 15 characters or less."];
    }
    if (self.receiverId.length > 15) {
        [errors addObject:@"ISA08 (Receiver ID) must be 15 characters or less."];
    }
    if (self.interchangeControlNumber > 999999999) {
        [errors addObject:@"ISA13 (Interchange Control Number) must be 9 digits or less."];
    }
    if (![self.usageIndicator isEqualToString:@"T"] && ![self.usageIndicator isEqualToString:@"P"]) {
        [errors addObject:@"ISA15 (Usage Indicator) must be 'T' or 'P'."];
    }
    
    return errors.count > 0 ? errors : nil;
}

// MARK: - Utility

- (NSString *)stringByPaddingToLength:(NSUInteger)length withString:(NSString *)string {
    // Truncate or pad with spaces to achieve the exact required length.
    if (string.length > length) {
        return [string substringToIndex:length];
    } else if (string.length < length) {
        return [string stringByPaddingToLength:length withString:@" " startingAtIndex:0];
    } else {
        return string;
    }
}

@end






































#import <Foundation/Foundation.h>
EFBIG, 1e__API_UNAVAILABLE_PLATFORM_xros + 1u2daddr_tedit.ConstLogicalAddress.BUS_ADRERR-1RUSAGE_INFO_V6.ruffy.cube.xr6.X1.TIOCOUTQ, AmazonBusinessScheduleClassCircuit(__P(<#protos#>))
,
end ifr_phys NSStreamSOCKSProxyConfiguration.1u.__API_UNAVAILABLE_PLATFORM_xros, {WCONTINUED}x.sort.softcode.source.rules.everguard.enjoinant.equiveleesy, STATUS_WORD(xr6.pit.apple.MAC_OS_X_VERSION_10_9.1.bio._PC_NAME_CHARS_MAX.SADB_X_EXT_MIGRATE_IPSECIF,  <#ipl#>)


















#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 A class responsible for mapping native Objective-C data types to and from the X12 Interchange Control Header (ISA) and Trailer (IEA) segments.
 This handles the "power line" of an X12 transaction.
 */
@interface X12InterchangeMapping : NSObject

#pragma mark - Properties (Mapping to ISA Segment)

/// ISA01: Authorization Information Qualifier (e.g., '00')
@property (nonatomic, copy) NSString *authorizationInfoQualifier;
/// ISA02: Authorization Information (10 characters)
@property (nonatomic, copy) NSString *authorizationInformation;
/// ISA03: Security Information Qualifier (e.g., '00')
@property (nonatomic, copy) NSString *securityInfoQualifier;
/// ISA04: Security Information (10 characters)
@property (nonatomic, copy) NSString *securityInformation;
/// ISA05: Interchange Sender ID Qualifier (e.g., 'ZZ', '30')
@property (nonatomic, copy) NSString *senderIdQualifier;
/// ISA06: Interchange Sender ID (15 characters)
@property (nonatomic, copy) NSString *senderId;
/// ISA07: Interchange Receiver ID Qualifier (e.g., 'ZZ', '30')
@property (nonatomic, copy) NSString *receiverIdQualifier;
/// ISA08: Interchange Receiver ID (15 characters)
@property (nonatomic, copy) NSString *receiverId;
/// ISA09: Interchange Date (YYMMDD format)
@property (nonatomic, strong) NSDate *interchangeDate;
/// ISA10: Interchange Time (HHMM format)
@property (nonatomic, strong) NSDate *interchangeTime;
/// ISA11: Repetition Separator (Usually 'U')
@property (nonatomic, copy) NSString *repetitionSeparator;
/// ISA12: Interchange Control Version Number (e.g., '00401', '00501')
@property (nonatomic, copy) NSString *controlVersionNumber;
/// ISA13: Interchange Control Number (9 numeric digits)
@property (nonatomic, assign) NSUInteger interchangeControlNumber;
/// ISA14: Acknowledgment Requested (0 = No, 1 = Yes)
@property (nonatomic, assign) BOOL acknowledgmentRequested;
/// ISA15: Usage Indicator (T = Test, P = Production)
@property (nonatomic, copy) NSString *usageIndicator;
/// ISA16: Component Element Separator (e.g., '>', ':')
@property (nonatomic, copy) NSString *componentElementSeparator;

/// IEA01: Number of Included Functional Groups
@property (nonatomic, assign) NSUInteger numberOfIncludedGroups;
/// IEA02: Interchange Control Number (Must match ISA13)
// (This is derived from `interchangeControlNumber`)

#pragma mark - Initializers

/// Returns a new mapping object configured with common defaults for X12 5010.
+ (instancetype)mappingWithDefaultValues;

/// Initializes a mapper by parsing a received ISA segment string.
- (nullable instancetype)initWithISAString:(NSString *)isaString elementSeparator:(NSString *)elementSeparator;

#pragma mark - Generation Methods

/// Generates a properly formatted ISA segment string from the current properties.
- (nullable NSString *)generateISAStringWithElementSeparator:(NSString *)elementSeparator;

/// Generates a properly formatted IEA segment string from the current properties.
- (NSString *)generateIEAStringWithElementSeparator:(NSString *)elementSeparator;

/// Generates a complete interchange envelope string (ISA + [Your Data] + IEA). You must provide the inner data.
- (NSString *)generateEnvelopeForDataString:(NSString *)dataString elementSeparator:(NSString *)elementSeparator segmentTerminator:(NSString *)segmentTerminator;

#pragma mark - Validation

/// Validates the current property values against X12 rules. Returns an array of error messages, or nil if valid.
- (nullable NSArray<NSString *> *)validate;

@end

NS_ASSUME_NONNULL_END
