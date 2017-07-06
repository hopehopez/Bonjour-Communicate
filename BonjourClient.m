//
//  BonjourClient.m
//  Bonjour-Communicate
//
//  Created by 张树青 on 2017/7/5.
//  Copyright © 2017年 zsq. All rights reserved.
//

#import "BonjourClient.h"
#import "Connection.h"
@interface BonjourClient()<NSNetServiceBrowserDelegate, ConnectionDelegate>
@property (nonatomic, copy) NSString *serverName;
@property (nonatomic, strong) NSNetServiceBrowser *serviceBrowser;
@property (nonatomic, strong) NSNetService *netService;
@property (nonatomic, strong) Connection *connection;
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
    self.serverName = serverName;
    
    [self startSerach];
}
- (void)stop{
    [self.serviceBrowser stop];
    self.serviceBrowser.delegate = nil;
    self.serviceBrowser = nil;
    
    [self.connection close];
    self.connection.delegate = nil;
    self.connection = nil;
}
- (void)sendMessage:(NSString *)message{
    if (self.connection) {
        [self.connection sendNetworkPacket:message];
    }
}

#pragma mark - ServiceBrowser
- (void)startSerach{
    if (!self.serviceBrowser) {
        self.serviceBrowser = [[NSNetServiceBrowser alloc] init];
        self.serviceBrowser.delegate = self;
    }
    
    [self.serviceBrowser searchForServicesOfType:@"_chatty._tcp." inDomain:@""];

}
//netServiceBrowser 代理
- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)browser{
    NSLog(@"开始查找Bonjour服务: %@", self.serverName);
}

- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)browser{
    NSLog(@"停止查找Bonjour服务");
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didNotSearch:(NSDictionary<NSString *, NSNumber *> *)errorDict{
    NSLog(@"开启查找Bonjour服务失败: %@", errorDict);
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didFindService:(NSNetService *)service moreComing:(BOOL)moreComing{
    if ([service.name isEqualToString:self.serverName]) {
        NSLog(@"发现Bonjour服务: %@", service.name);
        self.netService = service;
    }
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didRemoveService:(NSNetService *)service moreComing:(BOOL)moreComing{
    if ([service.name isEqualToString:self.serverName]) {
        NSLog(@"Bonjour服务取消发布: %@", service.name);
    }
}

#pragma mark - Connection

- (void)createConnection:(NSNetService *)netService{
    if (self.connection) {
        [self.connection close];
        self.connection = nil;
    }
    
    self.connection = [[Connection alloc] initWithNetService:netService];
    self.connection.delegate = self;
    
    [self.connection connect];
}
//Connection 代理
- (void)connectionAttemptFailed:(Connection *)connection{
    
    NSLog(@"connection连接失败");
}
- (void)connectionTerminated:(Connection *)connection{
    NSLog(@"connection连接中断");
}
- (void)receivedNetworkPacket:(NSString *)message viaConnection:(Connection *)connection{
    NSLog(@"收到消息: %@", message);
}



@end
