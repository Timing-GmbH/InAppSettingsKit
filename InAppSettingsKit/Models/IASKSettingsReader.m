//
//  IASKSettingsReader.m
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

#import "IASKSettingsReader.h"
#import "IASKSpecifier.h"

@interface IASKSettingsReader (private)
- (void)_reinterpretBundle:(NSDictionary*)settingsBundle;
- (BOOL)_sectionHasHeading:(NSInteger)section;
- (NSString *)platformSuffix;
- (NSString *)locateSettingsFile:(NSString *)file;

@end

@implementation IASKSettingsReader

@synthesize path=_path,
localizationTable=_localizationTable,
bundlePath=_bundlePath,
settingsBundle=_settingsBundle, 
dataSource=_dataSource;

- (instancetype)init {
	return [self initWithFile:@"Root"];
}

- (instancetype)initWithFile:(NSString*)file {
    if ((self=[super init])) {


        self.path = [self locateSettingsFile: file];
        self.settingsBundle = [NSDictionary dictionaryWithContentsOfFile:self.path];
        self.bundlePath = (self.path).stringByDeletingLastPathComponent;
        _bundle = [NSBundle bundleWithPath:self.bundlePath];
        
		// Look for localization file
		self.localizationTable = [(self.path).stringByDeletingPathExtension.stringByDeletingPathExtension.lastPathComponent // strip absolute path
								  stringByReplacingOccurrencesOfString:[self platformSuffix] withString:@""]; // removes potential '~device' (~ipad, ~iphone)
		if([_bundle pathForResource:self.localizationTable ofType:@"strings"] == nil){
			// Could not find the specified localization: use default
			self.localizationTable = @"Root";
		}

        if (_settingsBundle) {
            [self _reinterpretBundle:_settingsBundle];
        }
    }
    return self;
}

- (void)_reinterpretBundle:(NSDictionary*)settingsBundle {
    NSArray *preferenceSpecifiers   = settingsBundle[kIASKPreferenceSpecifiers];
    NSInteger sectionCount          = -1;
    NSMutableArray *dataSource      = [[NSMutableArray alloc] init];
    
    for (NSDictionary *specifier in preferenceSpecifiers) {
        if ([(NSString*)specifier[kIASKType] isEqualToString:kIASKPSGroupSpecifier]) {
            NSMutableArray *newArray = [[NSMutableArray alloc] init];
            
            [newArray addObject:specifier];
            [dataSource addObject:newArray];
            sectionCount++;
        }
        else {
            if (sectionCount == -1) {
                NSMutableArray *newArray = [[NSMutableArray alloc] init];
				[dataSource addObject:newArray];
				sectionCount++;
			}

            IASKSpecifier *newSpecifier = [[IASKSpecifier alloc] initWithSpecifier:specifier];
            [(NSMutableArray*)dataSource[sectionCount] addObject:newSpecifier];
        }
    }
    self.dataSource = dataSource;
}

- (BOOL)_sectionHasHeading:(NSInteger)section {
    return [self.dataSource[section][0] isKindOfClass:[NSDictionary class]];
}

- (NSInteger)numberOfSections {
    return self.dataSource.count;
}

- (NSInteger)numberOfRowsForSection:(NSInteger)section {
    int headingCorrection = [self _sectionHasHeading:section] ? 1 : 0;
    return ((NSArray*)self.dataSource[section]).count - headingCorrection;
}

- (IASKSpecifier*)specifierForIndexPath:(NSIndexPath*)indexPath {
    int headingCorrection = [self _sectionHasHeading:indexPath.section] ? 1 : 0;
    
    IASKSpecifier *specifier = self.dataSource[indexPath.section][(indexPath.row+headingCorrection)];
 	specifier.settingsReader = self;
 	return specifier;
}

