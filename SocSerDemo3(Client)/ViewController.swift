//
//  ViewController.swift
//  SocketServerDemo
//
//  Created by JiaCheng on 2018/8/29.
//  Copyright © 2018年 JiaCheng. All rights reserved.
//

//注意一个点，就是蓝牙串口波特率要让单片机改成9600（蓝牙插在电脑上的话电脑的串口波特率也要9600）
//但是Wi-Fi模块好像是11520就可以，我其它还没试

//现在这个app好想iphone真机调试，在同一wifi下又可以连接了么？？？
//然后我又发现这个网上找的得到自己IP的在真机上调试的话又是不对的，所以我又换了在之前CocoaHTTPServer工程上的。

//关于IP地址还有很多问题需要注意：比如我之前那个app和现在这个app都只能手机开热点让别人连，才能连上它的服务器。而且手机开热点后的IP比如是10.33.93.65，但是连上它的热点的设备是172.20.10.2，172.20.10.15等等。而更令我疑惑的是，手机数据线连上电脑，网络中会有一个iPhone USB，IP地址为172.20.10.2，然后我再电脑连其热点，Wi-Fi有个IP地址172.20.10.3，然后我在这个程序中让newSocket打印出的connectedHost是172.20.10.2而不是3.
//我手机数据线连电脑，iPhone USB的IP还是172.20.10.2，而电脑连的Wi-Fi其IP为192.168.1.3，然而我手机建立服务器，Mac上的网络调试助手client连接10.145.98.70：9050后，程序打印出的newSocket仍然是172.20.10.2。所以此时Wi-Fi不起作用？
/*
还有一点我下面用serverSocket去监听port9050（代表建立了服务器），然后我打印①(serverSocket.localHost?.description)!+":"+String(serverSocket.localPort)结果0.0.0.0:9050 ，打印②String(describing: serverSocket.connectedHost)为nil，③serverSocket.connectedPort为0.
再print(String(describing: newSocket.connectedHost))
print(newSocket.connectedPort)
print(String(describing: newSocket.localHost))
print(newSocket.localPort)
 Optional("172.20.10.2")
 54467
 Optional("10.145.98.70")
 9050
 
print(String(describing: sock.connectedHost))
print(sock.connectedPort)
print(String(describing: sock.localHost))
print(sock.localPort)
 nil
 0
 Optional("0.0.0.0")
 9050
 
 所以在没有接收到任何别的连接时，我好像得不到本机的IP地址，所以我就去网上找了个获得IP地址的方法放在helper里面，于是也就发现了手机开热点后IP地址10.33.93.65，与连接到此热点的设备的IP完全不一样的发现。
 */

import UIKit

//我之前写了个UITextViewDelegate，所以出不来。但其实是UITextFieldDelegate
class ViewController: UIViewController, GCDAsyncSocketDelegate, UITextFieldDelegate {
    
    @IBOutlet weak var sendBtn: UIButton!
    @IBOutlet weak var sendField: UITextField!
    @IBOutlet weak var IPAddressText: UITextField!
    @IBOutlet weak var PortText: UITextField!
    @IBOutlet weak var receivedStr: UITextView!
    @IBOutlet weak var connectingText: UITextView!
    @IBOutlet weak var ConnectedDevicesText: UITextView!
    
    var serverSocket: GCDAsyncSocket!
    var clientSockets = [GCDAsyncSocket]()
    var clientInfos = [String]()
    let serverPort:UInt16 = 9050
    var myIP = ""
    var connectingInfo = "" {
        didSet {
            connectingText.text = connectingInfo
            connectingText.scrollRangeToVisible(NSMakeRange(connectingText.text.lengthOfBytes(using: .utf8), 1))
            //上面这句设置后会是textView有文字产生时自动到最后，但网上一查所还要加下面一句才可以不需要每次都从最上面滑下来，但是我好像不需要也行的么？
            //这句代码设置了 UITextView 中的 layoutManager(NSLayoutManager) 的是否非连续布局属性，默认是 YES，设置为 NO 后 UITextView 就不会再自己重置滑动了。
            //        receivedStr.layoutManager.allowsNonContiguousLayout = false
            //        connectingText.layoutManager.allowsNonContiguousLayout = false
        }
    }
    var receivedInfo = "" {
        didSet {
            receivedStr.text = receivedInfo
            receivedStr.scrollRangeToVisible(NSMakeRange(receivedStr.text.lengthOfBytes(using: .utf8), 1))
        }
    }
    var connectedDevicesInfo = "" {
        didSet {
            ConnectedDevicesText.text = connectedDevicesInfo
            ConnectedDevicesText.scrollRangeToVisible(NSMakeRange(ConnectedDevicesText.text.lengthOfBytes(using: .utf8), 1))
        }
    }

    var startBtn: UIBarButtonItem!
    var endBtn: UIBarButtonItem!
    
    //MARK: - btnMethods
    @IBAction func sendMessage(_ sender: UIButton) {
        sendField.resignFirstResponder()
        
        if var sendStr = sendField.text {
            sendStr += "\n"
            if clientSockets.count > 0 {
                for clientSocket in clientSockets {
                    clientSocket.write(sendStr.data(using: .utf8)!, withTimeout: -1, tag: 0)
                }
            } else {
                showAlertWithTitle("No client", andMessage: "Please check your configure。")
            }
        }
    }
    
