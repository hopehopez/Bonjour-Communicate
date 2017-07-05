//
//  BonjourClient.h
//  Bonjour-Communicate
//
//  Created by 张树青 on 2017/7/5.
//  Copyright © 2017年 zsq. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BonjourClient : NSObject

+ (instancetype)shareInsatance;
- (void)strtWithServerName:(NSString *)serverName;
- (void)stop;
- (void)sendMessage:(NSString *)message;

@end