- (IASKSpecifier*)specifierForKey:(NSString*)key {
    for (NSArray *specifiers in _dataSource) {
        for (id sp in specifiers) {
            if ([sp isKindOfClass:[IASKSpecifier class]]) {
                if ([[sp key] isEqualToString:key]) {
                    return sp;
                }
            }
        }
    }
    return nil;
}

- (NSString*)titleForSection:(NSInteger)section {
    if ([self _sectionHasHeading:section]) {
        NSDictionary *dict = self.dataSource[section][kIASKSectionHeaderIndex];
        return [_bundle localizedStringForKey:dict[kIASKTitle] value:dict[kIASKTitle] table:self.localizationTable];
    }
    return nil;
}

- (NSString*)keyForSection:(NSInteger)section {
    if ([self _sectionHasHeading:section]) {
        return self.dataSource[section][kIASKSectionHeaderIndex][kIASKKey];
    }
    return nil;
}

- (NSString*)footerTextForSection:(NSInteger)section {
    if ([self _sectionHasHeading:section]) {
        NSDictionary *dict = self.dataSource[section][kIASKSectionHeaderIndex];
        return [_bundle localizedStringForKey:dict[kIASKFooterText] value:dict[kIASKFooterText] table:self.localizationTable];
    }
    return nil;
}

- (NSString*)titleForStringId:(NSString*)stringId {
    return [_bundle localizedStringForKey:stringId value:stringId table:self.localizationTable];
}

- (NSString*)pathForImageNamed:(NSString*)image {
    return [self.bundlePath stringByAppendingPathComponent:image];
}

- (NSString *)platformSuffix {
    BOOL isPad = NO;
#if (__IPHONE_OS_VERSION_MAX_ALLOWED >= 30200)
    isPad = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
#endif
    return isPad ? @"~ipad" : @"~iphone";
}

- (NSString *)file:(NSString *)file
        withBundle:(NSString *)bundle
            suffix:(NSString *)suffix
         extension:(NSString *)extension {

    NSString *appBundle = [NSBundle mainBundle].bundlePath;
    bundle = [appBundle stringByAppendingPathComponent:bundle];
    file = [file stringByAppendingFormat:@"%@%@", suffix, extension];
    return [bundle stringByAppendingPathComponent:file];

}

- (NSString *)locateSettingsFile: (NSString *)file {

    // The file is searched in the following order:
    //
    // InAppSettings.bundle/FILE~DEVICE.inApp.plist
    // InAppSettings.bundle/FILE.inApp.plist
    // InAppSettings.bundle/FILE~DEVICE.plist
    // InAppSettings.bundle/FILE.plist
    // Settings.bundle/FILE~DEVICE.inApp.plist
    // Settings.bundle/FILE.inApp.plist
    // Settings.bundle/FILE~DEVICE.plist
    // Settings.bundle/FILE.plist
    //
    // where DEVICE is either "iphone" or "ipad" depending on the current
    // interface idiom.
    //
    // Settings.app uses the ~DEVICE suffixes since iOS 4.0.  There are some
    // differences from this implementation:
    // - For an iPhone-only app running on iPad, Settings.app will not use the
    //   ~iphone suffix.  There is no point in using these suffixes outside
    //   of universal apps anyway.
    // - This implementation uses the device suffixes on iOS 3.x as well.

    NSArray *bundles =
        @[kIASKBundleFolderAlt, kIASKBundleFolder];

    NSArray *extensions =
        @[@".inApp.plist", @".plist"];

    NSArray *suffixes =
        @[[self platformSuffix], @""];

    NSString *path = nil;
    NSFileManager *fileManager = [NSFileManager defaultManager];
	
    for (NSString *bundle in bundles) {
		for (NSString *extension in extensions) {
			for (NSString *suffix in suffixes) {
                path = [self file:file
                       withBundle:bundle
                           suffix:suffix
                        extension:extension];
                if ([fileManager fileExistsAtPath:path]) {
                    goto exitFromNestedLoop;
                }
            }
		}
    }
	
exitFromNestedLoop:
    return path;
}

@end