    @objc func startServer() {
        serverSocket = GCDAsyncSocket()
        
        serverSocket.delegate = self
        serverSocket.delegateQueue = DispatchQueue.main
        
        do {
            try serverSocket.accept(onPort: serverPort)
            //            showAlertWithTitle("Server start successful!", andMessage: nil)
            print("[" + myIP + ":" + String(serverPort) + "] 服务器已打开")
            connectingInfo += "[" + myIP + ":" + String(serverPort) + "] 服务器已打开\n"
            navigationItem.rightBarButtonItem = endBtn
            connectedDevicesInfo = "已连接的设备：\n"
            
            //            print(GCDAsyncUdpSocket.host(fromAddress: serverSocket.localAddress!)) 不知道什么用
        } catch {
            showAlertWithTitle("Error", andMessage: error.localizedDescription)
        }
    }
    
    @objc func endServer() {
        //注意此处上一句把监听的serverSocket断开后，其它之后的socket都连接不上了。但是别的已经连接的socket都还是连接着的，所以我把它们也都循环一遍断开。
        for clientSocket in clientSockets {
            clientSocket.disconnect()
        }
        serverSocket.disconnect()
        //我打算用下面这句使它为nil，看能否把别的一连上的也一并断开，答案是好像不可以。
        //        serverSocket = nil
        
        //本来直接在这里写这句话即可，但是我后面disconnect的代理中要数组中有才可以，所以我在代理中去除。
        //        clientSockets.removeAll()
        navigationItem.rightBarButtonItem = startBtn
        self.endBtn.tintColor = UIColor.red
    }
    
    //MARK: - View SetUp
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.title = "TCP Server"
        
        myIP = HmTool.getIPAddress(true)
        IPAddressText.text = myIP
        PortText.text = String(serverPort)
        print("内网: \(myIP)")
        print("外网: \(String(describing: getIpinfo()))")
        
        connectedDevicesInfo = "未打开服务器\n"
        
        sendField.delegate = self
        
        //注，下面四句话enable为false之后背景变黑，且selected为true也不能选了。要么用textview，且下面两个属性在storyboard中可以找到。
//        IPAddressText.isEnabled = false
//        IPAddressText.isSelected = true
//        PortText.isEnabled = false
//        PortText.isSelected = true
        
        startBtn = UIBarButtonItem(title: "Start", style: .plain, target: self, action: #selector(startServer))
        endBtn = UIBarButtonItem(title: "Dealloc", style: .plain, target: self, action: #selector(endServer))
        endBtn.tintColor = UIColor.red
        navigationItem.rightBarButtonItem = startBtn
    }
    
    //MARK: - GCDAsyncSocketDelegate
//    有客户端的socket连接到服务器
    func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        // 1 保存socket： 判断socket是否存在，不存在就添加
        if clientSockets.contains(newSocket) {
            print("已经存在")
            return
        } else {
            clientSockets.append(newSocket)
            let socketInfo = newSocket.connectedHost! + ":" + String(newSocket.connectedPort)
            clientInfos.append(socketInfo)
            
            print("[" + socketInfo+"] 客服端已连接")
            connectingInfo += "[" + socketInfo+"] 客服端已连接\n"
            connectedDevicesInfo += socketInfo + "\n"
        }
        
        // 2 返回消息
        //之前我模拟w服务器返回http请求的时候一直不对，原因竟然是这里我连接上了之后会发送"Login successful\n"，所以出现了错误
        //这是我在火狐服务器连接的时候看到的，火狐很不错啊，能看到发送过去的源码（如果请求的响应它解析不了的话），safari和chrom不行
//        let serviceStr =  "Login successful\n"
//        newSocket.write(serviceStr.data(using: .utf8)!, withTimeout: -1, tag: 0)
        
        // 3.监听客户端有没有数据上传,下面这句话一定要写的，因为不写的话下一次读取数据就读取不到了
        //timeout -1 代表不超时
        //tag 标识作用，现在不用，就写0
        newSocket.readData(withTimeout: -1, tag: 0)
    }
    
//    读取客户端请求的数据
    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        // 1 获取客户的发来的数据 ，把 NSData 转 NSString
        let readClientDataSStr = NSString(data: data, encoding: String.Encoding.utf8.rawValue)
//        let readClientDataStr = readClientDataSStr! as String
        let readClientDataStr = readClientDataSStr!.description
        
        //或者跟我在蓝牙里面的一样，打印出ascii码？？？
        //        let updateData = NSData(data: data)
        //        let updateStr = updateData.description
        
        // 2 主界面UI显示数据
//        DispatchQueue.main.async {
//            var showStr:String = self.receivedStr.text
//            showStr += readClientDataStr + "\n"
//            self.receivedStr.text = showStr
//        }
        receivedInfo += readClientDataStr + "\n"
        
        if receivedInfo.prefix(3) == "GET" {
            //Content-Length现在还不确定到底怎么算，我用pages算了一下若一个算一个字节的话只有412而不是523，但是我不论填写412还是523，浏览器都能显示完全，但是显示完了浏览器还在转就是在加载，感觉没加载完的样子？？
            let response = """
                HTTP/1.1 200 OK
                Date: Mon, 10 Jun 2019 11:28:30 GMT
                Accept-Ranges: bytes
                Content-Length: 523
                Proxy-Connection: keep-alive

                <!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
                <html lang="en">
                    <head>
                        <meta charset="UTF-8">
                        <meta http-equiv=\"content-type\" content=\"text/html\">
                    </head>
                    
                    <body>
                        <form action="upload.html" method="post" enctype="multipart/form-data" accept-charset="utf-8">
                            <input type="file" name="upload1"><br/>
                            <input type="file" name="upload2"><br/>
                            <input type="submit" value="Submit">
                        </form>
                        
                    </body>
                </html>
            """
            
            sock.write(response.data(using: .utf8)!, withTimeout: -1, tag: 0)

        }
        
        // 3.处理请求，返回数据给客户端 ok（有时候不能返回，比如别人也会在收到你发送的消息后回馈，这样就没完没了了；或者说接收到特定符号不回复这可以解决）
        //let serviceStr =  "OK\n"
        //sock.write(serviceStr.data(using: .utf8)!, withTimeout: -1, tag: 0)
        
