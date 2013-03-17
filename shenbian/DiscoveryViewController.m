//
//  DiscoveryViewController.m
//  shenbian
//
//  Created by MagicYang on 4/7/11.
//  Copyright 2011 百度. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "DiscoveryViewController.h"
#import "HomeViewController.h"
#import "VSTabBarController.h"
#import "ProvincePickerViewController.h"
#import "HelpViewController.h"
#import "CommodityPhotoDetailVC.h"

#import "SBSubcategoryTabView.h"
#import "VSSegmentCell.h"
#import "SBSegmentView.h"
#import "DiscoveryCellView.h"
#import "CustomCell.h"
#import "SBLocationView.h"
#import "SBNoResultView.h"

#import "DatasourceDiscovery.h"
#import "SBCommodityList.h"
#import "SBLocation.h"

#import "LocationService.h"
#import "Notifications.h"
#import "CacheCenter.h"
#import "TKAlertCenter.h"
#import "Utility.h"

@interface DiscoveryViewController() 

- (void)showNotFoundView;
- (void)hideNotFoundView;

@end

@implementation DiscoveryViewController

@synthesize tableView = _tableView;


#pragma mark - public

- (void)selectLatestTab
{
//    int lastIndex = [datasource.tabs count] -1;
//    if (lastIndex > 0) {
//        titleTabView.selectedIndex = lastIndex;
//        [self reloadDataAtTab:lastIndex subTab:-1];
//    }    
    int lastIndex = [datasource mappingIndexWithMainTab:MainTab_Newest];
    titleTabView.selectedIndex = lastIndex;
    [self reloadDataAtTab:lastIndex subTab:-1];
}

#pragma mark - NSObject

- (id)init {
	self = [super init];
	datasource = [[DatasourceDiscovery alloc] init];
	[datasource addDelegate:self];
    
	[Notifier addObserver:self selector:@selector(cityChanged:) name:kCityChanged object:nil];
    [Notifier addObserver:self selector:@selector(getLocationSuccessed:) name:kLocationSuccessed object:nil];
    [Notifier addObserver:self selector:@selector(getLocationFailed:) name:kLocationFailed object:nil];
    [Notifier addObserver:self selector:@selector(guideDismissed) name:kGuideDissmissed object:nil];
	return self;
}

- (void)dealloc
{
	[Notifier removeObserver:self name:kCityChanged object:nil];
    [Notifier removeObserver:self name:kLocationSuccessed object:nil];
    [Notifier removeObserver:self name:kLocationFailed object:nil];
	[Notifier removeObserver:self name:kGuideDissmissed object:nil];
    
	VSSafeRelease(locationFloatView);
	VSSafeRelease(_tableView);
	VSSafeRelease(headerTabView);
	VSSafeRelease(titleTabView);
	VSSafeRelease(datasource);
    VSSafeRelease(refreshFooter);
    VSSafeRelease(refreshHeader);
    VSSafeRelease(noResultView);
    [super dealloc];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    
    Release(_tableView);
    Release(headerTabView);
    Release(titleTabView);
    Release(refreshHeader);
    Release(locationFloatView);
}

- (void)loadView
{
	[super loadView];
	
    self.view.backgroundColor = [UIColor clearColor];
    
	_tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
	_tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
	_tableView.delegate = self;
	_tableView.dataSource = self;
    _tableView.backgroundColor = [UIColor clearColor];
	_tableView.height = 460 - 44 - 49;
	_tableView.scrollsToTop = YES;
	[self addSubview:_tableView];
	
	headerTabView = [[SBSubcategoryTabView alloc] initWithFixedSize];
	headerTabView.bottom = 0;
	[self addSubview:headerTabView];	
	headerTabView.delegate = self;

	
	titleTabView = [[SBSegmentView alloc] init];
	titleTabView.delegate = self;
//	self.navigationItem.titleView = titleTabView;
	
	//refreshView
	refreshHeader = [[EGORefreshTableHeaderView alloc] initWithFrame:CGRectMake(0, -self.tableView.height, 320, self.tableView.height)];
	refreshHeader.delegate = self;
	refreshHeader.downText = NSLocalizedString(@"下拉刷新",@"pull to refresh");
	refreshHeader.releaseText = NSLocalizedString(@"松开刷新数据",@"release to refresh");
	refreshHeader.loadingText = NSLocalizedString(@"正在载入…",@"loading");

	[self.tableView addSubview:refreshHeader];
	
	//location float view
    SBLocation *location = [[LocationService sharedInstance] currentLocation];
    NSString *address = @"...";
    if (location) address = location.address;
	locationFloatView = [[SBLocationView alloc] initWithAddress:address andPosition:ccp(0,0)];
	locationFloatView.bottom = 460 - 49 - 44 + 5;
	[self.view addSubview:locationFloatView];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

	[headerTabView setDatasource:VSArray(@"",@"")];
	[[LocationService sharedInstance] startLocation];
	[self reloadRemoteData];
}

