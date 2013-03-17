//
//  DatasourceDiscovery.m
//  shenbian
//
//  Created by xhan on 4/11/11.
//  Copyright 2011 百度. All rights reserved.
//

#import "DatasourceDiscovery.h"
#import "SBCommodityList.h"
#import "JSON.h"
#import "SBApiEngine.h"

#import "LocationService.h"
#import "CacheCenter.h"
#import "SBLocation.h"


@implementation DatasourceDiscovery
@synthesize tabs, categories, lists, cityID;
@synthesize currentMainTab, currentSubTab;
@synthesize currentCommodityIndex;
@synthesize httpClientGlobal, httpClientTab;
@synthesize hasMore = _hasMore;


- (void)addDelegate:(id)ob
{
	if (!delegates) {
		delegates = [[NSMutableArray alloc] init];
	}
	[delegates addObject:[NSValue valueWithNonretainedObject:ob]];
}

- (void)removeDelegate:(id)obj
{
	NSMutableArray* array  =[[NSMutableArray alloc] init];
	
	for (int i = 0; i< [delegates count]; i++) {
		id theObj = [[delegates objectAtIndex:i] nonretainedObjectValue];
		if (theObj != obj) {
			[array addObject:[NSValue valueWithNonretainedObject:theObj]];
		}
	}
	
	[delegates release];
	delegates = array;
	
}

- (void)dealloc {
	[self resetData];
	[super dealloc];
}

- (void)resetData
{
    CancelRequest(httpClientTab);
	CancelRequest(httpClientGlobal);
    
    VSSafeRelease(categories);
	VSSafeRelease(tabs);
	VSSafeRelease(lists);
	
    VSSafeRelease(cityID);
    
	currentList = nil;
	currentMainTab = 0;
    currentSubTab  = 0;
}

- (NSString*)getCommomURLprefix
{
    SBLocation* location = [[LocationService sharedInstance] currentLocation];
    NSString* xPos = SETNIL(location.x, @"");
    NSString* yPos = SETNIL(location.y, @"");
//    return [NSString stringWithFormat:@"%@%@?city_id=%d&x=%@&y=%@",
//            ROOT_URL, @"/getfind", CurrentCityId, xPos, yPos];
    return [NSString stringWithFormat:@"%@%@?city_id=%d&x=%@&y=%@",
            ROOT_URL, @"/discover", CurrentCityId, xPos, yPos];

}

- (void)setCurrentTabIndex:(int)index category:(int)category
{
    currentMainTab = index;
    currentSubTab  = category;
}

- (void)setCurrentMainTab:(MainTab)tab
{
    currentMainTab = tab;
}

- (SBCommodityList*)modelAtTab:(int)tab subTab:(int)subtab
{
    // Edited by MagicYang for 2.0.3 new API update
    int indexOfList;
    if ([categories count] > 0) {
        int mainIndex = [self mappingIndexWithMainTab:tab];
        if (mainIndex == 0) {
            indexOfList = subtab;
        } else {
            // "附近","最新"的SBCommodityList在"热门"下的子类后面的偏移量为 [categories count] - 1 + tab
            indexOfList = mainIndex == 0 ? subtab : [categories count] - 1 + tab;
        }
    } else {
        indexOfList = [self mappingIndexWithMainTab:tab];
    }
    
    return [lists objectAtIndex:indexOfList];
    // Edited End
}

- (SBCommodityList*)currentList{
    return [self modelAtTab:currentMainTab subTab:currentSubTab];
}

- (BOOL)parseMoreHttpResponse:(NSData*)data atTab:(int)tab atPage:(int)page
{
    NSError* error = nil;
    NSDictionary* dict = [SBApiEngine parseHttpData:data error:&error];
    if (error) {
        return NO;
    }

    SBCommodityList* curList = [self modelAtTab:requestTab subTab:requestSubTab];
    curList.currentPage = page;
    curList.countTotal = [[dict objectForKey:@"list_total"] intValue];
    
    //set commodities
    NSString* imagePrefix = [dict objectForKey:@"pic_path"];
    [CacheCenter sharedInstance].imagePath = imagePrefix;
    NSArray* commodities = [dict objectForKey:@"commodity"];
    for (NSDictionary* dict in commodities) {
        SBCommodity* commodity = [[SBCommodity alloc] initWithDict:dict imagePrefix:imagePrefix];
        [curList addObject:commodity];
        [commodity release];
    }
    curList.hasMore = [[dict objectForKey:@"hasmore"] boolValue];
    
    return YES;
}

