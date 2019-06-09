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
        let serviceStr =  "Login successful\n"
        newSocket.write(serviceStr.data(using: .utf8)!, withTimeout: -1, tag: 0)
        
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
            sock.write("<H1> Hello, World! <H1>".data(using: .utf8)!, withTimeout: -1, tag: 0)
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
    //⑤ WiFi：我用以下方法getIpinfo获取到的是公网的IP，也就是跟直接在浏览器中输入IP得到的是同样的IP
    //⑥ WiFi：我用上面HmTool.c获取到的是连在Wi-Fi下的内网IP，连相同的Wi-Fi下两设备可以通过此内网IP连接（当然一个设备直接连公网baidu，我的阿里云服务器这些当然也是可以的，或者花生壳内网穿透喽）
    
    //HTTP请求里包括些什么内容？HTTP响应里包括些什么内容？
    //https://blog.csdn.net/a382064640/article/details/21317647
    //若socket模拟http请求
    /*
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

