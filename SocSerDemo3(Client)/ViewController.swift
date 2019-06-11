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
    @IBOutlet weak var userfulInfo: UITextView!
    
    
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
    //只要收到的信息都在这里
    var receivedInfo = "" {
        didSet {
            receivedStr.text = receivedInfo
            receivedStr.scrollRangeToVisible(NSMakeRange(receivedStr.text.lengthOfBytes(using: .utf8), 0))
        }
    }
    //收到的有用的信息
    var userfulInfoStr = "" {
        didSet {
            userfulInfo.text = userfulInfoStr
            userfulInfo.scrollRangeToVisible(NSMakeRange(userfulInfo.text.lengthOfBytes(using: .utf8), 0))
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
        
        
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(switchReceViews))
        doubleTap.numberOfTapsRequired = 2
        let doubleTap2 = UITapGestureRecognizer(target: self, action: #selector(switchReceViews2))
        doubleTap2.numberOfTapsRequired = 2
        receivedStr.addGestureRecognizer(doubleTap)
        userfulInfo.addGestureRecognizer(doubleTap2)
    }
    
    @objc func switchReceViews(_ ges: UITapGestureRecognizer) {
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn, animations: { [unowned self] in
            self.receivedStr.alpha = 0
            self.userfulInfo.alpha = 1
        }, completion: nil)
    }
    @objc func switchReceViews2(_ ges: UITapGestureRecognizer) {
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn, animations: { [unowned self] in
            self.receivedStr.alpha = 1
            self.userfulInfo.alpha = 0
        }, completion: nil)
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
    var continueStr = ""
    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        // 1 获取客户的发来的数据 ，把 NSData 转 NSString
        let readClientDataSStr = NSString(data: data, encoding: String.Encoding.utf8.rawValue)
//        let readClientDataStr = readClientDataSStr! as String
        var readClientDataStr = readClientDataSStr!.description
        
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
        
        readClientDataStr = continueStr + readClientDataStr
        //Content-Length现在还不确定到底怎么算，我用pages算了一下若一个算一个字节的话只有412而不是523，但是我不论填写412还是523，浏览器都能显示完全，但是显示完了浏览器还在转就是在加载，感觉没加载完的样子？？keep-alive
        //哇，以下字符串格式要严格按照下面的来（就是字符串跟let平齐写，然后最后的三个引号也要平齐）他才可以解析到什么是header什么是body，不然的话它会把header也解析为body的,所以没有看到header的话加载完了也一直加载中，但是奇怪的是就算header被解析为body但是不加的话浏览器会说收到错误响应
        //好像有点清楚Content-Length怎么计算的了，①空格是算的，②回车\r\n是算一个的, ③汉子貌似算两个字符？？？④pages放到Xcode中时，要按照XCode的行数来算 ⑤每一行最后多出来的空格不要算
        
        
        //1062+44+25*2
        //1821是正好的，因为若大于1156浏览器还要再加载等到你发的字符等于它，若小x于，抓包的时候抓到的内容会比我现在发送的少
        //比如发1820，那么最后浏览器收到的只有</html，少了一个字节的 >    .
        // (注意换行符的时候Pages一段话（不论是否下一行）只有一个换行，但是到XCode中到下一行了就算一个换行了的，还有pages后面每一行多余的空格都是不能算的)
        /*⚠️注意enctype=“application/x-www-form-urlencoded”时，发送到服务端的时候
        不会有分隔符“——WebKitFormBoundaryai8MzIxXQVpZLLWX”，网上查了下默认不写就是这个enctype。而enctype=“multipart/form-data”据说是给传图片之类的用的？但是我既然写好了我还是用enctype=“application/x-www-form-urlencoded”吧。
         */
        let response1 = """
        HTTP/1.1 200 OK
        Accept-Ranges: bytes
        Content-Length: 1821
        Proxy-Connection: keep-alive

        <!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
        <html lang="en">
            <head>
                <meta charset="UTF-8">
                <title>Hello JiaCheng!</title>
            </head>

            <body>
                <h2>一个标题</h2>
                <p>这是测试，传输数据</p>

                <a href="http://DoLNw.github.io"> JiaChengCc07 </a><br/>

                <p> 这是初次练习表格 </p>
                <table border="1">
                    <th>列1</th>
                    <th>列2</th>
                    <th>列3</th>
                    <th>列4</th>
                    <tr>
                        <td rowspan="3">1</td>
                        <td colspan="2">1</td>
                        <td rowspan="3">4</td>
                    </tr>
                    <tr>
                        <td>22</td>
                        <td>23</td>
                    </tr>
                    <tr>
                        <td>32</td>
                        <td>33</td>
                    </tr>
                </table>

                <script>
                let text = "Nice to Meet You too!";
                function editDocument() {
                    document.write(text)
                }
                </script>
                <br><br>
                <button onclick="editDocument()"> Post </button>

                <br><br>
                <form method="post" enctype="multipart/form-data" accept-charset="utf-8">
                    <p>Send what you want: <input type="text" name="name"></p>
                    <input type="submit" value="submit" style = " width : 50px ;
                        height : 20px ; color = red ; background : #84C134 " >
                </form>

                <form method="post" enctype="multipart/form-data" accept-charset="utf-8">
                    <p><input type="text" name="name" value="Hello server." hidden="true"></p>
                    <input type="submit" value="It's a button sending hello to server." style = " width : 200px ;
                        height : 20px ; color = red ; background : #84C134 " >
                </form>
            </body>
        </html>
        """
        
        if readClientDataStr.prefix(3) == "GET" {
            
            sock.write(response1.data(using: .utf8)!, withTimeout: -1, tag: 0)
            continueStr = ""
        } else if readClientDataStr.prefix(4) == "POST" {
            //有的情况下这个post的头和正文会分两次发送
            if readClientDataStr.hasSuffix("en-us\r\n\r\n") {
                continueStr = readClientDataStr
            } else {
                let infors = readClientDataStr.components(separatedBy: "\r\n")
                
                if infors.count-3 > 0 && infors[infors.count-1] == "" && infors[infors.count-2] != "" && infors[infors.count-3] != "" {
                    let infor = infors[infors.count-3]
                    userfulInfoStr += infor + "\n"
                }
                
                sock.write(response1.data(using: .utf8)!, withTimeout: -1, tag: 0)
                continueStr = ""
            }
        } else {
            userfulInfoStr += readClientDataStr + "\n"
            continueStr = ""
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