- (BOOL)parseHttpResponse:(NSData*)data
{
    NSError* error = nil;
    NSDictionary* dict = [SBApiEngine parseHttpData:data error:&error];
    if (error) {
        return NO;
    }
    // continue get properties from json dict
            
    NSString* imagePrefix = [dict objectForKey:@"pic_path"];
    [CacheCenter sharedInstance].imagePath = imagePrefix;
    
    if ([[dict objectForKey:@"tabs"] isKindOfClass:[NSArray class]]) {
        Release(tabs);
        tabs = [[dict objectForKey:@"tabs"] copy];
    }
    if ([[dict objectForKey:@"sub_tabs"] isKindOfClass:[NSArray class]]) {
        Release(categories);
        categories = [[dict objectForKey:@"sub_tabs"] copy];
    }
    
    //get current tab index 
    currentMainTab = [[dict objectForKey:@"index_tab"] intValue];
    lists = [[NSMutableArray alloc] initWithCapacity:3];
    for (id obj in tabs) {
        [lists addObject:[SBCommodityList list]];
    }
    if ([categories count] > 0) {
        for (int i = 0; i < [categories count] - 1; i++) {
            [lists addObject:[SBCommodityList list]];
        }
    }

    //set commodities
    NSArray* commodities = [dict objectForKey:@"commodity"];
    SBCommodityList* curList = self.currentList;
    
    for (NSDictionary* dict in commodities) {
        SBCommodity* commodity = [[SBCommodity alloc] initWithDict:dict imagePrefix:imagePrefix];
        [curList addObject:commodity];
        [commodity release];
    }
    curList.countTotal = [[dict objectForKey:@"list_total"] intValue];
    curList.hasMore = _hasMore = [[dict objectForKey:@"hasmore"] boolValue];
    
    return YES;

}

///
- (void)loadFirstData
{
	if (!httpClientGlobal) {
		httpClientGlobal = [[HttpRequest alloc] init];
		httpClientGlobal.delegate = self;
	}
	[httpClientGlobal requestGET:[NSString stringWithFormat:@"%@",[self getCommomURLprefix]] useStat:YES];
}

- (void)loadDataRefreshForCurrentList
{
    [self loadDataRefreshAtTab:currentMainTab subTab:currentSubTab];
}

- (void)loadDataRefreshAtTab:(int)tab subTab:(int)subtab
{
    SBCommodityList* list = [self modelAtTab:tab subTab:subtab];
    [list resetData];
    [self loadMoreForTabAt:tab subTab:subtab];
}

- (void)loadMoreForCurrentList
{
    [self loadMoreForTabAt:currentMainTab subTab:currentSubTab];
}

