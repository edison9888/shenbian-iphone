//
//  OAuthEngine.m
//  OAuthOniPhone
//
//  Created by xu xhan on 5/20/10.
//  Copyright 2010 xu han. All rights reserved.
//

#import "OAuthEngine.h"

@interface OAuthEngine(Private)
- (void) requestURL: (NSURL *) url token: (OAToken *) token onSuccess: (SEL) success onFail: (SEL) fail;
@end


@implementation OAuthEngine


@synthesize accessToken = _accessToken;
@synthesize requestToken = _requestToken;
@synthesize consumer = _consumer;
@synthesize delegate = _delegate;
@synthesize authorizeURL = _authorizeURL;
@synthesize accessTokenURL = _accessTokenURL;
@synthesize requestTokenURL = _requestTokenURL;
@synthesize consumerKey = _consumerKey;
@synthesize consumerSecret = _consumerSecret;


#pragma mark NSObject

- (void)dealloc {
	[_accessToken release], _accessToken = nil;
	[_requestToken release], _requestToken = nil;
	[_consumer release], _consumer = nil;
	[_authorizeURL release], _authorizeURL = nil;
	[_accessTokenURL release], _accessTokenURL = nil;
	[_requestTokenURL release], _requestTokenURL = nil;
	[_consumerKey release], _consumerKey = nil;
	[_consumerSecret release], _consumerSecret = nil;
	[super dealloc];
}

- (id)initWithConsumerKey:(NSString*)key Secret:(NSString*)secret RequestTokenURL:(NSString*)requestURLstr AuthorizeURL:(NSString*)authorizeURLstr AccessTokenURL:(NSString*)accessURLstr
{
	self = [super init];
	
	self.consumerKey = key;
	self.consumerSecret = secret;
	self.consumer = [[OAConsumer alloc] initWithKey: self.consumerKey secret: self.consumerSecret];
	self.requestTokenURL = [NSURL URLWithString:requestURLstr];
	self.authorizeURL = [NSURL URLWithString:authorizeURLstr];
	self.accessTokenURL = [NSURL URLWithString:accessURLstr];
	
	return self;
}

#pragma mark Public Methods

- (BOOL)isAuthorized
{
	return self.accessToken != NULL ;
}

- (void) requestAccessToken
{
	[self requestURL: self.accessTokenURL token: _requestToken onSuccess: @selector(setAccessToken:withData:) onFail: @selector(outhTicketFailed:data:)];
}

- (void) requestAccessTokenWithVerifier:(NSString*)ver
{
	OAMutableURLRequest	*request = [[[OAMutableURLRequest alloc] initWithURL:self.accessTokenURL
																	consumer: self.consumer 
																	   token:_requestToken realm:nil 
														   signatureProvider: nil] autorelease];
    request.verifier = ver;
    [request setHTTPMethod: @"POST"];
    OADataFetcher *fetcher = [[[OADataFetcher alloc] init] autorelease];	
    [fetcher fetchDataWithRequest:request 
						 delegate:self 
				didFinishSelector:@selector(setAccessToken:withData:)
				  didFailSelector:@selector(outhTicketFailed:data:)];	
}

- (void) requestRequestToken
{
	[self requestURL: self.requestTokenURL token: nil onSuccess: @selector(setRequestToken:withData:) onFail: @selector(outhTicketFailed:data:)];
}

- (void) requestAuthorizeAction
{

}

- (NSURLRequest*)authorizeURLRequest
{
	if (!_requestToken.key && _requestToken.secret) return nil;	// we need a valid request token to generate the URL
	
	OAMutableURLRequest	*request = [[[OAMutableURLRequest alloc] initWithURL: self.authorizeURL consumer: nil token: _requestToken realm: nil signatureProvider: nil] autorelease];	
	
	[request setParameters: [NSArray arrayWithObject: [[[OARequestParameter alloc] initWithName: @"oauth_token" value: _requestToken.key] autorelease]]];	
	
	return request;	
}

#pragma mark Response From Request

- (void) outhTicketFailed: (OAServiceTicket *) ticket data: (NSData *) data {
//	NSLog(@"failed %@",data);	
	if ([_delegate respondsToSelector:@selector(OAuthEngineFailed:)]) {
		[_delegate OAuthEngineFailed:data];
	}

}

