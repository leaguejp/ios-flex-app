#import <UIKit/UIKit.h>
@interface LXBrowser : UITableViewController <UISearchResultsUpdating>
@property(nonatomic,strong) NSArray<NSDictionary *> *rows;
@property(nonatomic,copy) void (^selected)(NSDictionary *);
@end
void LXShowJSON(UIViewController *vc,NSString *title,id json);
void LXAlert(UIViewController *vc,NSString *message);