- (void)loadMoreForTabAt:(int)tab subTab:(int)subtab
{
	if (!httpClientTab) {
		httpClientTab = [[HttpRequest alloc] init];
		httpClientTab.delegate = self;
	}
    
    SBCommodityList* list = [self modelAtTab:tab subTab:subtab];
    
    requestTab = tab;
    requestSubTab = subtab;
    if (![self isLatestTab:tab]) {
        if (list.countTotal == 0 ) {
            //so the tab hasn't have any data yet
            requestPage = 0;
        }else {
            requestPage = list.currentPage + 1;
        }
        
        if (tab == 0 && [categories count] > 0) {
            NSString* subCategoryName = [categories objectAtIndex:subtab];
            [httpClientTab requestGET:[NSString stringWithFormat:@"%@&t=%d&p=%d&subt=%@",[self getCommomURLprefix],requestTab,requestPage,subCategoryName]
                              useStat:YES];
        }else{
            [httpClientTab requestGET:[NSString stringWithFormat:@"%@&t=%d&p=%d",[self getCommomURLprefix],requestTab,requestPage]
                              useStat:YES];
        }
        
    }else{
        // latest tab don't have page properties, by using pl(p_id) and last_time to avoid return results contains same contents
        SBCommodity* commodity = [list lastCommodity];
        
        if (commodity) {
            NSString* createdAt = SETNIL(commodity.createdAt, @"");
            NSString* cid       = SETNIL(commodity.pid, @"");
            [httpClientTab requestGET:[NSString stringWithFormat:@"%@&t=%d&pl=%@&last_time=%@",[self getCommomURLprefix],tab,cid,createdAt]
                              useStat:YES];
        }else{
            //first load
            [httpClientTab requestGET:[NSString stringWithFormat:@"%@&t=%d",
                                       [self getCommomURLprefix],tab]
                              useStat:YES];
        }
    }
}


- (BOOL)isLatestTab:(int)tab
{
    //last one is LatestTab
    if (tab==2) {
        return YES;
    }
    return  NO;
}

- (BOOL)isLatestTabForCurList
{
    return [self isLatestTab:currentMainTab];
}

- (SBCommodity *)currentCommodity
{
    return [currentList objectAtIndex:currentCommodityIndex];
}

- (int)mappingIndexWithMainTab:(MainTab)tab
{
    if ([tabs count] == 3) {
        return tab;
    } else {
        return tab - 1;
    }
}

- (MainTab)mappingMainTabWithIndex:(int)index
{
    if ([tabs count] == 3) {
        return index;
    } else {
        return index + 1;
    }
}


#pragma mark - HttpRequest delegates

- (void)requestSucceeded:(HttpRequest *)request
{
	if (request == httpClientGlobal) {
		BOOL value = [self parseHttpResponse:[request recievedData]];
//		DLog(@"---------------------------------------------------------------- hasmore: %d", self.hasMore);
		Release(httpClientGlobal);
		if (value) {
			[self _invokeDelegateSuccess:YES];
		} else {
			//TODO: add error description
			[self _invokeDelegateFailed:[NSError errorWithDomain:SBApiEngineError code:0 userInfo:nil]];
		}
		return;
	}
	
	if (request == httpClientTab) {
		BOOL value = [self parseMoreHttpResponse:[request recievedData] 
                                           atTab:requestTab
										  atPage:requestPage];
//		DLog(@"+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++");
		Release(httpClientTab);
		if (value) {
			[self _invokeDelegateSuccess:NO];
		} else {
			[self _invokeDelegateFailed:[NSError errorWithDomain:SBApiEngineError code:0 userInfo:nil]];
		}
		return;
	}
}

- (void)requestFailed:(HttpRequest *)request error:(NSError *)error
{
    if (request == httpClientTab) {
        Release(httpClientTab);
    } else if (request == httpClientGlobal){
        Release(httpClientGlobal)
    } else {
        Release(request);
    }
    
	[self _invokeDelegateFailed:[NSError errorWithDomain:SBApiEngineError code:0 userInfo:nil]];	
}

- (void)_invokeDelegateSuccess:(BOOL)isInit
{
	for (NSValue* delegateValue in delegates) {
		id<DatasourceDiscoveryDelegate> delegate = [delegateValue nonretainedObjectValue];
		if ([delegate respondsToSelector:@selector(datasource:successLoaded:)]) {
			[delegate datasource:self successLoaded:isInit];
		}
	}
}

- (void)_invokeDelegateFailed:(NSError*)reason
{
	for (NSValue* delegateValue in delegates) {
		id<DatasourceDiscoveryDelegate> delegate = [delegateValue nonretainedObjectValue];
		if ([delegate respondsToSelector:@selector(datasource:failedWithError:)]) {
			[delegate datasource:self failedWithError:reason];
		}
	}	
}


@end