- (void)switchCity
{
    ProvincePickerViewController *controller = [[ProvincePickerViewController alloc] initWithDelegate:self];
    controller.title = @"选择城市";
    controller.isForceChoose = YES;
    controller.delegate = self;
    controller.hasTabbar = NO;
    controller.isCascadeCity = YES;
    controller.needLocating = YES;
    controller.hasCancelButton = YES;
    UINavigationController *nc = [[UINavigationController alloc] initWithRootViewController:controller];
    [self showModalViewController:nc animated:NO];
    [controller release];
    [nc release];
}

- (void)setupFooterRefreshView
{
	if (![datasource currentList].hasMore) {
		[refreshFooter removeFromSuperview];
		return;
	}
	
	if (!refreshFooter) {
		refreshFooter = [[EGORefreshTableFooterView alloc] initWithFrame:CGRectMake(0, self.tableView.contentSize.height, 320, self.tableView.height)];
		refreshFooter.upText = NSLocalizedString(@"上拉载入更多",@"pull to refresh");
		refreshFooter.releaseText = NSLocalizedString(@"松开载入更多",@"pull to refresh");
		refreshFooter.loadingText = NSLocalizedString(@"正在载入…",@"loading");
		refreshFooter.delegate = self;
	}
	
	[self.tableView addSubview:refreshFooter];
	refreshFooter.top = self.tableView.contentSize.height;

}

- (void)showCellAtIndex:(int)index
{
//	[self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]
//					 atScrollPosition:UITableViewScrollPositionTop animated:NO];
    CGRect curRect = [self.tableView rectForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
    [self.tableView scrollRectToVisible:curRect animated:YES];
}

- (void)guideDismissed
{
    SBLocation *location = [[LocationService sharedInstance] currentLocation];
    if (!location) {
        [self switchCity];
    } else {
        Area *city = [Area new];
        city.id = location.cityId;
        city.name = location.cityName;
        CurrentCity = city;
        [city release];
    }
}

#pragma mark - tab delegate

- (void)segment:(VSSegmentView*)segment clickedAtIndex:(int)index onCurrentCell:(BOOL)isCurrent{
	if (segment == titleTabView && !isCurrent) {
		[self reloadDataAtTab:index subTab:-1];
	}
	
	if (segment == headerTabView.segmentView && !isCurrent) {
		[self reloadDataAtTab:MainTab_Hot subTab:index];
	}
    
    if (datasource.currentMainTab == 0) {
        NSString *subTabName = [[datasource categories] objectAtIndex:datasource.currentMainTab];
        Stat(@"find_changetab?t=%d&subt=%@", datasource.currentMainTab, subTabName);
    } else {
        Stat(@"find_changetab?t=%d", datasource.currentMainTab);
    }
}

- (void)reloadDataAtTab:(int)index subTab:(int)subtab
{
    //save current CommodityList's status
    datasource.currentList.contentOffsetY = self.tableView.contentOffset.y;
	datasource.currentMainTab = [datasource mappingMainTabWithIndex:index];
    if (subtab != -1) {
        datasource.currentMainTab = index;
        datasource.currentSubTab  = subtab;
    }
	
	BOOL isShowCategoryList = NO;
	if (datasource.currentMainTab == 0 && datasource.categories.count > 0) 
	{
		isShowCategoryList = YES;
	}
	[self showCategorySegmentView:isShowCategoryList];
    
	[self.tableView  scrollRectToVisible:vsr(0, 0, 0, 0) animated:NO];
    [self.tableView reloadData];
    self.tableView.contentOffset = ccp(0, datasource.currentList.contentOffsetY); 

	[self setupFooterRefreshView];
	
	//check if content is empty
	if (datasource.currentList.array.count == 0 ) {
        [refreshHeader setInitLoadingState:self.tableView];
        isRefreshingHeader = YES;
		[self loadMoreDatas];
	}
  
}

- (void)showCategorySegmentView:(BOOL)isShow
{
	if(isShow){
		headerTabView.top = 0;
		self.tableView.top = headerTabView.bottom;
		self.tableView.height = 460 - 44 - 49 - headerTabView.height;
	}else {
		headerTabView.bottom = 0;
		self.tableView.top = 0;
		self.tableView.height = 460 - 44 - 49;
	}	
}

#pragma mark - tableviews
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
	return [datasource.currentList count];
}

