//
//  Bridging-Header.h
//  SocSerDemo3(Client)
//
//  Created by JiaCheng on 2018/9/2.
//  Copyright © 2018年 JiaCheng. All rights reserved.
//

//①Build Setting -> Swift Compiler - General -> OC Bridging Header 如此头文件与工程在同一目录，只需写上Bridging-Header.h
//②Search Paths -> User Header Search Paths -> ${SRCROOT}    recursive

#ifndef Bridging_Header_h
#define Bridging_Header_h

#import "GCDAsyncSocket.h"
#import "GCDAsyncUdpSocket.h"
#import "HmTool.h"

#endif /* Bridging_Header_h */
