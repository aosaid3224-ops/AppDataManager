#import <UIKit/UIKit.h>

typedef void (^FileSelectedCallback)(NSString *path);

@interface IPAFileBrowserViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating>
@property (nonatomic, copy) FileSelectedCallback onFileSelected;
@property (nonatomic, strong) NSString *currentPath;
@end
