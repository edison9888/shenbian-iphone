//
//  UserPhotoListVC.m
//  shenbian
//
//  Created by xhan on 5/17/11.
//  Copyright 2011 百度. All rights reserved.
//

#import "UserPhotoListVC.h"
#import "HomeViewController.h"
#import "CommodityPhotoDetailVC.h"
#import "LoginController.h"
#import "DiscoveryCellView.h"
#import "CustomCell.h"
#import "CacheCenter.h"
#import "SBApiEngine.h"
#import "SBCommodityList.h"


@implementation UserPhotoListVC
//@synthesize tableView = _tableView;
@synthesize hasTabbar;
- (id)initWithUserID:(NSString*)ufcrid uiconPath:(NSString*)url uname:(NSString*)name uicon:(UIImage*)img
{
    self = [super init];    
    if (self) {
        self.hidesBottomBarWhenPushed = YES;
        userID = [ufcrid copy];
        userName = [name copy];
        userIconURL = [url copy];
        userICON = [img retain];
        lists = [[NSMutableArray alloc] init];
    }
    return self;    
}

- (void)dealloc
{
    VSSafeRelease(userName);
    VSSafeRelease(userICON);
    VSSafeRelease(userIconURL);
    
    CancelRequest(httpClient);
    CancelRequest(hcLoadMore);
//    VSSafeRelease(_tableView);
    VSSafeRelease(refreshFooter);
    VSSafeRelease(refreshHeader);
    VSSafeRelease(userID);
    VSSafeRelease(lists);
    VSSafeRelease(titleTabView);
    [super dealloc];
}


#pragma mark - View lifecycle

- (void)loadRefreshHeaderView 
{
    //refreshView -- header
	  refreshHeader = [[EGORefreshTableHeaderView alloc] initWithFrame:CGRectMake(0, -tableView.height, 320, tableView.height)];
	refreshHeader.delegate = self;
	refreshHeader.downText = NSLocalizedString(@"下拉刷新",@"pull to refresh");
	refreshHeader.releaseText = NSLocalizedString(@"松开刷新数据",@"release to refresh");
	refreshHeader.loadingText = NSLocalizedString(@"正在载入…",@"loading");

	[tableView addSubview:refreshHeader];
}


- (void)setupFooterRefreshView
{
   
        if ([lists count] >= picCountTotal) {
            [refreshFooter removeFromSuperview];
            return;
        }
	
	if (!refreshFooter) {
		refreshFooter = [[EGORefreshTableFooterView alloc] initWithFrame:CGRectMake(0, tableView.contentSize.height, 320, tableView.height)];
		refreshFooter.upText = NSLocalizedString(@"上拉载入更多",@"pull to refresh");
		refreshFooter.releaseText = NSLocalizedString(@"松开载入更多",@"pull to refresh");
		refreshFooter.loadingText = NSLocalizedString(@"正在载入…",@"loading");
		refreshFooter.delegate = self;
        
	}
	
	[tableView addSubview:refreshFooter];
	refreshFooter.top = tableView.contentSize.height;
    
}

- (void)initTableView {
	tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 320, 416) style:UITableViewStylePlain];
	tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
	tableView.delegate = self;
	tableView.dataSource = self;  
    tableView.backgroundColor = [UIColor clearColor];
}

- (void)loadView
{
	[super loadView];
    self.title = @"我的照片";    
	self.view.backgroundColor = [UIColor clearColor];
    
    [self loadRefreshHeaderView];

}


- (void)viewDidAppear:(BOOL)animated
{
	NSString *session = [NSString stringWithFormat:@"home_intomypic?u_fcry=%@", userID];
	Stat(session);
    [super viewDidAppear:animated];
    if ([lists count] == 0) {
        [self reloadRemoteData];
    }
}