- (float)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return [DiscoveryCellView heightOfCell:[datasource.currentList objectAtIndex:indexPath.row]];
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {	
	return indexPath;
}

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *CellIdentifier = @"Cell";
	UITableViewCell *cell = [table dequeueReusableCellWithIdentifier:CellIdentifier];

    if (cell == nil) {
        cell = [[[CustomCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = [UIColor whiteColor];
        DiscoveryCellView *cellView = [[DiscoveryCellView alloc] initWithFrame:cell.frame];
        ((CustomCell *)cell).cellView = cellView;
        [cellView release];
    }
	
    [((CustomCell *)cell) setDataModel:[datasource.currentList objectAtIndex:indexPath.row]];
    ((DiscoveryCellView*)((CustomCell *)cell).cellView).isLatestTab = [datasource isLatestTabForCurList];

    return cell;

}

- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
    SBCommodity *commodity = [datasource.currentList objectAtIndex:indexPath.row];
    
    if (datasource.currentMainTab == 0) {
        NSString *subTabName = [[datasource categories] objectAtIndex:datasource.currentMainTab];
        Stat(@"find_click?t=%d&subt=%@&r=%d&i_fcry=%@&s_fcry=%@&p_fcry=%@", 
             datasource.currentMainTab, subTabName, indexPath.row + 1, commodity.cid, commodity.sid, commodity.pid);
    } else {
        Stat(@"find_click?t=%d&r=%d&i_fcry=%@&s_fcry=%@&p_fcry=%@", 
             datasource.currentMainTab, indexPath.row + 1, commodity.cid, commodity.sid, commodity.pid);
    }
    

	CommodityPhotoDetailVC* vc = [[CommodityPhotoDetailVC alloc] initWithCommdity:commodity
																	  displayType:CommodityPhotoDetailTypeBoth
																	   Datasource:datasource
																	   previousVC:self];
	vc.from = CommodityPhotoSourceFromDiscovery;
    vc.tab = datasource.currentMainTab;
	[self.navigationController pushViewController:vc animated:YES];
	[vc release];
}


#pragma mark -
#pragma mark UIScrollViewDelegate Methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView{		
	if (datasource.currentList.hasMore){
		[refreshFooter egoRefreshScrollViewDidScroll:scrollView];
	}
	
	[refreshHeader egoRefreshScrollViewDidScroll:scrollView];	
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate{	
	
	if (datasource.currentList.hasMore) {
		[refreshFooter egoRefreshScrollViewDidEndDragging:scrollView];
	}
	[refreshHeader egoRefreshScrollViewDidEndDragging:scrollView];	
}


#pragma mark -
#pragma mark EGORefreshTableHeaderDelegate Methods
//header
- (void)egoRefreshTableHeaderDidTriggerRefresh:(EGORefreshTableHeaderView*)view{
    if (datasource.currentMainTab == 0) {
        NSString *subTabName = [[datasource categories] objectAtIndex:datasource.currentMainTab];
        Stat(@"find_downmore?t=%d&subt=%@", datasource.currentMainTab, subTabName);
    } else {
        Stat(@"find_downmore?t=%d", datasource.currentMainTab);
    }
    
    if (datasource.currentList) {
        [self reloadCurrentListData];
        [_tableView reloadData];
    } else {
        [self resetData]; // Load first data if there's no tab
    }
}

- (BOOL)egoRefreshTableHeaderDataSourceIsLoading:(EGORefreshTableHeaderView*)view{
	return isRefreshingHeader; // should return if data source model is reloading
}

//footer
- (void)egoRefreshTableFooterDidTriggerRefresh:(EGORefreshTableFooterView *)view{
    if (datasource.currentMainTab == 0) {
        NSString *subTabName = [[datasource categories] objectAtIndex:datasource.currentSubTab];
        Stat(@"find_upmore?t=%d&subt=%@", datasource.currentMainTab, subTabName);
    } else {
        Stat(@"find_upmore?t=%d", datasource.currentMainTab);
    }
    
	[self loadMoreDatas];
}

- (BOOL)egoRefreshTableFooterDataSourceIsLoading:(EGORefreshTableFooterView *)view{
	return isRefreshingFooter;
}

- (void)finishedHttpClientReload
{
	isRefreshingHeader = NO;
	[refreshHeader egoRefreshScrollViewDataSourceDidFinishedLoading:self.tableView];
}

- (void)finishedHttpClientLoadmore
{
	isRefreshingFooter = NO;
	[refreshFooter egoRefreshScrollViewDataSourceDidFinishedLoading:self.tableView];	
}

- (NSDate*)egoRefreshTableFooterDataSourceLastUpdated:(EGORefreshTableFooterView *)v {
	return [NSDate date]; // should return date data source was last changed
}

- (NSDate*)egoRefreshTableHeaderDataSourceLastUpdated:(EGORefreshTableHeaderView *)v {
	return [NSDate date]; // should return date data source was last changed
}

#pragma mark -
#pragma mark loading remote datasource 

- (void)reloadCurrentListData
{
    isRefreshingHeader = YES;
    [datasource loadDataRefreshForCurrentList];
}

- (void)reloadRemoteData
{
    // 避免第一次安装App时，没有定位或选择city时发送discover请求，导致出现NoResult界面
    if (CurrentCityId == 0) return;
    
	if (datasource.currentList.array.count == 0) {
		[refreshHeader setInitLoadingState:self.tableView];
	}
	
	isRefreshingHeader = YES;
	[datasource loadFirstData];
}

- (void)loadMoreDatas
{
	isRefreshingFooter = YES;
    [datasource loadMoreForCurrentList];
}

- (void)checkNeedNoResult
{
    if ([datasource.currentList count] == 0) {
        [self showNotFoundView];
    } else {
        [self hideNotFoundView];
    }
}

#pragma mark - datasource delegate

- (void)datasource:(DatasourceDiscovery *)ds failedWithError:(NSError *)error
{
	[self finishedHttpClientReload];
	[self finishedHttpClientLoadmore];
    [self checkNeedNoResult];
}

- (void)datasource:(DatasourceDiscovery *)ds successLoaded:(BOOL)isInit
{
	if (isInit) {
		[self finishedHttpClientReload];
		if (datasource.categories.count >0) {
			[headerTabView setDatasource:datasource.categories];
			headerTabView.segmentView.selectedIndex = 0;
			
			headerTabView.top = 0;
			self.tableView.top = headerTabView.bottom - 3;
			self.tableView.height = 460 - 44 - 49 - headerTabView.height + 3;
		} else {
			headerTabView.bottom = 0;
			self.tableView.top = 0;
			self.tableView.height = 460 - 44 - 49;
		}
		[titleTabView setDatasource:datasource.tabs];
        self.navigationItem.titleView=titleTabView;
		titleTabView.selectedIndex = [datasource mappingIndexWithMainTab:datasource.currentMainTab];
        
        if (datasource.currentMainTab == 0) {
            NSString *subTabName = [[datasource categories] objectAtIndex:datasource.currentSubTab];
            Stat(@"find_into?t=%d&subt=%@", datasource.currentMainTab, subTabName);
        } else {
            Stat(@"find_into?t=%d", datasource.currentMainTab);
        }
	} else {
        [self finishedHttpClientReload];
		[self finishedHttpClientLoadmore];
	}

    //TODO: while in loadMore state, it's better to add ContentOffset in few pixels to indicate user more datas was loaded

	[self.tableView reloadData];
	
	[self setupFooterRefreshView];
    
    // Check if there's no result
    [self checkNeedNoResult];
}

#pragma mark - notifications

- (void)cityChanged:(id)sender 
{
    [self resetData];
}

- (void)getLocationSuccessed:(NSNotification *)notification 
{    
    SBLocation *location = [[LocationService sharedInstance] currentLocation];
    locationFloatView.address = location.address;
}

- (void)getLocationFailed:(NSNotification *)notification
{
    if ([[LocationService sharedInstance] currentLocation] && !isShowing) {
        return;
    }
    
    locationFloatView.address = @"...";
    
    if ([[notification object] isKindOfClass:[NSError class]]) {
        NSError *error = (NSError *)[notification object];
        if ([error code] == 1 && !hasAlertGPSEnabled) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"定位失败"
                                                            message:@"请确认是否开启定位服务"
                                                           delegate:self
                                                  cancelButtonTitle:@"确定"
                                                  otherButtonTitles:@"帮助", nil];
            alert.tag = 1;
            [alert show];
            [alert release];
            
            hasAlertGPSEnabled = YES;
        }
    } else {
//        TKAlert(@"定位失败");
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (buttonIndex != [alertView cancelButtonIndex]) {
        HelpViewController *controller = [HelpViewController new];
        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:controller];
        [self showModalViewController:navController animated:YES];
        [controller release];
        [navController release];
	}
}


