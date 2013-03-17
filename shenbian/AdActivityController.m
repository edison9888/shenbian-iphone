//
//  AdActivityController.m
//  shenbian
//
//  Created by Leeyan on 11-8-1.
//  Copyright 2011 ÁôæÂ∫¶. All rights reserved.
//

#import "AdActivityController.h"
#import "TKAlertCenter.h"
#import "LoginController.h"
#import "SBApiEngine.h"
#import "Utility.h"
#import "HttpRequest+Statistic.h"

@implementation AdActivityController

@synthesize activityId;

- (id)initWithFrame:(CGRect)_frame andActivityId:(NSString *)_activityId andDelegate:(id)_delegate {
	if ((self = [super initWithFrame:_frame andDelegate:_delegate])) {
		self.activityId = _activityId;
	}
	return self;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
	[super webViewDidFinishLoad:webView];
	//	判断是否已报过名
	enrollStatusRequest = [[HttpRequest alloc] initWithDelegate:self andExtraData:nil];
	[enrollStatusRequest requestGET:[NSString stringWithFormat:@"%@/getActivityStatus?actid=%@", ROOT_URL, activityId] useStat:YES];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
	[super webView:webView didFailLoadWithError:error];
//	[self hideLoading];
}

- (void)enroll:(NSDictionary *)params {
	if (isInEnrolling) {
		return;
	}
	//	check login
	BOOL isLogin = [[LoginController sharedInstance] isLogin];
	if (!isLogin) {
		//	未登录
		[[LoginController sharedInstance] showLoginView];
	} else {
		//	已登录
		//	判断是否已报过名
		enrollRequest = [[HttpRequest alloc] initWithDelegate:self andExtraData:nil];
		NSDictionary *params = [NSDictionary dictionaryWithObjects:
								[NSArray arrayWithObjects:activityId, nil] 
														   forKeys:
								[NSArray arrayWithObjects:@"actid", nil]
								];
		isInEnrolling = YES;
		[enrollRequest requestPOST:[NSString stringWithFormat:@"%@/submitActivity", ROOT_URL] parameters:params];
	}
}

#pragma mark -
#pragma mark request delegate

- (void)requestFailed:(HttpRequest*)req error:(NSError*)error {
	if (req == enrollRequest) {
        Release(enrollRequest);
		isInEnrolling = NO;
	} else {
        Release(enrollStatusRequest);
    }
}

- (void)requestSucceeded:(HttpRequest*)req {
	DLog(@"response: %@", [[[NSString alloc] initWithData:req.recievedData
												 encoding:NSStringEncodingConversionAllowLossy] autorelease]);
//	NSError *error = nil;
//	NSDictionary *dict = [SBApiEngine parseHttpData:req.recievedData error:&error];
	NSDictionary *dict = [Utility parseData:req.recievedData];
	NSInteger error = [[dict objectForKey:@"errno"] intValue];
	if (req == enrollStatusRequest) {
		if (error) {
			if (21003 == error) {
				[self.webView stringByEvaluatingJavaScriptFromString:AD_ACTIVITY_SHOW_ENROLL_BUTTON];
			} else if (21001 == error) {
				[self.webView stringByEvaluatingJavaScriptFromString:AD_ACTIVITY_SHOW_ENROLL_BUTTON];
			}

			[self requestFailed:req error:[NSError errorWithDomain:@"enroll status" code:error userInfo:dict]];
			return;
		}
		
		NSInteger status = [[dict objectForKey:@"status"] intValue];
		
		//		status = 1;		//	test code
		switch (status) {
			case 1:
				//已报名
//				TKAlert(@"已经报过名");
				[self.webView stringByEvaluatingJavaScriptFromString:AD_ACTIVITY_SHOW_ALREADY_ENROLLED_BUTTON];
				break;
			case 0:
				//未报名
				[self.webView stringByEvaluatingJavaScriptFromString:AD_ACTIVITY_SHOW_ENROLL_BUTTON];
				break;
			default:
				break;
		}
		
		Release(enrollStatusRequest);
	} else if (req == enrollRequest) {
		//		error = 0;	//	test code
		switch (error) {
			case 0:
				//	报名成功
				[self.webView stringByEvaluatingJavaScriptFromString:AD_ACTIVITY_SHOW_ALREADY_ENROLLED_BUTTON];
				break;
//			case 21001:
//				TKAlert(@"系统错误");
//				break;
//			case 21003:
//				TKAlert(@"用户未登录");
//				break;
//			case 21004:
//				TKAlert(@"用户未激活");
//				break;
//			case 21013:
//				TKAlert(@"徽章可使用数为0");
//				break;
			case 21012:
				//	报名成功
//				TKAlert(@"您已报名");
				[self.webView stringByEvaluatingJavaScriptFromString:AD_ACTIVITY_SHOW_ALREADY_ENROLLED_BUTTON];
				break;
			default:
				break;
		}
		isInEnrolling = NO;
		Release(enrollRequest);
	}
}

- (void)dealloc {
	CancelRequest(enrollRequest);
	CancelRequest(enrollStatusRequest);
	[super dealloc];
}

@end
