#import "ETRootListController.h"
#import <Preferences/PSSpecifier.h>
#import <Cephei/HBPreferences.h>
#import <notify.h>
#import "../shared/TemplateConfig.h"

@implementation ETRootListController {
    HBPreferences *_preferences;
}
- (instancetype)init {
    self = [super init];
    if (self) {
        _preferences = [[HBPreferences alloc] initWithIdentifier:ETPreferencesDomain];
        [_preferences registerDefaults:@{ETEnabledKey: @NO}];
    }
    return self;
}
- (NSArray *)specifiers {
    if (!_specifiers) _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    return _specifiers;
}
- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    return [_preferences objectForKey:key] ?: [specifier propertyForKey:@"default"];
}
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (![key isEqualToString:ETEnabledKey] || ![value isKindOfClass:NSNumber.class]) return;
    [_preferences setBool:[value boolValue] forKey:key];
    // Cephei documents this exact domain/ReloadPrefs convention for live refresh.
    NSString *notification = [specifier propertyForKey:@"PostNotification"];
    if (notification.length) notify_post(notification.UTF8String);
}
@end
