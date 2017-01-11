
//
//  IASKAppSettingsViewController.m
//  http://www.inappsettingskit.com
//
//  Copyright (c) 2009-2010:
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


#import "IASKAppSettingsViewController.h"
#import "IASKSettingsReader.h"
#import "IASKSettingsStoreUserDefaults.h"
#import "IASKPSToggleSwitchSpecifierViewCell.h"
#import "IASKPSSliderSpecifierViewCell.h"
#import "IASKPSTextFieldSpecifierViewCell.h"
#import "IASKPSTitleValueSpecifierViewCell.h"
#import "IASKSwitch.h"
#import "IASKSlider.h"
#import "IASKSpecifier.h"
#import "IASKSpecifierValuesViewController.h"
#import "IASKTextField.h"

#import "PCAppDelegate.h"
#import "ECUIKit.h"

static NSString *kIASKCredits = @"Powered by InAppSettingsKit"; // Leave this as-is!!!

#define kIASKSpecifierValuesViewControllerIndex       0
#define kIASKSpecifierChildViewControllerIndex        1

#define kIASKCreditsViewWidth                         285

CGRect IASKCGRectSwap(CGRect rect);

@interface IASKAppSettingsViewController ()
- (void)_textChanged:(id)sender;
- (void)_keyboardWillShow:(NSNotification*)notification;
- (void)_keyboardWillHide:(NSNotification*)notification;
- (void)synchronizeSettings;
- (void)reload;
@end

@implementation IASKAppSettingsViewController

@synthesize delegate = _delegate;
@synthesize currentIndexPath=_currentIndexPath;
@synthesize settingsReader = _settingsReader;
@synthesize file = _file;
@synthesize currentFirstResponder = _currentFirstResponder;
@synthesize showCreditsFooter = _showCreditsFooter;
@synthesize showDoneButton = _showDoneButton;
@synthesize settingsStore = _settingsStore;

#pragma mark accessors
- (IASKSettingsReader*)settingsReader {
	if (!_settingsReader) {
		_settingsReader = [[IASKSettingsReader alloc] initWithFile:self.file];
	}
	return _settingsReader;
}

- (id<IASKSettingsStore>)settingsStore {
	if (!_settingsStore) {
		_settingsStore = [[IASKSettingsStoreUserDefaults alloc] init];
	}
	return _settingsStore;
}

- (NSString*)file {
	if (!_file) {
		return @"Root";
	}
	return _file;
}

- (void)setFile:(NSString *)file {
	if (file != _file) {
		_file = [file copy];
	}
	
	self.settingsReader = nil; // automatically initializes itself
}

- (UITableView *)tableView
{
	return _tableView;
}

#pragma mark standard view controller methods
- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        // If set to YES, will display credits for InAppSettingsKit creators
        _showCreditsFooter = YES;
        
        // If set to YES, will add a DONE button at the right of the navigation bar
        _showDoneButton = YES;
    }
    return self;
}

- (void)awakeFromNib {
	[super awakeFromNib];
	// If set to YES, will display credits for InAppSettingsKit creators
	_showCreditsFooter = YES;
	
	// If set to YES, will add a DONE button at the right of the navigation bar
	// if loaded via NIB, it's likely we sit in a TabBar- or NavigationController
	// and thus don't need the Done button
	_showDoneButton = NO;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Add views
    _viewList = [[NSMutableArray alloc] init];
    [_viewList addObject:@{@"ViewName": @"IASKSpecifierValuesView"}];
    [_viewList addObject:@{@"ViewName": @"IASKAppSettingsView"}];

}

