//
//  IASKSpecifier.m
//  http://www.inappsettingskit.com
//
//  Copyright (c) 2009:
//  Luc Vandal, Edovia Inc., http://www.edovia.com
//  Ortwin Gentz, FutureTap GmbH, http://www.futuretap.com
//  All rights reserved.
// 
//  It is appreciated but not required that you give credit to Luc Vandal and Ortwin Gentz, 
//  as the original authors of this code. You can give credit in a blog post, a tweet or on 
//  a info page of your app. Also, the original authors appreciate letting them know if you use this code.
//
//  This code is licensed under the BSD license that is available at: http://www.opensource.org/licenses/bsd-license.php
//

#import "IASKSpecifier.h"
#import "IASKSettingsReader.h"

@interface IASKSpecifier ()
@property (nonatomic, strong) NSDictionary  *multipleValuesDict;
- (void)_reinterpretValues:(NSDictionary*)specifierDict;
@end

@implementation IASKSpecifier

@synthesize specifierDict=_specifierDict;
@synthesize multipleValuesDict=_multipleValuesDict;
@synthesize settingsReader = _settingsReader;

- (instancetype)initWithSpecifier:(NSDictionary*)specifier {
    if (self = [super init]) {
        self.specifierDict = specifier;
        
        if ([[self type] isEqualToString:kIASKPSMultiValueSpecifier] ||
			[[self type] isEqualToString:kIASKPSTitleValueSpecifier]) {
            [self _reinterpretValues:self.specifierDict];
        }
    }
    return self;
}

- (void)_reinterpretValues:(NSDictionary*)specifierDict {
    NSArray *values = _specifierDict[kIASKValues];
    NSArray *titles = _specifierDict[kIASKTitles];
    
    NSMutableDictionary *multipleValuesDict = [[NSMutableDictionary alloc] init];
    
    if (values) {
		multipleValuesDict[kIASKValues] = values;
	}
	
    if (titles) {
		multipleValuesDict[kIASKTitles] = titles;
	}
    
    self.multipleValuesDict = multipleValuesDict;
}
- (NSString*)localizedObjectForKey:(NSString*)key {
	return [self.settingsReader titleForStringId:_specifierDict[key]];
}

- (NSString*)title {
    return [self localizedObjectForKey:kIASKTitle];
}

- (NSString*)footerText {
    return [self localizedObjectForKey:kIASKFooterText];
}

-(Class) viewControllerClass {
    return NSClassFromString(_specifierDict[kIASKViewControllerClass]);
}

-(SEL) viewControllerSelector {
    return NSSelectorFromString(_specifierDict[kIASKViewControllerSelector]);
}

-(Class)buttonClass {
    return NSClassFromString(_specifierDict[kIASKButtonClass]);
}

-(SEL)buttonAction {
    return NSSelectorFromString(_specifierDict[kIASKButtonAction]);
}

- (NSString*)key {
    return _specifierDict[kIASKKey];
}

- (NSString*)type {
    return _specifierDict[kIASKType];
}

- (NSString*)titleForCurrentValue:(id)currentValue {
	NSArray *values = [self multipleValues];
	NSArray *titles = [self multipleTitles];
	if (values.count != titles.count) {
		return nil;
	}
    NSInteger keyIndex = [values indexOfObject:currentValue];
	if (keyIndex == NSNotFound) {
		return nil;
	}
	@try {
		return [self.settingsReader titleForStringId:titles[keyIndex]];
	}
	@catch (NSException * e) {}
	return nil;
}

- (NSInteger)multipleValuesCount {
    return [_multipleValuesDict[kIASKValues] count];
}

- (NSArray*)multipleValues {
    return _multipleValuesDict[kIASKValues];
}

- (NSArray*)multipleTitles {
    return _multipleValuesDict[kIASKTitles];
}

- (NSString*)file {
    return _specifierDict[kIASKFile];
}

- (id)defaultValue {
    return _specifierDict[kIASKDefaultValue];
}

- (id)defaultStringValue {
    return [_specifierDict[kIASKDefaultValue] description];
}

- (BOOL)defaultBoolValue {
	id defaultValue = [self defaultValue];
	if ([defaultValue isEqual:[self trueValue]]) {
		return YES;
	}
	if ([defaultValue isEqual:[self falseValue]]) {
		return NO;
	}
	return [defaultValue boolValue];
}

- (id)trueValue {
    return _specifierDict[kIASKTrueValue];
}

- (id)falseValue {
    return _specifierDict[kIASKFalseValue];
}

- (float)minimumValue {
    return [_specifierDict[kIASKMinimumValue] floatValue];
}

- (float)maximumValue {
    return [_specifierDict[kIASKMaximumValue] floatValue];
}

- (NSString*)minimumValueImage {
    return _specifierDict[kIASKMinimumValueImage];
}

- (NSString*)maximumValueImage {
    return _specifierDict[kIASKMaximumValueImage];
}

- (BOOL)isSecure {
    return [_specifierDict[kIASKIsSecure] boolValue];
}

- (UIKeyboardType)keyboardType {
    if ([_specifierDict[KIASKKeyboardType] isEqualToString:kIASKKeyboardAlphabet]) {
        return UIKeyboardTypeASCIICapable;
    }
    else if ([_specifierDict[KIASKKeyboardType] isEqualToString:kIASKKeyboardNumbersAndPunctuation]) {
        return UIKeyboardTypeNumbersAndPunctuation;
    }
    else if ([_specifierDict[KIASKKeyboardType] isEqualToString:kIASKKeyboardNumberPad]) {
        return UIKeyboardTypeNumberPad;
    }
    else if ([_specifierDict[KIASKKeyboardType] isEqualToString:KIASKKeyboardURL]) {
        return UIKeyboardTypeURL;
    }
    else if ([_specifierDict[KIASKKeyboardType] isEqualToString:kIASKKeyboardEmailAddress]) {
        return UIKeyboardTypeEmailAddress;
    }
    return UIKeyboardTypeDefault;
}

- (UITextAutocapitalizationType)autocapitalizationType {
    if ([_specifierDict[kIASKAutocapitalizationType] isEqualToString:kIASKAutoCapNone]) {
        return UITextAutocapitalizationTypeNone;
    }
    else if ([_specifierDict[kIASKAutocapitalizationType] isEqualToString:kIASKAutoCapSentences]) {
        return UITextAutocapitalizationTypeSentences;
    }
    else if ([_specifierDict[kIASKAutocapitalizationType] isEqualToString:kIASKAutoCapWords]) {
        return UITextAutocapitalizationTypeWords;
    }
    else if ([_specifierDict[kIASKAutocapitalizationType] isEqualToString:kIASKAutoCapAllCharacters]) {
        return UITextAutocapitalizationTypeAllCharacters;
    }
    return UITextAutocapitalizationTypeNone;
}

- (UITextAutocorrectionType)autoCorrectionType {
    if ([_specifierDict[kIASKAutoCorrectionType] isEqualToString:kIASKAutoCorrDefault]) {
        return UITextAutocorrectionTypeDefault;
    }
    else if ([_specifierDict[kIASKAutoCorrectionType] isEqualToString:kIASKAutoCorrNo]) {
        return UITextAutocorrectionTypeNo;
    }
    else if ([_specifierDict[kIASKAutoCorrectionType] isEqualToString:kIASKAutoCorrYes]) {
        return UITextAutocorrectionTypeYes;
    }
    return UITextAutocorrectionTypeDefault;
}

@end
