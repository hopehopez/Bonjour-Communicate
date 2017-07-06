//
//  BonjourServer.m
//  Bonjour-Communicate
//
//  Created by 张树青 on 2017/7/4.
//  Copyright © 2017年 zsq. All rights reserved.
//

#import "BonjourServer.h"
#include <netinet/in.h>
#include <unistd.h>
#import "Connection.h"

@interface BonjourServer ()<NSNetServiceDelegate, ConnectionDelegate>{
    CFSocketRef _listeningSocket;
}

//bonjour服务
@property (nonatomic, strong) NSNetService *netService;
//bonjour服务名
@property (nonatomic, copy) NSString *serviceName;
//bonjour端口
@property (nonatomic, assign) uint16_t port;
@property (nonatomic, assign) NSTimeInterval lastTime;
//存放所有的连接
@property (nonatomic, strong) NSMutableSet *clients;

@end

@implementation BonjourServer

+ (instancetype)shareInsatance{
    static BonjourServer *_service;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _service = [[BonjourServer alloc] init];
        _service.clients = [NSMutableSet set];
    });
    return _service;
}

- (BOOL)startServerWithName:(NSString *)name{
    
    self.serviceName = name;
    
    //是否创建socket服务器成功;
    BOOL succeed =[self createSocket];
    if (!succeed) {
        return NO;
    }
    succeed = [self publishService];
    if ( !succeed ) {
        [self terminateSocket];
        return NO;
    }
    
    return YES;
}
- (void)stopServer{
    [self terminateSocket];
    [self unpublishService];
}

#pragma mark - 创建Scoket
-(BOOL)createSocket {
    //0. (可选)创建CFSocketContext->用来关联Socket上下文信息
    /*
     struct CFSocketContext
     {
     CFIndex version; 版本号，必须为0
     void *info; 一个指向任意程序定义数据的指针，可以在CFScocket对象刚创建的时候与之关联，被传递给所有在上下文中回调；
     CFAllocatorRetainCallBack retain; info指针中的retain回调，可以为NULL
     CFAllocatorReleaseCallBack release; info指针中的release的回调，可以为NULL
     CFAllocatorCopyDescriptionCallBack copyDescription; info指针中的回调描述，可以为NULL
     };
     typedef struct CFSocketContext CFSocketContext;
     */
    
    //这里把self作为数据指针传过去，这样在回调的时候就能拿到当前的self
    CFSocketContext context =  {
        0,
        (__bridge void *)(self),
        NULL,
        NULL,
        NULL,
    };
    
    //1. 创建socket listen
    _listeningSocket = CFSocketCreate(
                                      kCFAllocatorDefault, //内存分配类型，一般为默认的Allocator->kCFAllocatorDefault
                                      PF_INET,//协议族,一般为Ipv4:PF_INET,(Ipv6,PF_INET6)
                                      SOCK_STREAM,//套接字类型，TCP用流式—>SOCK_STREAM，UDP用报文式->SOCK_DGRAM
                                      IPPROTO_TCP,//套接字协议，如果之前用的是流式套接字类型：PPROTO_TCP，如果是报文式：IPPROTO_UDP
                                      kCFSocketAcceptCallBack,//回调事件触发类型
                                      SocketAcceptCallBack,//触发时候调用的方法
                                      &context//用户定义的数据指针，用于对CFSocket对象的额外定义或者申明，可以为NULL
                                      );
    
    if (_listeningSocket == NULL) {
        return NO;
    }
    
    //2.设置Socket关联的选项
    int existingValue = 1;
    CFSocketNativeHandle socketNativeHandle = CFSocketGetNative(_listeningSocket);
    setsockopt(
               socketNativeHandle,//需要设置选项的套接字
               SOL_SOCKET,//选项所在的协议层 SOL_SOCKET:通用套接字选项.（常用）
               SO_REUSEADDR,//需要访问的选项名 SO_REUSERADDR- 允许重用本地地址和端口- int
               (void *)&existingValue,//设置套接字选项
               sizeof(existingValue)//选项的长度
               );
    
    //3.创建Socket需要连接的地址
    //定义sockaddr_in类型的变量，该变量将作为CFSocket的地址
    struct sockaddr_in socketAddress;
    memset(&socketAddress, 0, sizeof(socketAddress));
    socketAddress.sin_len = sizeof(socketAddress);
    socketAddress.sin_family = AF_INET;   //IPv4 IPv6
    //设置服务器监听端口
    socketAddress.sin_port = 0;   //由内核自动分配
    //设置服务器监听地址
    socketAddress.sin_addr.s_addr = htonl(INADDR_ANY);
    
    //4. 转换地址类型，连接
    NSData * socketAddressData = [NSData dataWithBytes:&socketAddress length:sizeof(socketAddress)];
    //将CFSocket绑定到指定IP地址
    if (CFSocketSetAddress(_listeningSocket,(__bridge CFDataRef)(socketAddressData))!= kCFSocketSuccess) {
        if (_listeningSocket !=NULL) {
            CFRelease(_listeningSocket);
            _listeningSocket = NULL;
        }
        return NO;
    }
    
    //5.找到内核分配给我们的端口号, 用来发布bonjour服务
    NSData * socketAddressActualData =(NSData *)CFBridgingRelease(CFSocketCopyAddress(_listeningSocket));
    //socket实际地址
    struct sockaddr_in socketAddressActual;
    memcpy(&socketAddressActual, [socketAddressActualData bytes], [socketAddressActualData length]);
    self.port = ntohs(socketAddressActual.sin_port);
    NSLog(@"bonjour端口: %d",_port);
    
    //6.加入RunLoop循环监听
    CFRunLoopRef currentRunLoop = CFRunLoopGetCurrent();
    //将_socket包装成CFRunLoopSource
    CFRunLoopSourceRef source = CFSocketCreateRunLoopSource(kCFAllocatorDefault, _listeningSocket, 0);
    //为CFRunLoop对象添加source
    CFRunLoopAddSource(currentRunLoop, source, kCFRunLoopCommonModes);
    CFRelease(source);
    //运行当前线程的CFRunLoop
    CFRunLoopRun();
    return YES;
}