- (void)viewWillAppear:(BOOL)animated {
    if (_tableView) {
        [_tableView reloadData];
		_tableView.frame = self.view.bounds;
    }
	
	self.navigationItem.rightBarButtonItem = nil;
    if (_showDoneButton) {
        UIBarButtonItem *buttonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone 
                                                                                    target:self 
                                                                                    action:@selector(dismiss:)];
        self.navigationItem.rightBarButtonItem = buttonItem;
    } 
    if (!self.title) {
        self.title = NSLocalizedString(@"Settings", @"");
    }
	
	if (self.currentIndexPath) {
		if (animated) {
			// animate deselection of previously selected row
			[_tableView selectRowAtIndexPath:self.currentIndexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
			[_tableView deselectRowAtIndexPath:self.currentIndexPath animated:YES];
		}
		self.currentIndexPath = nil;
	}
	
	[super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
	[_tableView flashScrollIndicators];
//	_tableView.frame = self.view.bounds;
	[super viewDidAppear:animated];

	NSNotificationCenter *dc = [NSNotificationCenter defaultCenter];
	IASK_IF_IOS4_OR_GREATER([dc addObserver:self selector:@selector(synchronizeSettings) name:UIApplicationDidEnterBackgroundNotification object:[UIApplication sharedApplication]];);
	IASK_IF_IOS4_OR_GREATER([dc addObserver:self selector:@selector(reload) name:UIApplicationWillEnterForegroundNotification object:[UIApplication sharedApplication]];);
	[dc addObserver:self selector:@selector(synchronizeSettings) name:UIApplicationWillTerminateNotification object:[UIApplication sharedApplication]];

	[dc addObserver:self
											 selector:@selector(_keyboardWillShow:)
												 name:UIKeyboardWillShowNotification
											   object:nil];
	[dc addObserver:self
											 selector:@selector(_keyboardWillHide:)
												 name:UIKeyboardWillHideNotification
											   object:nil];		
}

- (void)viewWillDisappear:(BOOL)animated {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
	if ([self.currentFirstResponder canResignFirstResponder]) {
		[self.currentFirstResponder resignFirstResponder];
	}
	[super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
	NSNotificationCenter *dc = [NSNotificationCenter defaultCenter];
	IASK_IF_IOS4_OR_GREATER([dc removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];);
	IASK_IF_IOS4_OR_GREATER([dc removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];);
	[dc removeObserver:self name:UIApplicationWillTerminateNotification object:nil];
	[dc removeObserver:self name:UIKeyboardWillHideNotification object:nil];
	
	if (!self.navigationController && self.delegate && [self.delegate conformsToProtocol:@protocol(IASKSettingsDelegate)]) {
		[self.delegate settingsViewControllerDidEnd:self];
	}
	
	[super viewDidDisappear:animated];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
	return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? UIInterfaceOrientationMaskAll : UIInterfaceOrientationMaskAllButUpsideDown;
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark -
#pragma mark Actions

- (IBAction)dismiss:(id)sender {
	if ([self.currentFirstResponder canResignFirstResponder]) {
		[self.currentFirstResponder resignFirstResponder];
	}
	
	[self.settingsStore synchronize];
	
	if (self.delegate && [self.delegate conformsToProtocol:@protocol(IASKSettingsDelegate)]) {
		[self.delegate settingsViewControllerDidEnd:self];
	}
}

- (void)toggledValue:(id)sender {
    IASKSwitch *toggle    = (IASKSwitch*)sender;
    IASKSpecifier *spec   = [_settingsReader specifierForKey:toggle.key];
    
    if (toggle.on) {
        if ([spec trueValue] != nil) {
            [self.settingsStore setObject:[spec trueValue] forKey:toggle.key];
        }
        else {
            [self.settingsStore setBool:YES forKey:toggle.key]; 
        }
    }
    else {
        if ([spec falseValue] != nil) {
            [self.settingsStore setObject:[spec falseValue] forKey:toggle.key];
        }
        else {
            [self.settingsStore setBool:NO forKey:toggle.key]; 
        }
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kIASKAppSettingChanged
                                                        object:toggle.key
                                                      userInfo:@{toggle.key: [self.settingsStore objectForKey:toggle.key]}];
}

- (void)sliderChangedValue:(id)sender {
    IASKSlider *slider = (IASKSlider*)sender;
    [self.settingsStore setFloat:slider.value forKey:slider.key];
    [[NSNotificationCenter defaultCenter] postNotificationName:kIASKAppSettingChanged
                                                        object:slider.key
                                                      userInfo:@{slider.key: @(slider.value)}];
}


#pragma mark -
#pragma mark UITableView Functions

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return [self.settingsReader numberOfSections];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.settingsReader numberOfRowsForSection:section];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    IASKSpecifier *specifier  = [self.settingsReader specifierForIndexPath:indexPath];
    if ([[specifier type] isEqualToString:kIASKCustomViewSpecifier]) {
		if ([self.delegate respondsToSelector:@selector(tableView:heightForSpecifier:)]) {
			return [self.delegate tableView:_tableView heightForSpecifier:specifier];
		} else {
			return 0;
		}
	}
	return tableView.rowHeight;
}

- (NSString *)tableView:(UITableView*)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *header = [self.settingsReader titleForSection:section];
	if (0 == header.length) {
		return nil;
	}
	return header;
}

