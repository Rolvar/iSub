//
//  CustomUITableViewController.h
//  iSub
//
//  Created by Benjamin Baron on 10/9/13.
//  Copyright (c) 2013 Ben Baron. All rights reserved.
//

@interface CustomUITableViewController : UITableViewController

#pragma mark - UI -

#pragma mark Initial Setup
- (UIView *)setupHeaderView;
- (void)customizeTableView:(UITableView *)tableView;
- (UIBarButtonItem *)setupLeftBarButton;
- (UIBarButtonItem *)setupRightBarButton;

#pragma mark Pull to Refresh
- (BOOL)shouldSetupRefreshControl; // Override and return YES to use pull to refresh, otherwise implemented automatically
- (void)setupRefreshControl;
- (void)didPullToRefresh; // Override to perform an action after user pulls to refresh

#pragma mark Other

- (void)showDeleteToggles;
- (void)hideDeleteToggles;
- (void)markCellAsPlayingAtIndexPath:(NSIndexPath *)indexPath;

@end