//有客户端连接进来的回调函数
static void SocketAcceptCallBack(CFSocketRef s, CFSocketCallBackType type, CFDataRef address, const void *data, void *info){
    
    if ( type != kCFSocketAcceptCallBack ) {
        return;
    }
    //接收socket
    // 回调一个套接字本地句柄指针 //用于存放error
    CFSocketNativeHandle nativeSocketHandle = *(CFSocketNativeHandle *)data;
    
    BonjourServer *server = (__bridge BonjourServer *)info;
    [server handleNewNativeSocket:nativeSocketHandle];
}
//建立对应客户端的本地连接
- (void)handleNewNativeSocket:(CFSocketNativeHandle)nativeSocketHandle
{
    // nativeSocketHandle :可以作为一个请求响应
    //由于是Bonjour服务器 port和ip都是自动产生
    Connection* connection = [[Connection alloc] initWithNativeSocketHandle:nativeSocketHandle];
    
    // 关闭套接字句柄
    if ( connection == nil ) {
        close(nativeSocketHandle);
        return;
    }
    
    connection.delegate = self;
    
    // 连接成功
    BOOL succeed = [connection connect];
    if ( !succeed ) {
        [connection close];
        return;
    }
    
    [self.clients addObject:connection];
    
    // 客户端进来的回调
    if (self.delegate && [self.delegate respondsToSelector:@selector(handleNewClient:)]) {
        [self.delegate handleNewClient:connection];
    }
    
}
- (void)terminateSocket{
    if ( _listeningSocket != nil ) {
        CFSocketInvalidate(_listeningSocket);
        CFRelease(_listeningSocket);
        _listeningSocket = nil;
    }
}

#pragma mark - Bonjour 服务
//发布服务
- (BOOL)publishService {
    //发布一个本地服务器
    self.netService = [[NSNetService alloc] initWithDomain:@"" type:@"_chatty._tcp." name:self.serviceName port:_port];
    if (self.netService == nil) {
        return NO;
    }
    [self.netService scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    [self.netService setDelegate:self];
    [self.netService publish];
    return YES;
}
- (void)unpublishService
{
    if (self.netService) {
        [self.netService stop];
        [self.netService removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
        self.netService = nil;
    }
}

#pragma mark - NetService 代理
- (void)netService:(NSNetService *)sender didNotPublish:(NSDictionary<NSString *,NSNumber *> *)errorDict{
    if ( sender != self.netService ) {
        return;
    }
    
    // 暂停socket服务
    [self terminateSocket];
    
    // 停止Bonjour
    [self unpublishService];
    
    // 服务器发布失败
    if ([self.delegate respondsToSelector:@selector(serverFailed:reason:)]) {
        [self.delegate serverFailed:self reason:[self getFailReason:errorDict[@"errorCode"]]];
    }
    
}

- (void) netServiceDidPublish:(NSNetService *)sender
{
    NSLog(@"%@, 服务发布成功", sender.name);
    
}
- (void) netServiceDidStop:(NSNetService *)sender
{
    NSLog(@"%@, 服务停止", sender.name);
}

//根据错误码获取错误描述
- (NSString *)getFailReason:(NSNumber *)errorNumber{
    NSInteger errorCode = [errorNumber integerValue];
    switch (errorCode) {
        case -72000:
            return @"NSNetServicesUnknownError. An unknown error occured during resolution or publication.";
            break;
        case -72001:
            return @"NSNetServicesCollisionError. An NSNetService with the same domain, type and name was already present when the publication request was made.";
            break;
        case -72002:
            return @"NSNetServicesNotFoundError. The NSNetService was not found when a resolution request was made.";
            break;
        case -72003:
            return @"NSNetServicesActivityInProgress. A publication or resolution request was sent to an NSNetService instance which was already published or a search request was made of an NSNetServiceBrowser instance which was already searching";
            break;
        case -72004:
            return @"NSNetServicesBadArgumentError. An required argument was not provided when initializing the NSNetService instance.";
            break;
        case -72005:
            return @"NSNetServicesCancelledError. The operation being performed by the NSNetService or NSNetServiceBrowser instance was cancelled.";
            break;
        case -72006:
            return @"NSNetServicesInvalidError. An invalid argument was provided when initializing the NSNetService instance or starting a search with an NSNetServiceBrowser instance.";
            break;
        case -72007:
            return @"NSNetServicesTimeoutError. Resolution of an NSNetService instance failed because the timeout was reached.";
            break;
            
        default:
            return @"";
            break;
    }
    return @"";
}

#pragma mark - Connection 代理
- (void)connectionAttemptFailed:(Connection *)connection{
    
    NSLog(@"connection连接失败");
    [self.clients removeObject:connection];
}
- (void)connectionTerminated:(Connection *)connection{
    NSLog(@"connection连接中断");
    [self.clients removeObject:connection];
}
- (void)receivedNetworkPacket:(NSString *)message viaConnection:(Connection *)connection{
    NSLog(@"收到消息: %@", message);
}

#pragma mark - 消息发送
- (void)sendMessage:(NSString *)message{
    [self.clients makeObjectsPerformSelector:@selector(sendNetworkPacket:) withObject:message];
}
- (void)sendMessage:(NSString *)message toMobile:(NSString *)mobileNumber{
    
}

- (NSTimeInterval)getLastTime{
    return  self.lastTime;
}
@end