- (UIView *)tableView:(UITableView*)tableView viewForHeaderInSection:(NSInteger)section {
	NSString *key  = [self.settingsReader keyForSection:section];
	if ([self.delegate respondsToSelector:@selector(tableView:viewForHeaderForKey:)]) {
		return [self.delegate tableView:_tableView viewForHeaderForKey:key];
	} else {
		return nil;
	}
}

- (CGFloat)tableView:(UITableView*)tableView heightForHeaderInSection:(NSInteger)section {
	NSString *key  = [self.settingsReader keyForSection:section];
	if ([self tableView:tableView viewForHeaderInSection:section] && [self.delegate respondsToSelector:@selector(tableView:heightForHeaderForKey:)]) {
		CGFloat result;
		if ((result = [self.delegate tableView:tableView heightForHeaderForKey:key]) != 0) {
			return result;
		}
		
	}
	NSString *title;
	if ((title = [self tableView:tableView titleForHeaderInSection:section])) {
		CGSize size = [title ec_sizeWithFont:[UIFont boldSystemFontOfSize:[UIFont labelFontSize]]
						   constrainedToSize:CGSizeMake(tableView.frame.size.width - 2*kIASKHorizontalPaddingGroupTitles, INFINITY)
							   lineBreakMode:NSLineBreakByWordWrapping];
		return ceil(size.height)+kIASKVerticalPaddingGroupTitles;
	}
	return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
	NSString *footerText = [self.settingsReader footerTextForSection:section];
	if (_showCreditsFooter && (section == [self.settingsReader numberOfSections]-1)) {
		// show credits since this is the last section
		if ((footerText == nil) || (footerText.length == 0)) {
			// show the credits on their own
			return kIASKCredits;
		} else {
			// show the credits below the app's FooterText
			return [NSString stringWithFormat:@"%@\n\n%@", footerText, kIASKCredits];
		}
	} else {
		if (footerText.length == 0) {
			return nil;
		}
		return [self.settingsReader footerTextForSection:section];
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    IASKSpecifier *specifier  = [self.settingsReader specifierForIndexPath:indexPath];
    NSString *key           = [specifier key];
    
    if ([[specifier type] isEqualToString:kIASKPSToggleSwitchSpecifier]) {
        IASKPSToggleSwitchSpecifierViewCell *cell = (IASKPSToggleSwitchSpecifierViewCell*)[tableView dequeueReusableCellWithIdentifier:[specifier type]];
        
        if (!cell) {
            cell = (IASKPSToggleSwitchSpecifierViewCell*) [[NSBundle mainBundle] loadNibNamed:@"IASKPSToggleSwitchSpecifierViewCell" 
																					   owner:self 
																					 options:nil][0];
			cell.label.font = [UIFont systemFontOfSize:17];
        }
        cell.label.text = [specifier title];

		id currentValue = [self.settingsStore objectForKey:key];
		BOOL toggleState;
		if (currentValue) {
			if ([currentValue isEqual:[specifier trueValue]]) {
				toggleState = YES;
			} else if ([currentValue isEqual:[specifier falseValue]]) {
				toggleState = NO;
			} else {
				toggleState = [currentValue boolValue];
			}
		} else {
			toggleState = [specifier defaultBoolValue];
		}
		cell.toggle.on = toggleState;
		
        [cell.toggle addTarget:self action:@selector(toggledValue:) forControlEvents:UIControlEventValueChanged];
        cell.toggle.key = key;
        return cell;
    }
    else if ([[specifier type] isEqualToString:kIASKPSMultiValueSpecifier]) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[specifier type]];
        
        if (!cell) {
            cell = [[IASKPSTitleValueSpecifierViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:[specifier type]];
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		}
        cell.textLabel.text = [specifier title];
		cell.detailTextLabel.text = [specifier titleForCurrentValue:[self.settingsStore objectForKey:key] != nil ? 
										 [self.settingsStore objectForKey:key] : [specifier defaultValue]].description;
        return cell;
    }
    else if ([[specifier type] isEqualToString:kIASKPSTitleValueSpecifier]) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[specifier type]];
        
        if (!cell) {
            cell = [[IASKPSTitleValueSpecifierViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:[specifier type]];
			cell.accessoryType = UITableViewCellAccessoryNone;
        }
		
		cell.textLabel.text = [specifier title];
		id value = [self.settingsStore objectForKey:key] ? : [specifier defaultValue];
		
		NSString *stringValue;
		if ([specifier multipleValues] || [specifier multipleTitles]) {
			stringValue = [specifier titleForCurrentValue:value];
		} else {
			stringValue = [value description];
		}

		cell.detailTextLabel.text = stringValue;
		[cell setUserInteractionEnabled:NO];
		
        return cell;
    }
    else if ([[specifier type] isEqualToString:kIASKPSTextFieldSpecifier]) {
        IASKPSTextFieldSpecifierViewCell *cell = (IASKPSTextFieldSpecifierViewCell*)[tableView dequeueReusableCellWithIdentifier:[specifier type]];

        if (!cell) {
            cell = (IASKPSTextFieldSpecifierViewCell*) [[NSBundle mainBundle] loadNibNamed:@"IASKPSTextFieldSpecifierViewCell" 
                                                                                      owner:self 
                                                                                    options:nil][0];

            cell.textField.textAlignment = NSTextAlignmentLeft;
            cell.textField.returnKeyType = UIReturnKeyDone;
            cell.accessoryType = UITableViewCellAccessoryNone;
        }

        cell.label.text = [specifier title];      
      
        NSString *textValue = [self.settingsStore objectForKey:key] != nil ? [self.settingsStore objectForKey:key] : [specifier defaultStringValue];
        if (![textValue isMemberOfClass:[NSString class]]) {
            textValue = [NSString stringWithFormat:@"%@", textValue];
        }
        cell.textField.text = textValue;

        cell.textField.key = key;
        cell.textField.delegate = self;
        [cell.textField addTarget:self action:@selector(_textChanged:) forControlEvents:UIControlEventEditingChanged];
        cell.textField.secureTextEntry = [specifier isSecure];
        cell.textField.keyboardType = [specifier keyboardType];
        cell.textField.autocapitalizationType = [specifier autocapitalizationType];
        cell.textField.autocorrectionType = [specifier autoCorrectionType];
        [cell setNeedsLayout];
        return cell;
    }
	else if ([[specifier type] isEqualToString:kIASKPSSliderSpecifier]) {
        IASKPSSliderSpecifierViewCell *cell = (IASKPSSliderSpecifierViewCell*)[tableView dequeueReusableCellWithIdentifier:[specifier type]];
        
        if (!cell) {
            cell = (IASKPSSliderSpecifierViewCell*) [[NSBundle mainBundle] loadNibNamed:@"IASKPSSliderSpecifierViewCell" 
																				 owner:self 
																			   options:nil][0];
		}
        
        if ([specifier minimumValueImage].length > 0) {
            cell.minImage.image = [UIImage imageWithContentsOfFile:[_settingsReader pathForImageNamed:[specifier minimumValueImage]]];
        }
		
        if ([specifier maximumValueImage].length > 0) {
            cell.maxImage.image = [UIImage imageWithContentsOfFile:[_settingsReader pathForImageNamed:[specifier maximumValueImage]]];
        }
        
        cell.slider.minimumValue = [specifier minimumValue];
        cell.slider.maximumValue = [specifier maximumValue];
        cell.slider.value = [self.settingsStore objectForKey:key] != nil ? 
		 [[self.settingsStore objectForKey:key] floatValue] : [[specifier defaultValue] floatValue];
        [cell.slider addTarget:self action:@selector(sliderChangedValue:) forControlEvents:UIControlEventValueChanged];
        cell.slider.key = key;
		[cell setNeedsLayout];
        return cell;
    }
    else if ([[specifier type] isEqualToString:kIASKPSChildPaneSpecifier]) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[specifier type]];
        
        if (!cell) {
            cell = [[IASKPSTitleValueSpecifierViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:[specifier type]];
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }

        cell.textLabel.text = [specifier title];
        return cell;
    } else if ([[specifier type] isEqualToString:kIASKOpenURLSpecifier]) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[specifier type]];
        
        if (!cell) {
            cell = [[IASKPSTitleValueSpecifierViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:[specifier type]];
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }

		cell.textLabel.text = [specifier title];
		cell.detailTextLabel.text = [[specifier defaultValue] description];
		return cell;        
    } else if ([[specifier type] isEqualToString:kIASKButtonSpecifier]) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[specifier type]];
		
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:[specifier type]];
        }
        cell.textLabel.text = [specifier title];
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        return cell;
    } else if ([[specifier type] isEqualToString:kIASKMailComposeSpecifier]) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[specifier type]];
        
        if (!cell) {
            cell = [[IASKPSTitleValueSpecifierViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:[specifier type]];
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
        
		cell.textLabel.text = [specifier title];
		cell.detailTextLabel.text = [[specifier defaultValue] description];
		return cell;
    } else if ([[specifier type] isEqualToString:kIASKCustomViewSpecifier] && [self.delegate respondsToSelector:@selector(tableView:cellForSpecifier:)]) {
		return [self.delegate tableView:_tableView cellForSpecifier:specifier];
		
	} else {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[specifier type]];
		
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:[specifier type]];
        }
        cell.textLabel.text = [specifier title];
        return cell;
    }
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	IASKSpecifier *specifier  = [self.settingsReader specifierForIndexPath:indexPath];
	
	if ([[specifier type] isEqualToString:kIASKPSToggleSwitchSpecifier]) {
		return nil;
	} else {
		return indexPath;
	}
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    IASKSpecifier *specifier  = [self.settingsReader specifierForIndexPath:indexPath];
    
    if ([[specifier type] isEqualToString:kIASKPSToggleSwitchSpecifier]) {
        [tableView deselectRowAtIndexPath:indexPath animated:NO];
    }
    else if ([[specifier type] isEqualToString:kIASKPSMultiValueSpecifier]) {
        IASKSpecifierValuesViewController *targetViewController = _viewList[kIASKSpecifierValuesViewControllerIndex][@"viewController"];
		
        if (targetViewController == nil) {
            // the view controller has not been created yet, create it and set it to our viewList array
            // create a new dictionary with the new view controller
            NSMutableDictionary *newItemDict = [NSMutableDictionary dictionaryWithCapacity:3];
            [newItemDict addEntriesFromDictionary: _viewList[kIASKSpecifierValuesViewControllerIndex]];	// copy the title and explain strings
            
            targetViewController = [[IASKSpecifierValuesViewController alloc] initWithNibName:@"IASKSpecifierValuesView" bundle:nil];
            // add the new view controller to the dictionary and then to the 'viewList' array
            newItemDict[@"viewController"] = targetViewController;
            _viewList[kIASKSpecifierValuesViewControllerIndex] = newItemDict;
            
            // load the view controll back in to push it
            targetViewController = _viewList[kIASKSpecifierValuesViewControllerIndex][@"viewController"];
        }
        self.currentIndexPath = indexPath;
        targetViewController.currentSpecifier = specifier;
        targetViewController.settingsReader = self.settingsReader;
        targetViewController.settingsStore = self.settingsStore;
        [self.navigationController pushViewController:targetViewController animated:YES];
    }
    else if ([[specifier type] isEqualToString:kIASKPSSliderSpecifier]) {
        [tableView deselectRowAtIndexPath:indexPath animated:NO];
    }
    else if ([[specifier type] isEqualToString:kIASKPSTextFieldSpecifier]) {
		IASKPSTextFieldSpecifierViewCell *textFieldCell = (id)[tableView cellForRowAtIndexPath:indexPath];
		[textFieldCell.textField becomeFirstResponder];
    }
    else if ([[specifier type] isEqualToString:kIASKPSChildPaneSpecifier]) {

        
        Class vcClass = [specifier viewControllerClass];
        if (vcClass) {
            SEL initSelector = [specifier viewControllerSelector];
            if (!initSelector) {
                initSelector = @selector(init);
            }
            UIViewController * vc = [vcClass alloc];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [vc performSelector:initSelector withObject:[specifier file] withObject:[specifier key]];
#pragma clang diagnostic pop
			if ([vc respondsToSelector:@selector(setDelegate:)]) {
				[vc performSelector:@selector(setDelegate:) withObject:self.delegate];
			}
			if ([vc respondsToSelector:@selector(setSettingsStore:)]) {
				[vc performSelector:@selector(setSettingsStore:) withObject:self.settingsStore];
			}
			
            [self.navigationController pushViewController:vc animated:YES];
            return;
        }
        
        if (nil == [specifier file]) {
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
            return;
        }        
        
        IASKAppSettingsViewController *targetViewController = _viewList[kIASKSpecifierChildViewControllerIndex][@"viewController"];
		
        if (targetViewController == nil) {
            // the view controller has not been created yet, create it and set it to our viewList array
            // create a new dictionary with the new view controller
            NSMutableDictionary *newItemDict = [NSMutableDictionary dictionaryWithCapacity:3];
            [newItemDict addEntriesFromDictionary: _viewList[kIASKSpecifierChildViewControllerIndex]];	// copy the title and explain strings
            
            targetViewController = [[[self class] alloc] initWithNibName:@"IASKAppSettingsView" bundle:nil];
			targetViewController.showDoneButton = NO;
			targetViewController.settingsStore = self.settingsStore; 
			targetViewController.delegate = self.delegate;

            // add the new view controller to the dictionary and then to the 'viewList' array
            newItemDict[@"viewController"] = targetViewController;
            _viewList[kIASKSpecifierChildViewControllerIndex] = newItemDict;
            
            // load the view controll back in to push it
            targetViewController = _viewList[kIASKSpecifierChildViewControllerIndex][@"viewController"];
        }
        self.currentIndexPath = indexPath;
		targetViewController.file = specifier.file;
		targetViewController.title = specifier.title;
        targetViewController.showCreditsFooter = NO;
        [self.navigationController pushViewController:targetViewController animated:YES];
    } else if ([[specifier type] isEqualToString:kIASKOpenURLSpecifier]) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:specifier.file]];    
    } else if ([[specifier type] isEqualToString:kIASKButtonSpecifier]) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
		Class buttonClass = [specifier buttonClass];
		SEL buttonAction = [specifier buttonAction];
		if ([buttonClass respondsToSelector:buttonAction]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
			[buttonClass performSelector:buttonAction withObject:self withObject:[specifier key]];
#pragma clang diagnostic pop
		}
    } else if ([[specifier type] isEqualToString:kIASKMailComposeSpecifier]) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        if ([MFMailComposeViewController canSendMail]) {
            MFMailComposeViewController *mailViewController = [[MFMailComposeViewController alloc] init];
            
            if ([specifier localizedObjectForKey:kIASKMailComposeSubject]) {
                [mailViewController setSubject:[specifier localizedObjectForKey:kIASKMailComposeSubject]];
            }
            if (specifier.specifierDict[kIASKMailComposeToRecipents]) {
                [mailViewController setToRecipients:specifier.specifierDict[kIASKMailComposeToRecipents]];
            }
            if (specifier.specifierDict[kIASKMailComposeCcRecipents]) {
                [mailViewController setCcRecipients:specifier.specifierDict[kIASKMailComposeCcRecipents]];
            }
            if (specifier.specifierDict[kIASKMailComposeBccRecipents]) {
                [mailViewController setBccRecipients:specifier.specifierDict[kIASKMailComposeBccRecipents]];
            }
            if ([specifier localizedObjectForKey:kIASKMailComposeBody]) {
                BOOL isHTML = NO;
                if (specifier.specifierDict[kIASKMailComposeBodyIsHTML]) {
                    isHTML = [specifier.specifierDict[kIASKMailComposeBodyIsHTML] boolValue];
                }
                
                if ([self.delegate respondsToSelector:@selector(mailComposeBody)]) {
                    [mailViewController setMessageBody:[self.delegate mailComposeBody] isHTML:isHTML];
                }
                else {
                    [mailViewController setMessageBody:[specifier localizedObjectForKey:kIASKMailComposeBody] isHTML:isHTML];
                }
            }

            UIViewController<MFMailComposeViewControllerDelegate> *vc = nil;
            
            if ([self.delegate respondsToSelector:@selector(viewControllerForMailComposeView)]) {
                vc = [self.delegate viewControllerForMailComposeView];
            }
            
            if (vc == nil) {
                vc = self;
            }
            
            mailViewController.mailComposeDelegate = vc;
            [vc presentViewController:mailViewController animated:YES completion:nil];
        } else {
            UIAlertView *alert = [[UIAlertView alloc]
                                  initWithTitle:NSLocalizedString(@"Mail not configured", @"InAppSettingsKit")
                                  message:NSLocalizedString(@"This device is not configured for sending Email. Please configure the Mail settings in the Settings app.", @"InAppSettingsKit")
                                  delegate: nil
                                  cancelButtonTitle:NSLocalizedString(@"OK", @"InAppSettingsKit")
                                  otherButtonTitles:nil];
            [alert show];
        }

	} else {
        [tableView deselectRowAtIndexPath:indexPath animated:NO];
    }
}


