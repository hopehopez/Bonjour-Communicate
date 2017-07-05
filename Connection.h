//
//  Connection.h
//  Bonjour-Communicate
//
//  Created by 张树青 on 2017/7/4.
//  Copyright © 2017年 zsq. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CFNetwork/CFSocketStream.h>
@class Connection;
@protocol ConnectionDelegate <NSObject>

//收到消息
- (void) receivedNetworkPacket:(NSString *)message
                 viaConnection:(Connection *)connection;

@optional
/**
 *  连接失败 :重连
 */
- (void) connectionAttemptFailed:(Connection*)connection;
/**
 *  连接终止
 */
- (void) connectionTerminated:(Connection*)connection;

@end

@interface Connection : NSObject<NSNetServiceDelegate>

@property (nonatomic ,weak) id<ConnectionDelegate> delegate;

- (instancetype) initWithHostAddress:(NSString *)host andPort:(NSInteger)port;

- (instancetype) initWithNativeSocketHandle:(CFSocketNativeHandle)nativeSocketHandle;
- (instancetype) initWithNetService:(NSNetService *)netService;
- (BOOL) connect;
- (void) close;
- (void) sendNetworkPacket:(NSString *)packet;
@end

