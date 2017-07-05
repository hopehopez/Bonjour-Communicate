//
//  BonjourClient.m
//  Bonjour-Communicate
//
//  Created by 张树青 on 2017/7/5.
//  Copyright © 2017年 zsq. All rights reserved.
//

#import "BonjourClient.h"
#import "Connection.h"
@interface BonjourClient()<NSNetServiceBrowserDelegate>
@property (nonatomic, copy) NSString *serverName;
@property (nonatomic, strong) NSNetServiceBrowser *serviceBrowser;
@end

@implementation BonjourClient

+ (instancetype)shareInsatance{
    static BonjourClient *_client;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _client = [[BonjourClient alloc] init];
    });
    return _client;
}

- (void)strtWithServerName:(NSString *)serverName{
    
    
}
- (void)startSerach{
    
}

@end