#pragma mark -
#pragma mark MFMailComposeViewControllerDelegate Function

-(void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
    // NOTE: No error handling is done here
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark -
#pragma mark UITextFieldDelegate Functions

- (void)_textChanged:(id)sender {
    IASKTextField *text = (IASKTextField*)sender;
    [_settingsStore setObject:text.text forKey:text.key];
    [[NSNotificationCenter defaultCenter] postNotificationName:kIASKAppSettingChanged
                                                        object:text.key
                                                      userInfo:@{text.key: text.text}];
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
	textField.textAlignment = NSTextAlignmentLeft;
	self.currentFirstResponder = textField;
    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
	self.currentFirstResponder = textField;
	if (_tableView.indexPathsForVisibleRows.count) {
		_topmostRowBeforeKeyboardWasShown = (NSIndexPath*)_tableView.indexPathsForVisibleRows[0];
	} else {
		// this should never happen
		_topmostRowBeforeKeyboardWasShown = [NSIndexPath indexPathForRow:0 inSection:0];
		[textField resignFirstResponder];
	}
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
	self.currentFirstResponder = nil;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField{
    [textField resignFirstResponder];
	return YES;
}

#pragma mark Keyboard Management
- (void)_keyboardWillShow:(NSNotification*)notification {
	if (self.navigationController.topViewController == self) {
		NSDictionary* userInfo = notification.userInfo;

		// we don't use SDK constants here to be universally compatible with all SDKs ≥ 3.0
		NSValue* keyboardFrameValue = userInfo[@"UIKeyboardBoundsUserInfoKey"];
		if (!keyboardFrameValue) {
			keyboardFrameValue = userInfo[@"UIKeyboardFrameEndUserInfoKey"];
		}
		
		// Reduce the tableView height by the part of the keyboard that actually covers the tableView
		CGRect windowRect = [UIApplication sharedApplication].keyWindow.bounds;
		if (UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)) {
			windowRect = IASKCGRectSwap(windowRect);
		}
		CGRect viewRectAbsolute = [_tableView convertRect:_tableView.bounds toView:[UIApplication sharedApplication].keyWindow];
		if (UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)) {
			viewRectAbsolute = IASKCGRectSwap(viewRectAbsolute);
		}
		CGRect frame = _tableView.frame;
		frame.size.height -= [keyboardFrameValue CGRectValue].size.height - CGRectGetMaxY(windowRect) + CGRectGetMaxY(viewRectAbsolute);

		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:[userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue]];
		[UIView setAnimationCurve:[userInfo[UIKeyboardAnimationCurveUserInfoKey] intValue]];
		_tableView.frame = frame;
		[UIView commitAnimations];
		
		UITableViewCell *textFieldCell = (id)((UITextField *)self.currentFirstResponder).superview.superview;
		NSIndexPath *textFieldIndexPath = [_tableView indexPathForCell:textFieldCell];

		// iOS 3 sends hide and show notifications right after each other
		// when switching between textFields, so cancel -scrollToOldPosition requests
		[NSObject cancelPreviousPerformRequestsWithTarget:self];
		
		[_tableView scrollToRowAtIndexPath:textFieldIndexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
	}
}


