/*   Copyright 2014 APPNEXUS INC
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "CustomKeywordsTVC.h"
#import "AdSettings.h"
#import "AddCustomKeywordTVC.h"

static NSString *const kAppNexusSDKAppCustomKeywordCellIdentifier = @"customKeywordCell";
static NSTimeInterval const kAppNexusSDKAppDeleteTimeIntervalInSeconds = 0.7;

@interface CustomKeywordsTVC () <AddCustomKeywordToPersistentStoreDelegate>

@property (nonatomic, strong) NSArray *orderedKeys;
@property (nonatomic, strong) NSDictionary *customKeywords;
@property (nonatomic, strong) AdSettings *persistentSettings;

@property (nonatomic, assign) BOOL isDeleting;

@end

@implementation CustomKeywordsTVC

- (void)viewDidLoad {
    [self setEditBarButtonItemOnNavigationItemAnimated:NO];
    self.isDeleting = NO;
}

- (NSArray *)orderedKeys {
    if (!_orderedKeys) _orderedKeys = [[self customKeywords] keysSortedByValueUsingSelector:@selector(caseInsensitiveCompare:)];
    return _orderedKeys;
}

- (NSDictionary *)customKeywords {
    if (!_customKeywords) _customKeywords = [self.persistentSettings customKeywords];
    return _customKeywords;
}

- (AdSettings *)persistentSettings {
    if (!_persistentSettings) _persistentSettings = [[AdSettings alloc] init];
    return _persistentSettings;
}

#pragma mark Bar Button Items

- (void)setDoneBarButtonItemOnNavigationItemAnimated:(BOOL)animated {
    UIBarButtonItem *newItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                             target:self
                                                                             action:@selector(finishedEditTableViewItems:)];
    [self.navigationItem setLeftBarButtonItem:newItem animated:animated];
}

- (void)setEditBarButtonItemOnNavigationItemAnimated:(BOOL)animated {
    UIBarButtonItem *newItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"CircleMinus"]
                                                                style:UIBarButtonItemStylePlain
                                                               target:self
                                                               action:@selector(editTableViewItems:)];
    [self.navigationItem setLeftBarButtonItem:newItem animated:animated];
}

- (void)editTableViewItems:(UIBarButtonItem *)sender {
    if ([self.customKeywords count] > 0) {
        [self setEditing:YES animated:YES];
        [self setDoneBarButtonItemOnNavigationItemAnimated:YES];
    }
}

- (void)finishedEditTableViewItems:(UIBarButtonItem *)item {
    [self setEditing:NO animated:YES];
    [self setEditBarButtonItemOnNavigationItemAnimated:YES];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.customKeywords count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kAppNexusSDKAppCustomKeywordCellIdentifier forIndexPath:indexPath];
    NSString *key = [self.orderedKeys objectAtIndex:indexPath.item];
    NSString *value = [self.customKeywords objectForKey:key];
    [[cell textLabel] setText:key];
    [[cell detailTextLabel] setText:value];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [self deleteCustomKeywordAtIndexPath:indexPath];
    }
}

- (void)deleteCustomKeywordAtIndexPath:(NSIndexPath *)indexPath {
    NSLog(@"%@", NSStringFromSelector(_cmd));
    if (!self.isDeleting) {
        NSLog(@"%@ | will Delete", NSStringFromSelector(_cmd));
        self.isDeleting = YES;
        [NSTimer scheduledTimerWithTimeInterval:kAppNexusSDKAppDeleteTimeIntervalInSeconds
                                         target:self
                                       selector:@selector(postDeleteHandler:)
                                       userInfo:nil
                                        repeats:NO];
        NSMutableDictionary *mutableDict = [[self customKeywords] mutableCopy];
        NSString *key = [self.orderedKeys objectAtIndex:indexPath.item];
        [mutableDict removeObjectForKey:key];
        self.persistentSettings.customKeywords = [mutableDict copy];
        self.customKeywords = nil;
        self.orderedKeys = nil;
        [self.tableView beginUpdates];
        [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        [self.tableView endUpdates];
    }
}

- (void)postDeleteHandler:(NSTimer *)timer {
    self.isDeleting = NO;
    if (![self.customKeywords count] && self.isEditing) {
        [self finishedEditTableViewItems:nil];
    }
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.destinationViewController isKindOfClass:[AddCustomKeywordTVC class]]) {
        AddCustomKeywordTVC *destinationVC = (AddCustomKeywordTVC *)segue.destinationViewController;
        destinationVC.delegate = self;
        if ([sender isKindOfClass:[UITableViewCell class]]) {
            UITableViewCell *cell = (UITableViewCell *)sender;
            destinationVC.existingKey = [cell.textLabel text];
            destinationVC.existingValue = [cell.detailTextLabel text];
        }
    }
}

#pragma mark AddCustomKeywordToPersistentStoreDelegate methods

- (void)addCustomKeywordWithKey:(NSString *)key andValue:(NSString *)value {
    NSMutableDictionary *mutableDict = [[self customKeywords] mutableCopy];
    [mutableDict setObject:value forKey:key];
    self.persistentSettings.customKeywords = [mutableDict copy];
    self.customKeywords = nil;
    self.orderedKeys = nil;
    [self.tableView reloadData];
}

- (void)deleteCustomKeywordWithKey:(NSString *)key {
    NSMutableDictionary *mutableDict = [[self customKeywords] mutableCopy];
    [mutableDict removeObjectForKey:key];
    self.persistentSettings.customKeywords = [mutableDict copy];
    self.customKeywords = nil;
    self.orderedKeys = nil;
}

@end