#pragma mark - actions

- (void)onCellViewUserIconClicked:(SBCommodity*)item
{
    NSString* userID = item.uid;
    if (!userID) return;
    
    if (datasource.currentMainTab == 0) {
        NSString *subTabName = [[datasource categories] objectAtIndex:datasource.currentSubTab];
        Stat(@"find_clickportrait?t=%d&subt=%@&i_fcry=%@&s_fcry=%@&p_fcry=%@&u_fcry=%@",
             datasource.currentMainTab, subTabName, item.cid, item.sid, item.pid, item.uid);
    } else {
        Stat(@"find_clickportrait?t=%d&i_fcry=%@&s_fcry=%@&p_fcry=%@&u_fcry=%@",
             datasource.currentMainTab, item.cid, item.sid, item.pid, item.uid);
    }
    
    HomeViewController* homeVC = [[HomeViewController alloc] initWithUserID:userID];
    [self.navigationController pushViewController:homeVC animated:YES];
    [homeVC release];
}

- (void)resetData
{
    [headerTabView setDatasource:VSArray(@"",@"")];
    [datasource resetData];
    [_tableView reloadData];
    [self reloadRemoteData];
}


#pragma mark -
#pragma mark SBPickerDelegate
- (void)pickerController:(SBPickerViewController *)controller pickData:(SBObject *)data {
	Area *c = (Area *)data;
	[CacheCenter sharedInstance].currentCity = c;
    [self resetData];
	[controller dismissModalViewControllerAnimated:YES];
}

- (void)pickerControllerCancelled:(SBPickerViewController *)controller {
	[controller dismissModalViewControllerAnimated:YES];
}


#pragma mark-
#pragma PrivateMethods
- (void)showNotFoundView
{
    if (!noResultView) {
        noResultView = [[SBNoResultView alloc] initWithFrame:vsr(0, 50, 320, 340) andText:@"这个城市的美食拍客太懒了，目前没有图片，赶快来拍一张吧。"];
    }
	
	[self.view insertSubview:noResultView belowSubview:_tableView];
}

- (void)hideNotFoundView
{
    [noResultView removeFromSuperview];
}

@end