        // 4每次读完数据后，都要调用一次监听数据的方法;下面这句话一定要写的，因为不写的话下一次读取数据就读取不到了
        sock.readData(withTimeout: -1, tag: 0)
    }
    
    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        if sock == serverSocket {
            //我觉得那个不是真正的关闭，因为它dis后原本连上的还是连上的。
            print("[" + myIP + ":" + String(serverPort) + "] 服务器已关闭")
            connectingInfo += "[" + myIP + ":" + String(serverPort) + "] 服务器已关闭\n"
            connectedDevicesInfo = "未打开服务器\n"
        } else if clientSockets.contains(sock) {
            let socketIndex = clientSockets.firstIndex(of: sock)!
            print("[" + clientInfos[socketIndex]+"] 客服端已断开")
            connectingInfo += "[" + clientInfos[socketIndex]+"] 客服端已断开\n"
            clientSockets.remove(at: socketIndex)
            clientInfos.remove(at: socketIndex)
            
            connectedDevicesInfo = "已连接的设备:\n"
            for clientInfo in clientInfos {
                connectedDevicesInfo += clientInfo + "\n"
            }
        }
    }

    //MARK: - ExtralTask
    func showAlertWithTitle(_ title:String?, andMessage message:String?) {
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(ac, animated: true)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == sendField {
            sendMessage(sendBtn)
        }
        
        return true
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    //注意⚠️：2019/06/09
    //① iPhone4G：用4G网络的时候，我用以下方法getIpinfo获取到的是公网的IP，也就是跟直接在浏览器中输入IP得到的是同样的IP
    //② iPhone4G：不管开不开热点，我用上面HmTool.c获取到的可能应该是相对①中公网IP而言的内网IP（但是跟手机开热点给电脑那个内网不是同一个了），这个IP貌似没啥用？？因为毕竟现在手机这么多不能一个手机号码一个公网IP的
    //③ 手机4G开热点：我用以下方法getIpinfo获取到的也是公网的IP，也就是跟直接在浏览器中输入IP得到的是同样的IP
    //④ 手机4G开热点：与②相同，但是手机开了热点给电脑后，用getIpinfo得到的手机IP跟电脑上看到的IP不是同一个内网的。（所以我目前app编程方法得不到，不过可以用多个方法看到手机的这个内网IP。①电脑设置中看此时的路由IP（一般最后是.1 ？）就是我手机的跟电脑同一个内网的IP。  ②电脑上开一个服务器，手机作为客户端去连接，连接上后电脑会显示哪一个IP连接上了，此即为我手机的跟电脑同一个内网的IP）
    //④ 哇，我用第三方面框架cocoahttpserver，居然手机开热点后，连接HmTool.c得到的网址是可以登录的，而不是像④一样要再看一个更里面的内网，难道第三方已经穿透过去了？还是另有蹊跷？
    //⑤ WiFi：我用以下方法getIpinfo获取到的是公网的IP，也就是跟直接在浏览器中输入IP得到的是同样的IP
    //⑥ WiFi：我用上面HmTool.c获取到的是连在Wi-Fi下的内网IP，连相同的Wi-Fi下两设备可以通过此内网IP连接（当然一个设备直接连公网baidu，我的阿里云服务器这些当然也是可以的，或者花生壳内网穿透喽）
    //⑦ 手机USB连电脑：得到公网IP与③同
    //⑧ 手机USB连电脑：得到公网IP与④同，先看电脑连着的手机USB的热点的IP为172.20.10.4，所以我猜测这样跟电脑一个内网的手机IP为172.20.10.1，或者手机连接电脑开的socketk服务端看看IP，所以手机USBh给热点局域网也是通的。
    
    /*
         内网IP是以下面几个段开头的IP.用户可以自己设置.常用的内网IP地址:
         10.x.x.x
         172.16.x.x至172.31.x.x
         192.168.x.x
     */
    
    //HTTP请求里包括些什么内容？HTTP响应里包括些什么内容？
    //https://blog.csdn.net/a382064640/article/details/21317647
    //若socket模拟http请求
    /*                                    （好像http协议端口80才能请求到，https端口443的请求不到，发送后直接断开）
    //① eg 手机app当作socket客户端连接到百度（www.baidu.com  80）后发送请求（GET / HTTP/1.1\r\nHost:www.baidu.com\r\nConnection:close\r\n\r\n），（最后Connection:close所以收到响应后马上断开？也可以keep-alive）有转义字符所以文本框输入的时候要站换的
    //      收到的请求响应为（HTTP/1.1 200 OK
                        Accept-Ranges: bytes
                        Cache-Control: no-cache
                        Content-Length: 14615
                        Content-Type: text/html
                        Date: Sun, 09 Jun 2019 03:12:53 GMT
                        Etag: "5cf609dc-3917"
                        Last-Modified: Tue, 04 Jun 2019 06:04:12 GMT
                        P3p: CP=" OTI DSP COR IVA OUR IND COM "
                        Pragma: no-cache
                        Server: BWS/1.1
                        Set-Cookie: BAIDUID=3DE98CD64CB70606A8A026F84727E12F:FG=1; expires=Thu, 31-Dec-37 23:55:55 GMT; max-age=2147483647; path=/; domain=.baidu.com
                        Set-Cookie: BIDUPSID=3DE98CD64CB70606A8A026F84727E12F; expires=Thu, 31-Dec-37 23:55:55 GMT; max-age=2147483647; path=/; domain=.baidu.com
                        Set-Cookie: PSTM=1560049973; expires=Thu, 31-Dec-37 23:55:55 GMT; max-age=2147483647; path=/; domain=.baidu.com
                        Vary: Accept-Encoding
                        X-Ua-Compatible: IE=Edge,chrome=1
                        Connection: close
     
                     <!DOCTYPE html><!--STATUS OK-->
                     <html>
                     <head>
                     <meta http-equiv="content-type" content="text...
                     ...
                     ...});};}})();};if(window.pageState==0){initIndex();}})();document.cookie = 'IS_STATIC=1;expires=' + new Date(new Date().getTime() + 10*60*1000).toGMTString();</script>
                     </body></html>
     ）
     
     //② 手机app当作服务器，电脑或者手机浏览器来连接，Mac电脑Safari浏览器输入(eg http://192.168.1.102:9050)
     //   手机服务器得到请求（GET / HTTP/1.1
                         Host: 192.168.1.102:9050
                         Upgrade-Insecure-Requests: 1
                         Accept: text/html,application/xhtml+xml,application/xml;q=0.9,* / *;q=0.8  （⚠️此处* / *本来都是没有空格的，但是由于与注释符号冲突）
                        User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_4) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.1 Safari/605.1.15
                        Accept-Language: en-us
                        Accept-Encoding: gzip, deflate
                        Connection: keep-alive）
        手机app服务器发送相应请求还是有点不行，目前还没有模拟出来。。
    */
    
    
    //https://www.jianshu.com/p/af8e2072a132
    //iOS 获取手机外网和内网IP地址
    
    //App Transport Security has blocked a cleartext HTTP (http://) resource load since it is insecure. Temporary exceptions can be configured via your app's Info.plist file.
    //解决： https://www.cnblogs.com/chglog/p/4746683.html
    /// 获取外网ip
    ///
    /// - Returns: 外网ip,这个方法貌似比较耗时间，到时候最好不要放在主线程
    func getIpinfo() ->String?
    {
        /** 这是ip查询网址 */
        let urlStr = "http://ip.taobao.com/service/getIpInfo.php?ip=myip"
        
        /** 编码为下面转换数据做准备 */
        let strEncoding = urlStr.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)
        if strEncoding != nil {
            do{
                let data = try Data.init(contentsOf: URL.init(string: strEncoding!)!)
                do
                {
                    /** 解析data */
                    if let resultDic = try JSONSerialization.jsonObject(with: data, options: .mutableLeaves) as? [String:Any]
                    {
                        /** 打印结果 这边数据比较多类似以下数据 */
                        /** {
                         code = 0;
                         data =     {
                         area = "\U534e\U4e1c";
                         "area_id" = 300000;
                         city = "\U4e0a\U6d77\U5e02";
                         "city_id" = 310100;
                         country = "\U4e2d\U56fd";
                         "country_id" = CN;
                         county = "";
                         "county_id" = "-1";
                         ip = "139.226.164.200";
                         isp = "\U8054\U901a";
                         "isp_id" = 100026;
                         region = "\U4e0a\U6d77\U5e02";
                         "region_id" = 310000;
                         };
                         } */
                        print(resultDic)
                        /** 用guard逻辑稍微清晰点   */
                        guard let resultCode = resultDic["code"] as? Int  else
                        {
                            print("data error")
                            return nil;
                        }
                        guard resultCode == 0 else
                        {
                            print("code error")
                            return nil
                        }
                        guard let dataDic = resultDic["data"] as? [String:Any] else
                        {
                            print("dic info error")
                            return nil;
                        }
                        guard let ip = dataDic["ip"] as? String else
                        {
                            print("ip error")
                            return nil;
                        }
                        /** 得到最终结果 */
                        return ip
                    }
                }
                catch
                {
                    print(error.localizedDescription)
                }
            }
            catch
            {
                print(error.localizedDescription)
            }
        }
        return nil
    }
    

}