- (void) scrollToOldPosition {
  [_tableView scrollToRowAtIndexPath:_topmostRowBeforeKeyboardWasShown atScrollPosition:UITableViewScrollPositionTop animated:YES];
}

- (void)_keyboardWillHide:(NSNotification*)notification {
	if (self.navigationController.topViewController == self) {
		NSDictionary* userInfo = notification.userInfo;
		
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:[userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue]];
		[UIView setAnimationCurve:[userInfo[UIKeyboardAnimationCurveUserInfoKey] intValue]];
		_tableView.frame = self.view.bounds;
		[UIView commitAnimations];
		
		[self performSelector:@selector(scrollToOldPosition) withObject:nil afterDelay:0.1];
	}
}	

#pragma mark Notifications

- (void)synchronizeSettings {
    [_settingsStore synchronize];
}

- (void)reload {
	// wait 0.5 sec until UI is available after applicationWillEnterForeground
	[_tableView performSelector:@selector(reloadData) withObject:nil afterDelay:0.5];
}

#pragma mark CGRect Utility function
CGRect IASKCGRectSwap(CGRect rect) {
	CGRect newRect;
	newRect.origin.x = rect.origin.y;
	newRect.origin.y = rect.origin.x;
	newRect.size.width = rect.size.height;
	newRect.size.height = rect.size.width;
	return newRect;
}
@end
