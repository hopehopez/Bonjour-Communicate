//
//  BonjourServer.h
//  Bonjour-Communicate
//
//  Created by 张树青 on 2017/7/4.
//  Copyright © 2017年 zsq. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Connection;
@class BonjourServer;
@protocol BonjourServerDelegate <NSObject>

// 服务器被终止调用
- (void)serverFailed:(BonjourServer *)server reason:(NSString *)reason;

// 有新的用户连接的时候调用
-(void)handleNewClient:(Connection *)Client;
@end


@interface BonjourServer : NSObject

@property (nonatomic, weak) id<BonjourServerDelegate> delegate;

+ (instancetype)shareInsatance;
- (BOOL)startServerWithName:(NSString *)name;
- (void)stopServer;

//向所有学生发送消息
- (void)sendMessage:(NSString *)message;
//根据指定手机号发送消息
- (void)sendMessage:(NSString *)message toMobile:(NSString *)mobileNumber;
- (NSTimeInterval)getLastTime;

@end