/*
 HTTP/1.1 403 Forbidden
 Date: Mon, 10 Jun 2019 11:03:04 GMT
 Server: Apache/2.4.6 (CentOS) PHP/5.4.16
 Last-Modified: Thu, 16 Oct 2014 13:20:58 GMT
 ETag: "1321-5058a1e728280"
 Accept-Ranges: bytes
 Content-Length: 4897
 Connection: close
 Content-Type: text/html; charset=UTF-8
 
 
 
 <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd"><html><head>
 <meta http-equiv="content-type" content="text/html; charset=UTF-8">
 <title>Apache HTTP Server Test Page powered by CentOS</title>
 <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
 
 <!-- Bootstrap -->
 <link href="/noindex/css/bootstrap.min.css" rel="stylesheet">
 <link rel="stylesheet" href="noindex/css/open-sans.css" type="text/css" />
 
 <style type="text/css"><!--
 
 body {
 font-family: "Open Sans", Helvetica, sans-serif;
 font-weight: 100;
 color: #ccc;
 background: rgba(10, 24, 55, 1);
 font-size: 16px;
 }
 
 h2, h3, h4 {
 font-weight: 200;
 }
 
 h2 {
 font-size: 28px;
 }
 
 .jumbotron {
 margin-bottom: 0;
 color: #333;
 background: rgb(212,212,221); /* Old browsers */
 background: radial-gradient(ellipse at center top, rgba(255,255,255,1) 0%,rgba(174,174,183,1) 100%); /* W3C */
 }
 
 .jumbotron h1 {
 font-size: 128px;
 font-weight: 700;
 color: white;
 text-shadow: 0px 2px 0px #abc,
 0px 4px 10px rgba(0,0,0,0.15),
 0px 5px 2px rgba(0,0,0,0.1),
 0px 6px 30px rgba(0,0,0,0.1);
 }
 
 .jumbotron p {
 font-size: 28px;
 font-weight: 100;
 }
 
 .main {
 background: white;
 color: #234;
 border-top: 1px solid rgba(0,0,0,0.12);
 padding-top: 30px;
 padding-bottom: 40px;
 }
 
 .footer {
 border-top: 1px solid rgba(255,255,255,0.2);
 padding-top: 30px;
 }
 
 --></style>
 </head>
 <body>
 <div class="jumbotron text-center">
 <div class="container">
 <h1>Testing 123..</h1>
 <p class="lead">This page is used to test the proper operation of the <a href="http://apache.org">Apache HTTP server</a> after it has been installed. If you can read this page it means that this site is working properly. This server is powered by <a href="http://centos.org">CentOS</a>.</p>
 </div>
 </div>
 <div class="main">
 <div class="container">
 <div class="row">
 <div class="col-sm-6">
 <h2>Just visiting?</h2>
 <p class="lead">The website you just visited is either experiencing problems or is undergoing routine maintenance.</p>
 <p>If you would like to let the administrators of this website know that you've seen this page instead of the page you expected, you should send them e-mail. In general, mail sent to the name "webmaster" and directed to the website's domain should reach the appropriate person.</p>
 <p>For example, if you experienced problems while visiting www.example.com, you should send e-mail to "webmaster@example.com".</p>
 </div>
 <div class="col-sm-6">
 <h2>Are you the Administrator?</h2>
 <p>You should add your website content to the directory <tt>/var/www/html/</tt>.</p>
 <p>To prevent this page from ever being used, follow the instructions in the file <tt>/etc/httpd/conf.d/welcome.conf</tt>.</p>
 
 <h2>Promoting Apache and CentOS</h2>
 <p>You are free to use the images below on Apache and CentOS Linux powered HTTP servers.  Thanks for using Apache and CentOS!</p>
 <p><a href="http://httpd.apache.org/"><img src="images/apache_pb.gif" alt="[ Powered by Apache ]"></a> <a href="http://www.centos.org/"><img src="images/poweredby.png" alt="[ Powered by CentOS Linux ]" height="31" width="88"></a></p>
 </div>
 </div>
 </div>
 </div>
 </div>
 <div class="footer">
 <div class="container">
 <div class="row">
 <div class="col-sm-6">
 <h2>Important note:</h2>
 <p class="lead">The CentOS Project has nothing to do with this website or its content,
 it just provides the software that makes the website run.</p>
 
 <p>If you have issues with the content of this site, contact the owner of the domain, not the CentOS project.
 Unless you intended to visit CentOS.org, the CentOS Project does not have anything to do with this website,
 the content or the lack of it.</p>
 <p>For example, if this website is www.example.com, you would find the owner of the example.com domain at the following WHOIS server:</p>
 <p><a href="http://www.internic.net/whois.html">http://www.internic.net/whois.html</a></p>
 </div>
 <div class="col-sm-6">
 <h2>The CentOS Project</h2>
 <p>The CentOS Linux distribution is a stable, predictable, manageable and reproduceable platform derived from
 the sources of Red Hat Enterprise Linux (RHEL).<p>
 
 <p>Additionally to being a popular choice for web hosting, CentOS also provides a rich platform for open source communities to build upon. For more information
 please visit the <a href="http://www.centos.org/">CentOS website</a>.</p>
 </div>
 </div>
 </div>
 </div>
 </div>
 </body></html>
 
 
 
 
 
 HTTP/1.1 200 OK
 Accept-Ranges: bytes
 Cache-Control: no-cache
 Content-Length: 14615
 Content-Type: text/html
 Date: Mon, 10 Jun 2019 11:04:29 GMT
 Etag: "5cf609dc-3917"
 Last-Modified: Tue, 04 Jun 2019 06:04:12 GMT
 P3p: CP=" OTI DSP COR IVA OUR IND COM "
 Pragma: no-cache
 Server: BWS/1.1
 Set-Cookie: BAIDUID=9644D5006BE5AF40B857D1157EA1E909:FG=1; expires=Thu, 31-Dec-37 23:55:55 GMT; max-age=2147483647; path=/; domain=.baidu.com
 Set-Cookie: BIDUPSID=9644D5006BE5AF40B857D1157EA1E909; expires=Thu, 31-Dec-37 23:55:55 GMT; max-age=2147483647; path=/; domain=.baidu.com
 Set-Cookie: PSTM=1560164669; expires=Thu, 31-Dec-37 23:55:55 GMT; max-age=2147483647; path=/; domain=.baidu.com
 Vary: Accept-Encoding
 X-Ua-Compatible: IE=Edge,chrome=1
 Connection: keep-alive
 
 
 
 <!DOCTYPE html><!--STATUS OK-->
 
 <html>
 
 <head>
 
 <meta http-equiv="content-type" content="text/html;charset=utf-8">
 
 <meta http-equiv="X-UA-Compatible" content="IE=Edge">
 
 <link rel="dns-prefetch" href="//s1.bdstatic.com"/>
 
 <link rel="dns-prefetch" href="//t1.baidu.com"/>
 
 <link rel="dns-prefetch" href="//t2.baidu.com"/>
 
 <link rel="dns-prefetch" href="//t3.baidu.com"/>
 
 <link rel="dns-prefetch" href="//t10.baidu.com"/>
 
 <link rel="dns-prefetch" href="//t11.baidu.com"/>
 
 <link rel="dns-prefetch" href="//t12.baidu.com"/>
 
 <link rel="dns-prefetch" href="//b1.bdstatic.com"/>
 
 <title>百度一下，你就知道</title>
 
 <link href="http://s1.bdstatic.com/r/www/cache/static/home/css/index.css" rel="stylesheet" type="text/css" />
 
 <!--[if lte IE 8]><style index="index" >#content{height:480px\9}#m{top:260px\9}</style><![endif]-->
 
 <!--[if IE 8]><style index="index" >#u1 a.mnav,#u1 a.mnav:visited{font-family:simsun}</style><![endif]-->
 
 <script>var hashMatch = document.location.href.match(/#+(.*wd=[^&].+)/);if (hashMatch && hashMatch[0] && hashMatch[1]) {document.location.replace("http://"+location.host+"/s?"+hashMatch[1]);}var ns_c = function(){};</script>
 
 <script>function h(obj){obj.style.behavior='url(#default#homepage)';var a = obj.setHomePage('//www.baidu.com/');}</script>
 
 <noscript><meta http-equiv="refresh" content="0; url=/baidu.html?from=noscript"/></noscript>
 
 <script>window._ASYNC_START=new Date().getTime();</script>
 
 </head>
 
 <body link="#0000cc"><div id="wrapper" style="display:none;"><div id="u"><a href="//www.baidu.com/gaoji/preferences.html"  onmousedown="return user_c({'fm':'set','tab':'setting','login':'0'})">搜索设置</a>|<a id="btop" href="/"  onmousedown="return user_c({'fm':'set','tab':'index','login':'0'})">百度首页</a>|<a id="lb" href="https://passport.baidu.com/v2/?login&tpl=mn&u=http%3A%2F%2Fwww.baidu.com%2F" onclick="return false;"  onmousedown="return user_c({'fm':'set','tab':'login'})">登录</a><a href="https://passport.baidu.com/v2/?reg&regType=1&tpl=mn&u=http%3A%2F%2Fwww.baidu.com%2F"  onmousedown="return user_c({'fm':'set','tab':'reg'})" target="_blank" class="reg">注册</a></div><div id="head"><div class="s_nav"><a href="/" class="s_logo" onmousedown="return c({'fm':'tab','tab':'logo'})"><img src="//www.baidu.com/img/baidu_jgylogo3.gif" width="117" height="38" border="0" alt="到百度首页" title="到百度首页"></a><div class="s_tab" id="s_tab"><a href="http://news.baidu.com/ns?cl=2&rn=20&tn=news&word=" wdfield="word"  onmousedown="return c({'fm':'tab','tab':'news'})">新闻</a>&#12288;<b>网页</b>&#12288;<a href="http://tieba.baidu.com/f?kw=&fr=wwwt" wdfield="kw"  onmousedown="return c({'fm':'tab','tab':'tieba'})">贴吧</a>&#12288;<a href="http://zhidao.baidu.com/q?ct=17&pn=0&tn=ikaslist&rn=10&word=&fr=wwwt" wdfield="word"  onmousedown="return c({'fm':'tab','tab':'zhidao'})">知道</a>&#12288;<a href="http://music.baidu.com/search?fr=ps&key=" wdfield="key"  onmousedown="return c({'fm':'tab','tab':'music'})">音乐</a>&#12288;<a href="http://image.baidu.com/i?tn=baiduimage&ps=1&ct=201326592&lm=-1&cl=2&nc=1&word=" wdfield="word"  onmousedown="return c({'fm':'tab','tab':'pic'})">图片</a>&#12288;<a href="http://v.baidu.com/v?ct=301989888&rn=20&pn=0&db=0&s=25&word=" wdfield="word"   onmousedown="return c({'fm':'tab','tab':'video'})">视频</a>&#12288;<a href="http://map.baidu.com/m?word=&fr=ps01000" wdfield="word"  onmousedown="return c({'fm':'tab','tab':'map'})">地图</a>&#12288;<a href="http://wenku.baidu.com/search?word=&lm=0&od=0" wdfield="word"  onmousedown="return c({'fm':'tab','tab':'wenku'})">文库</a>&#12288;<a href="//www.baidu.com/more/"  onmousedown="return c({'fm':'tab','tab':'more'})">更多»</a></div></div><form id="form" name="f" action="/s" class="fm" ><input type="hidden" name="ie" value="utf-8"><input type="hidden" name="f" value="8"><input type="hidden" name="rsv_bp" value="1"><span class="bg s_ipt_wr"><input name="wd" id="kw" class="s_ipt" value="" maxlength="100"></span><span class="bg s_btn_wr"><input type="submit" id="su" value="百度一下" class="bg s_btn" onmousedown="this.className='bg s_btn s_btn_h'" onmouseout="this.className='bg s_btn'"></span><span class="tools"><span id="mHolder"><div id="mCon"><span>输入法</span></div><ul id="mMenu"><li><a href="javascript:;" name="ime_hw">手写</a></li><li><a href="javascript:;" name="ime_py">拼音</a></li><li class="ln"></li><li><a href="javascript:;" name="ime_cl">关闭</a></li></ul></span><span class="shouji"><strong>推荐&nbsp;:&nbsp;</strong><a href="http://w.x.baidu.com/go/mini/8/10000020" onmousedown="return ns_c({'fm':'behs','tab':'bdbrowser'})">百度浏览器，打开网页快2秒！</a></span></span></form></div><div id="content"><div id="u1"><a href="http://news.baidu.com" name="tj_trnews" class="mnav">新闻</a><a href="http://www.hao123.com" name="tj_trhao123" class="mnav">hao123</a><a href="http://map.baidu.com" name="tj_trmap" class="mnav">地图</a><a href="http://v.baidu.com" name="tj_trvideo" class="mnav">视频</a><a href="http://tieba.baidu.com" name="tj_trtieba" class="mnav">贴吧</a><a href="https://passport.baidu.com/v2/?login&tpl=mn&u=http%3A%2F%2Fwww.baidu.com%2F" name="tj_login" id="lb" onclick="return false;">登录</a><a href="//www.baidu.com/gaoji/preferences.html" name="tj_settingicon" id="pf">设置</a><a href="//www.baidu.com/more/" name="tj_briicon" id="bri">更多产品</a></div><div id="m"><p id="lg"><img src="//www.baidu.com/img/bd_logo.png" width="270" height="129"></p><p id="nv"><a href="http://news.baidu.com">新&nbsp;闻</a>　<b>网&nbsp;页</b>　<a href="http://tieba.baidu.com">贴&nbsp;吧</a>　<a href="http://zhidao.baidu.com">知&nbsp;道</a>　<a href="http://music.baidu.com">音&nbsp;乐</a>　<a href="http://image.baidu.com">图&nbsp;片</a>　<a href="http://v.baidu.com">视&nbsp;频</a>　<a href="http://map.baidu.com">地&nbsp;图</a></p><div id="fm"><form id="form1" name="f1" action="/s" class="fm"><span class="bg s_ipt_wr"><input type="text" name="wd" id="kw1" maxlength="100" class="s_ipt"></span><input type="hidden" name="rsv_bp" value="0"><input type=hidden name=ch value=""><input type=hidden name=tn value="baidu"><input type=hidden name=bar value=""><input type="hidden" name="rsv_spt" value="3"><input type="hidden" name="ie" value="utf-8"><span class="bg s_btn_wr"><input type="submit" value="百度一下" id="su1" class="bg s_btn" onmousedown="this.className='bg s_btn s_btn_h'" onmouseout="this.className='bg s_btn'"></span></form><span class="tools"><span id="mHolder1"><div id="mCon1"><span>输入法</span></div></span></span><ul id="mMenu1"><div class="mMenu1-tip-arrow"><em></em><ins></ins></div><li><a href="javascript:;" name="ime_hw">手写</a></li><li><a href="javascript:;" name="ime_py">拼音</a></li><li class="ln"></li><li><a href="javascript:;" name="ime_cl">关闭</a></li></ul></div><p id="lk"><a href="http://baike.baidu.com">百科</a>　<a href="http://wenku.baidu.com">文库</a>　<a href="http://www.hao123.com">hao123</a><span>&nbsp;|&nbsp;<a href="//www.baidu.com/more/">更多&gt;&gt;</a></span></p><p id="lm"></p></div></div><div id="ftCon"><div id="ftConw"><p id="lh"><a id="seth" onClick="h(this)" href="/" onmousedown="return ns_c({'fm':'behs','tab':'homepage','pos':0})">把百度设为主页</a><a id="setf" href="//www.baidu.com/cache/sethelp/index.html" onmousedown="return ns_c({'fm':'behs','tab':'favorites','pos':0})" target="_blank">把百度设为主页</a><a onmousedown="return ns_c({'fm':'behs','tab':'tj_about'})" href="http://home.baidu.com">关于百度</a><a onmousedown="return ns_c({'fm':'behs','tab':'tj_about_en'})" href="http://ir.baidu.com">About Baidu</a></p><p id="cp">&copy;2018&nbsp;Baidu&nbsp;<a href="/duty/" name="tj_duty">使用百度前必读</a>&nbsp;京ICP证030173号&nbsp;<img src="http://s1.bdstatic.com/r/www/cache/static/global/img/gs_237f015b.gif"></p></div></div><div id="wrapper_wrapper"></div></div><div class="c-tips-container" id="c-tips-container"></div>
 
 <script>window.__async_strategy=2;</script>
 
 <script>var bds={se:{},su:{urdata:[],urSendClick:function(){}},util:{},use:{},comm : {domain:"http://www.baidu.com",ubsurl : "http://sclick.baidu.com/w.gif",tn:"baidu",queryEnc:"",queryId:"",inter:"",templateName:"baidu",sugHost : "http://suggestion.baidu.com/su",query : "",qid : "",cid : "",sid : "",indexSid : "",stoken : "",serverTime : "",user : "",username : "",loginAction : [],useFavo : "",pinyin : "",favoOn : "",curResultNum:"",rightResultExist:false,protectNum:0,zxlNum:0,pageNum:1,pageSize:10,newindex:0,async:1,maxPreloadThread:5,maxPreloadTimes:10,preloadMouseMoveDistance:5,switchAddMask:false,isDebug:false,ishome : 1},_base64:{domain : "http://b1.bdstatic.com/",b64Exp : -1,pdc : 0}};var name,navigate,al_arr=[];var selfOpen = window.open;eval("var open = selfOpen;");var isIE=navigator.userAgent.indexOf("MSIE")!=-1&&!window.opera;var E = bds.ecom= {};bds.se.mon = {'loadedItems':[],'load':function(){},'srvt':-1};try {bds.se.mon.srvt = parseInt(document.cookie.match(new RegExp("(^| )BDSVRTM=([^;]*)(;|$)"))[2]);document.cookie="BDSVRTM=;expires=Sat, 01 Jan 2000 00:00:00 GMT"; }catch(e){}</script>
 
 <script>if(!location.hash.match(/[^a-zA-Z0-9]wd=/)){document.getElementById("ftCon").style.display='block';document.getElementById("u1").style.display='block';document.getElementById("content").style.display='block';document.getElementById("wrapper").style.display='block';setTimeout(function(){try{document.getElementById("kw1").focus();document.getElementById("kw1").parentNode.className += ' iptfocus';}catch(e){}},0);}</script>
 
 <script type="text/javascript" src="http://s1.bdstatic.com/r/www/cache/static/jquery/jquery-1.10.2.min_f2fb5194.js"></script>
 
 <script>(function(){var index_content = $('#content');var index_foot= $('#ftCon');var index_css= $('head [index]');var index_u= $('#u1');var result_u= $('#u');var wrapper=$("#wrapper");window.index_on=function(){index_css.insertAfter("meta:eq(0)");result_common_css.remove();result_aladdin_css.remove();result_sug_css.remove();index_content.show();index_foot.show();index_u.show();result_u.hide();wrapper.show();if(bds.su&&bds.su.U&&bds.su.U.homeInit){bds.su.U.homeInit();}setTimeout(function(){try{$('#kw1').get(0).focus();window.sugIndex.start();}catch(e){}},0);if(typeof initIndex=='function'){initIndex();}};window.index_off=function(){index_css.remove();index_content.hide();index_foot.hide();index_u.hide();result_u.show();result_aladdin_css.insertAfter("meta:eq(0)");result_common_css.insertAfter("meta:eq(0)");result_sug_css.insertAfter("meta:eq(0)");wrapper.show();};})();</script>
 
 <script>window.__switch_add_mask=1;</script>
 
 <script type="text/javascript" src="http://s1.bdstatic.com/r/www/cache/static/global/js/instant_search_newi_redirect1_20bf4036.js"></script>
 
 <script>initPreload();$("#u,#u1").delegate("#lb",'click',function(){try{bds.se.login.open();}catch(e){}});if(navigator.cookieEnabled){document.cookie="NOJS=;expires=Sat, 01 Jan 2000 00:00:00 GMT";}</script>
 
 <script>$(function(){for(i=0;i<3;i++){u($($('.s_ipt_wr')[i]),$($('.s_ipt')[i]),$($('.s_btn_wr')[i]),$($('.s_btn')[i]));}function u(iptwr,ipt,btnwr,btn){if(iptwr && ipt){iptwr.on('mouseover',function(){iptwr.addClass('ipthover');}).on('mouseout',function(){iptwr.removeClass('ipthover');}).on('click',function(){ipt.focus();});ipt.on('focus',function(){iptwr.addClass('iptfocus');}).on('blur',function(){iptwr.removeClass('iptfocus');}).on('render',function(e){var $s = iptwr.parent().find('.bdsug');var l = $s.find('li').length;if(l>=5){$s.addClass('bdsugbg');}else{$s.removeClass('bdsugbg');}});}if(btnwr && btn){btnwr.on('mouseover',function(){btn.addClass('btnhover');}).on('mouseout',function(){btn.removeClass('btnhover');});}}});</script>
 
 <script type="text/javascript" src="http://s1.bdstatic.com/r/www/cache/static/home/js/bri_7f1fa703.js"></script>
 
 <script>(function(){var _init=false;window.initIndex=function(){if(_init){return;}_init=true;var w=window,d=document,n=navigator,k=d.f1.wd,a=d.getElementById("nv").getElementsByTagName("a"),isIE=n.userAgent.indexOf("MSIE")!=-1&&!window.opera;(function(){if(/q=([^&]+)/.test(location.search)){k.value=decodeURIComponent(RegExp["\x241"])}})();(function(){var u = G("u1").getElementsByTagName("a"), nv = G("nv").getElementsByTagName("a"), lk = G("lk").getElementsByTagName("a"), un = "";var tj_nv = ["news","tieba","zhidao","mp3","img","video","map"];var tj_lk = ["baike","wenku","hao123","more"];un = bds.comm.user == "" ? "" : bds.comm.user;function _addTJ(obj){addEV(obj, "mousedown", function(e){var e = e || window.event;var target = e.target || e.srcElement;if(target.name){ns_c({'fm':'behs','tab':target.name,'un':encodeURIComponent(un)});}});}for(var i = 0; i < u.length; i++){_addTJ(u[i]);}for(var i = 0; i < nv.length; i++){nv[i].name = 'tj_' + tj_nv[i];}for(var i = 0; i < lk.length; i++){lk[i].name = 'tj_' + tj_lk[i];}})();(function() {var links = {'tj_news': ['word', 'http://news.baidu.com/ns?tn=news&cl=2&rn=20&ct=1&ie=utf-8'],'tj_tieba': ['kw', 'http://tieba.baidu.com/f?ie=utf-8'],'tj_zhidao': ['word', 'http://zhidao.baidu.com/search?pn=0&rn=10&lm=0'],'tj_mp3': ['key', 'http://music.baidu.com/search?fr=ps&ie=utf-8'],'tj_img': ['word', 'http://image.baidu.com/i?ct=201326592&cl=2&nc=1&lm=-1&st=-1&tn=baiduimage&istype=2&fm=&pv=&z=0&ie=utf-8'],'tj_video': ['word', 'http://video.baidu.com/v?ct=301989888&s=25&ie=utf-8'],'tj_map': ['wd', 'http://map.baidu.com/?newmap=1&ie=utf-8&s=s'],'tj_baike': ['word', 'http://baike.baidu.com/search/word?pic=1&sug=1&enc=utf8'],'tj_wenku': ['word', 'http://wenku.baidu.com/search?ie=utf-8']};var domArr = [G('nv'), G('lk'),G('cp')],kw = G('kw1');for (var i = 0, l = domArr.length; i < l; i++) {domArr[i].onmousedown = function(e) {e = e || window.event;var target = e.target || e.srcElement,name = target.getAttribute('name'),items = links[name],reg = new RegExp('^\\s+|\\s+\x24'),key = kw.value.replace(reg, '');if (items) {if (key.length > 0) {var wd = items[0], url = items[1],url = url + ( name === 'tj_map' ? encodeURIComponent('&' + wd + '=' + key) : ( ( url.indexOf('?') > 0 ? '&' : '?' ) + wd + '=' + encodeURIComponent(key) ) );target.href = url;} else {target.href = target.href.match(new RegExp('^http:\/\/.+\.baidu\.com'))[0];}}name && ns_c({'fm': 'behs','tab': name,'query': encodeURIComponent(key),'un': encodeURIComponent(bds.comm.user || '') });};}})();};if(window.pageState==0){initIndex();}})();document.cookie = 'IS_STATIC=1;expires=' + new Date(new Date().getTime() + 10*60*1000).toGMTString();</script>
 
 </body></html>
 */
