//
//  IASKSpecifierValuesViewController.m
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

#import "IASKSpecifierValuesViewController.h"
#import "IASKSpecifier.h"
#import "IASKSettingsReader.h"
#import "IASKSettingsStoreUserDefaults.h"

#import "PCAppDelegate.h"

#define kCellValue      @"kCellValue"

@interface IASKSpecifierValuesViewController()
- (void)userDefaultsDidChange;
@end

@implementation IASKSpecifierValuesViewController

@synthesize currentSpecifier=_currentSpecifier;
@synthesize checkedItem=_checkedItem;
@synthesize settingsReader = _settingsReader;
@synthesize settingsStore = _settingsStore;

- (void) updateCheckedItem {
    NSInteger index;
	
	// Find the currently checked item
    if([self.settingsStore objectForKey:[_currentSpecifier key]]) {
      index = [[_currentSpecifier multipleValues] indexOfObject:[self.settingsStore objectForKey:[_currentSpecifier key]]];
    } else {
      index = [[_currentSpecifier multipleValues] indexOfObject:[_currentSpecifier defaultValue]];
    }
	self.checkedItem = [NSIndexPath indexPathForRow:index inSection:0];
}

- (id<IASKSettingsStore>)settingsStore {
    if(_settingsStore == nil) {
        _settingsStore = [[IASKSettingsStoreUserDefaults alloc] init];
    }
    return _settingsStore;
}

- (UITableView *)tableView
{
	return _tableView;
}

- (void)viewWillAppear:(BOOL)animated {
    if (_currentSpecifier) {
        self.title = [_currentSpecifier title];
        [self updateCheckedItem];
    }
    
    if (_tableView) {
        [_tableView reloadData];

		// Make sure the currently checked item is visible
        [_tableView scrollToRowAtIndexPath:self.checkedItem atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
    }
	[super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
	[_tableView flashScrollIndicators];
	[super viewDidAppear:animated];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(userDefaultsDidChange)
												 name:NSUserDefaultsDidChangeNotification
											   object:[NSUserDefaults standardUserDefaults]];
}

- (void)viewDidDisappear:(BOOL)animated {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSUserDefaultsDidChangeNotification object:nil];
	[super viewDidDisappear:animated];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
	return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? UIInterfaceOrientationMaskAll : UIInterfaceOrientationMaskAllButUpsideDown;
}

#pragma mark -
#pragma mark UITableView delegates

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_currentSpecifier multipleValuesCount];
}

- (void)selectCell:(UITableViewCell *)cell {
	cell.accessoryType = UITableViewCellAccessoryCheckmark;
	[cell.textLabel setTextColor:kIASKgrayBlueColor];
}

- (void)deselectCell:(UITableViewCell *)cell {
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.textLabel.textColor = [UIColor darkTextColor];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return [_currentSpecifier footerText];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell   = [tableView dequeueReusableCellWithIdentifier:kCellValue];
    NSArray *titles         = [_currentSpecifier multipleTitles];
	
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kCellValue];
    }
	
	if ([indexPath isEqual:self.checkedItem]) {
		[self selectCell:cell];
    } else {
        [self deselectCell:cell];
    }
	
	@try {
		cell.textLabel.text = [self.settingsReader titleForStringId:titles[indexPath.row]];
	}
	@catch (NSException * e) {}
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	
    if (indexPath == self.checkedItem) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }
    
    NSArray *values         = [_currentSpecifier multipleValues];
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self deselectCell:[tableView cellForRowAtIndexPath:self.checkedItem]];
    [self selectCell:[tableView cellForRowAtIndexPath:indexPath]];
    self.checkedItem = indexPath;
	
    [self.settingsStore setObject:values[indexPath.row] forKey:[_currentSpecifier key]];
	[self.settingsStore synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:kIASKAppSettingChanged
                                                        object:[_currentSpecifier key]
                                                      userInfo:@{[_currentSpecifier key]: values[indexPath.row]}];
}

#pragma mark Notifications

- (void)userDefaultsDidChange {
	NSIndexPath *oldCheckedItem = self.checkedItem;
	if(_currentSpecifier) {
		[self updateCheckedItem];
	}
	
	// only reload the table if it had changed; prevents animation cancellation
	if (self.checkedItem != oldCheckedItem) {
		[_tableView reloadData];
	}
}

@end