- (void)viewDidLoad {
//    [self.navigationItem setHidesBackButton:YES];
    if (hasTabbar) {
        UIView *emptyView = [[UIView alloc] init];;
        UIBarButtonItem *emptyButton = [[[UIBarButtonItem alloc] initWithCustomView:emptyView] autorelease];
        [self.navigationItem setLeftBarButtonItem:emptyButton animated:NO];
        [emptyView release];
    
    }
    

	[super viewDidLoad];
	[self showLoading];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    CancelRequest(httpClient);
    CancelRequest(hcLoadMore);
//    VSSafeRelease(_tableView);
    VSSafeRelease(refreshFooter);
    VSSafeRelease(refreshHeader);    

}

#pragma mark - actions

- (void)reloadRemoteData
{
    [lists removeAllObjects];
    pageIndex = 0;
    picCountTotal = 0;
    offset=0;
    feedsPage=0;
    [tableView reloadData];
    
    BOOL isMyself = [CurrentAccount.uid isEqualToString:userID] ? 1 : 0;
    NSString* url =hasTabbar?[NSString stringWithFormat:@"%@/%@?u_fcrid=%@&pn=%d",ROOT_URL,@"getFeeds",CurrentAccount.uid,10]: [NSString stringWithFormat:@"%@/memberAlbums?myself=%d&u_fcrid=%@", 
                     ROOT_URL, isMyself, userID];
    
    if (!httpClient) {
        httpClient = [[HttpRequest alloc] init];
        httpClient.delegate = self;
    }
    isRefreshingHeader = YES;
    [httpClient requestGET:url useStat:YES];
}

- (void)loadMoreData
{
	pageIndex++;
    if (!hcLoadMore) {
        hcLoadMore = [[HttpRequest alloc] init];
        hcLoadMore.delegate = self;
    }
    NSString* url = hasTabbar?[NSString stringWithFormat:@"%@/%@?u_fcrid=%@&pn=%d&offset=%d&page=%d",ROOT_URL,@"getFeeds",CurrentAccount.uid,10,offset,feedsPage]:[NSString stringWithFormat:@"%@/%@?u_fcrid=%@&p=%d",ROOT_URL,@"memberAlbums",userID,pageIndex];
    isRefreshingFooter = YES;
    [hcLoadMore requestGET:url useStat:YES];
}

#pragma mark - EGORefreshTableViewDelegate Methods

/// header ////
- (void)egoRefreshTableHeaderDidTriggerRefresh:(EGORefreshTableHeaderView*)view{
    [self reloadRemoteData];    
}

- (BOOL)egoRefreshTableHeaderDataSourceIsLoading:(EGORefreshTableHeaderView*)view{	
	return isRefreshingHeader; // should return if data source model is reloading	
}

//footer
- (void)egoRefreshTableFooterDidTriggerRefresh:(EGORefreshTableFooterView *)view{
	[self loadMoreData];
}

- (BOOL)egoRefreshTableFooterDataSourceIsLoading:(EGORefreshTableFooterView *)view{
	return isRefreshingFooter;
}

- (void)finishedHttpClientReload
{
	isRefreshingHeader = NO;
	[refreshHeader egoRefreshScrollViewDataSourceDidFinishedLoading:tableView];
}

- (void)finishedHttpClientLoadmore
{
	isRefreshingFooter = NO;
	[refreshFooter egoRefreshScrollViewDataSourceDidFinishedLoading:tableView];	
}

#pragma mark -
#pragma mark UIScrollViewDelegate Methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView{		
	if ([lists count] < picCountTotal){
		[refreshFooter egoRefreshScrollViewDidScroll:scrollView];
	}
	
	[refreshHeader egoRefreshScrollViewDidScroll:scrollView];	
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate{	
	
	if ([lists count] < picCountTotal) {
		[refreshFooter egoRefreshScrollViewDidEndDragging:scrollView];
	}
	[refreshHeader egoRefreshScrollViewDidEndDragging:scrollView];	
}

#pragma mark - tableView

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
	return [lists count];
}

- (float)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
	return [DiscoveryCellView heightOfCell:[lists objectAtIndex:indexPath.row]];
}


- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [table dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
		cell = [[[CustomCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		cell.backgroundColor = [UIColor whiteColor];
		DiscoveryCellView *cellView = [[DiscoveryCellView alloc] initWithFrame:cell.frame];
        cellView.isAlbumStyle=YES;
		((CustomCell *)cell).cellView = cellView;
		[cellView release];
    }
	[((CustomCell *)cell) setDataModel:[lists objectAtIndex:indexPath.row]];
						
    return cell;
    
}

- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	CommodityPhotoDetailVC* vc =
    [[CommodityPhotoDetailVC alloc] initWithCommdityArray:lists currentItemIndex:indexPath.row displayType:CommodityPhotoDetailTypeBoth];

	vc.from = CommodityPhotoSourceFromUserAlbum;
	[self.navigationController pushViewController:vc animated:YES];
	[vc release];
}


#pragma mark - http client delegates

- (void)requestSucceeded:(HttpRequest *)request
{
	[self hideLoading];
    [self finishedHttpClientReload];
    [self finishedHttpClientLoadmore];
    
    NSError*error = nil;
    NSDictionary* dict = [SBApiEngine parseHttpData:request.recievedData error:&error];
    if (error) {
        [self requestFailed:request error:error];
        return;
    }

    // reload all datas
    if (request == httpClient) {
        pageIndex = 0;
        picCountTotal = [VSDictV(dict, @"total") intValue];
       
        [lists removeAllObjects];
        [lists addObjectsFromArray:[self commodityFromDict:dict]];
      
    } else if (request == hcLoadMore) {
        [lists addObjectsFromArray:[self commodityFromDict:dict]];
    }
    if (hasTabbar) {
        picCountTotal=[lists count]+[[dict objectForKey:@"hasmore"] intValue];
        offset=[[dict objectForKey:@"offset"] intValue];
        feedsPage=[[dict objectForKey:@"page"] intValue];
    }
    [tableView reloadData];
    [self setupFooterRefreshView];
}

- (void)requestFailed:(HttpRequest *)request error:(NSError *)error
{
	[self hideLoading];
    [self finishedHttpClientReload];
    [self finishedHttpClientLoadmore];    
}

- (NSMutableArray*)commodityFromDict:(NSDictionary*)dict
{
    //convert an PhotoItem to CommodityItem
    NSString *keyStr=hasTabbar?@"list":@"pic";
     NSArray* ary = VSDictV(dict, keyStr);
    NSMutableArray* array = [NSMutableArray array];
    for (NSDictionary* dict in ary) {
        
        SBCommodity* commodity =hasTabbar? [[SBCommodity alloc] initWithFeedItem:dict uname:userName uiconPath:userIconURL uicon:userICON imagePrefix:IMG_BASE_URL uid:userID]:[[SBCommodity alloc] initWithAlbumItem:dict uname:userName uiconPath:userIconURL uicon:userICON imagePrefix:IMG_BASE_URL uid:userID];
        [array addObject:commodity];
        [commodity release];
    }
    return array;
    
}

#pragma mark - actions

- (void)onCellViewUserIconClicked:(SBCommodity*)item
{
    if (hasTabbar) {
        NSString* userIDStr = item.uid;
        if (!userIDStr) return;
        HomeViewController* homeVC = [[HomeViewController alloc] initWithUserID:userIDStr];
        [self.navigationController pushViewController:homeVC animated:YES];
        [homeVC release];
    }
    
}


-(void)readyHasTabbar
{
    hasTabbar=YES;
    if (!titleTabView) {titleTabView = [[SBSegmentView alloc] init];};
        NSArray *tabArr=[[NSArray alloc] initWithObjects:@"我的主页",@"好友动态", nil];
        [titleTabView setDatasource:tabArr];
        [titleTabView setCellWidth:76];
        titleTabView.delegate = self;
        self.navigationItem.titleView = titleTabView;
        titleTabView.selectedIndex = 1;
        [tabArr release];

}

- (void)segment:(VSSegmentView*)segment clickedAtIndex:(int)index onCurrentCell:(BOOL)isCurrent{
    

    if (segment == titleTabView && !isCurrent) {
        //		[self reloadDataAtTab:index subTab:-1];
        if (index==0) {
            [self.navigationController popViewControllerAnimated:NO];
        }
    }
}

@end




