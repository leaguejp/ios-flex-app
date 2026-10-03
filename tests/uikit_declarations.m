// Compile against the actual SDK, retaining normal override-signature diagnostics.
#import <UIKit/UIKit.h>
_Static_assert(sizeof(CGFloat)==sizeof(double),"Reviewed arm64 CGFloat wrapper requires double ABI");
@interface LXReviewedView : UIView
@end
@implementation LXReviewedView
- (void)setHidden:(BOOL)hidden { [super setHidden:hidden]; }
- (void)setAlpha:(CGFloat)alpha { [super setAlpha:alpha]; }
@end
@interface LXReviewedController : UIViewController
@end
@implementation LXReviewedController
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; }
- (void)viewDidAppear:(BOOL)animated { [super viewDidAppear:animated]; }
@end
