#import "LXBrowser.h"
@implementation LXBrowser { NSArray *_filtered;UISearchController *_search; }
- (void)viewDidLoad {
 [super viewDidLoad];_search=[[UISearchController alloc] initWithSearchResultsController:nil];_search.searchResultsUpdater=self;_search.obscuresBackgroundDuringPresentation=NO;self.navigationItem.searchController=_search;self.definesPresentationContext=YES;_filtered=self.rows ?: @[];
}
- (void)setRows:(NSArray *)rows { _rows=rows;[self updateSearchResultsForSearchController:_search]; }
- (void)updateSearchResultsForSearchController:(UISearchController *)controller {
 NSString *q=controller.searchBar.text ?: @"";
 _filtered=q.length?[self.rows filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *row,NSDictionary *bindings) { (void)bindings;return [row[@"title"] rangeOfString:q options:NSCaseInsensitiveSearch].location!=NSNotFound || [row[@"subtitle"] rangeOfString:q options:NSCaseInsensitiveSearch].location!=NSNotFound; }]]:self.rows;
 [self.tableView reloadData];
}
- (NSInteger)tableView:(UITableView *)view numberOfRowsInSection:(NSInteger)section { (void)view;(void)section;return _filtered.count; }
- (UITableViewCell *)tableView:(UITableView *)view cellForRowAtIndexPath:(NSIndexPath *)path {
 UITableViewCell *cell=[view dequeueReusableCellWithIdentifier:@"row"] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"row"];
 NSDictionary *row=_filtered[path.row];cell.textLabel.text=row[@"title"];cell.detailTextLabel.text=row[@"subtitle"];cell.detailTextLabel.numberOfLines=2;BOOL enabled=!row[@"enabled"] || [row[@"enabled"] boolValue];cell.userInteractionEnabled=enabled;cell.textLabel.textColor=enabled?UIColor.labelColor:UIColor.secondaryLabelColor;cell.accessoryType=enabled?UITableViewCellAccessoryDisclosureIndicator:UITableViewCellAccessoryNone;return cell;
}
- (void)tableView:(UITableView *)view didSelectRowAtIndexPath:(NSIndexPath *)path { [view deselectRowAtIndexPath:path animated:YES];if(self.selected) self.selected(_filtered[path.row]); }
@end
void LXAlert(UIViewController *vc,NSString *message) {
 UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Runtime Atlas" message:message preferredStyle:UIAlertControllerStyleAlert];[a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];[vc presentViewController:a animated:YES completion:nil];
}
void LXShowJSON(UIViewController *vc,NSString *title,id json) {
 UIViewController *detail=[UIViewController new];detail.title=title;UITextView *text=[UITextView new];text.editable=NO;text.font=[UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];text.backgroundColor=UIColor.systemBackgroundColor;
 NSData *data=[NSJSONSerialization dataWithJSONObject:json options:NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys error:nil];text.text=[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"No data";detail.view=text;[vc.navigationController pushViewController:detail animated:YES];
}
