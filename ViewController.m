//
//  ViewController.m
//  Bonjour-Communicate
//
//  Created by 张树青 on 2017/7/4.
//  Copyright © 2017年 zsq. All rights reserved.
//

#import "ViewController.h"
#import "BonjourServer.h"
@interface ViewController()
@property (assign) IBOutlet NSTextField *textField;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}
- (IBAction)sendMessage:(id)sender {
    [[BonjourServer shareInsatance] sendMessage:@"nihao"];
}

- (IBAction)startService:(id)sender {
    [[BonjourServer shareInsatance] startServerWithName:@"service_123"];
}
- (IBAction)stopService:(id)sender {
    [[BonjourServer shareInsatance] stopServer];
}

@end