- (void) setRequestToken: (OAServiceTicket *) ticket withData: (NSData *) data {

	if (!ticket.didSucceed || !data) return;
	
	NSString *dataString = [[[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding] autorelease];
	if (!dataString) return;
	
	[_requestToken release];
	_requestToken = [[OAToken alloc] initWithHTTPResponseBody:dataString];

	if([_delegate respondsToSelector:@selector(OAuthEngineRequestTokenSuccess)])
		[_delegate OAuthEngineRequestTokenSuccess];
}

- (void) setAccessToken: (OAServiceTicket *) ticket withData: (NSData *) data {
	NSLog(@"access token: %@",[[[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding] autorelease]);
	
	if (!ticket.didSucceed || !data) return;
	
	NSString *dataString = [[[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding] autorelease];
	if (!dataString) return;
	
	
	[_accessToken release];
	_accessToken = [[OAToken alloc] initWithHTTPResponseBody:dataString];
	
	if([_delegate respondsToSelector:@selector(OAuthEngineAccessTokenSuccess)])
		[_delegate OAuthEngineAccessTokenSuccess];
}
		 
#pragma mark Private Methods

- (void) requestURL: (NSURL *) url token: (OAToken *) token onSuccess: (SEL) success onFail: (SEL) fail {
    OAMutableURLRequest	*request = [[[OAMutableURLRequest alloc] initWithURL: url consumer: self.consumer token:token realm:nil signatureProvider: nil] autorelease];
	if (!request) return;
	
    [request setHTTPMethod: @"POST"];
	
    OADataFetcher *fetcher = [[[OADataFetcher alloc] init] autorelease];	
    [fetcher fetchDataWithRequest: request delegate: self didFinishSelector: success didFailSelector: fail];
}



-(void)updateStatus
{

//	NSString* message = [@"status=中文测试 居然可以了悲剧啊！" URLEncodedString];
//	NSString* message = [@"status=中文测试 居然可以了悲剧啊！" URLEncodedString];
//	NSString* message = @"status=Test Again 2";
	NSString* msg = @"中文测试!*'();:@&=+$,/?%#[] ABCDE!";
	NSString* message = [NSString stringWithFormat:@"status=%@",[msg URLEncodedString]];
	
	NSURL *url = [NSURL URLWithString:@"http://api.t.sina.com.cn/statuses/update.xml"];
	OAMutableURLRequest	*request = [[[OAMutableURLRequest alloc] initWithURL: url consumer: self.consumer token:self.accessToken
																	   realm:nil signatureProvider: nil] autorelease];	
	[request setHTTPMethod:@"POST"];
	
	[request setHTTPBody:[message dataUsingEncoding:NSUTF8StringEncoding]];

//	[request setValue:@"text/xml" forHTTPHeaderField:@"Content-Type"];
//	request.isPureBody = YES;
	
//	[request setOAuthParameterName:@"status" withValue:@"TestUpdateFromOAuth"];
	OADataFetcher *fetcher = [[[OADataFetcher alloc] init] autorelease];	
	[fetcher fetchDataWithRequest: request delegate: self didFinishSelector:@selector(statusSuccess:withData:)
				  didFailSelector: @selector(outhTicketFailed:data:)];

	
	/*
	NSURL *url = [NSURL URLWithString:@"http://api.t.sina.com.cn/statuses/public_timeline.xml"];
	OAMutableURLRequest	*request = [[[OAMutableURLRequest alloc] initWithURL: url consumer: self.consumer token:self.accessToken
																	   realm:nil signatureProvider: nil] autorelease];	
	[request setHTTPMethod:@"GET"];
	OADataFetcher *fetcher = [[[OADataFetcher alloc] init] autorelease];	
	[fetcher fetchDataWithRequest: request delegate: self didFinishSelector:@selector(statusSuccess:withData:)
				  didFailSelector: @selector(outhTicketFailed:data:)];
	 */
}

- (void) statusSuccess: (OAServiceTicket *) ticket withData: (NSData *) data {
	NSString* str = [[[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding] autorelease];
	NSLog(@"success get update :\n%@",str);
}

@end










