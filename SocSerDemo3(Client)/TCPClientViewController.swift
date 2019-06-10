//
//  TCPClientViewController.swift
//  SocSerDemo3(Client)
//
//  Created by JiaCheng on 2018/9/2.
//  Copyright © 2018年 JiaCheng. All rights reserved.
//

import UIKit

class TCPClientViewController: UIViewController, GCDAsyncSocketDelegate, UITextFieldDelegate {
    
    @IBOutlet weak var IPAddressField: UITextField!
    @IBOutlet weak var portField: UITextField!
    @IBOutlet weak var statusField: UITextField!
    @IBOutlet weak var sendField: UITextField!
    @IBOutlet weak var sendBtn: UIButton!
    @IBOutlet weak var receivedTextView: UITextView!
    @IBOutlet weak var connectedDevicesTextView: UITextView!
    
    var connectDevicesInfo = "" {
        didSet {
            connectedDevicesTextView.text = connectDevicesInfo
        }
    }
    
    var receiveInfo = "" {
        didSet {
            receivedTextView.text = receiveInfo
            receivedTextView.scrollRangeToVisible(NSMakeRange(receivedTextView.text.lengthOfBytes(using: .utf8), 1))
        }
    }
    
    var connectBtn: UIBarButtonItem!
    var disConnectBtn: UIBarButtonItem!
    //需要赋给spinnerBtn的customView属性为UIActivityIndicatorView(activityIndicatorStyle: .gray)才能旋转。
    var spinnerBtn: UIBarButtonItem!
    var isConnected = false
    
    var clientSocket: GCDAsyncSocket!
    
    //MARK: - View SetUp
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        self.title = "TCP Client"
        
        connectDevicesInfo = "服务器地址：\n本地客户端:\n"
        
        sendField.delegate = self
        IPAddressField.delegate = self
        portField.delegate = self
        
        connectBtn = UIBarButtonItem(title: "Connect", style: .plain, target: self, action: #selector(connectToServer))
        disConnectBtn = UIBarButtonItem(title: "DisConnect", style: .plain, target: self, action: #selector(disConnect))
        spinnerBtn = UIBarButtonItem(customView: UIActivityIndicatorView(style: .gray))
        (spinnerBtn.customView as! UIActivityIndicatorView).startAnimating()
        disConnectBtn.tintColor = UIColor.red
        navigationItem.rightBarButtonItem = connectBtn
    }
    
    //MARK: - BtnMethod
    @IBAction func sendAction(_ sender: UIButton) {
        sendField.resignFirstResponder()
        
        guard isConnected else { showAlertWithTitle("Error", andMessage: "Please connect to server first."); return}
        
        if let sendData = convertToEscapeData() {
            //发送过去好像自动加换行的诶？
            clientSocket.write(sendData, withTimeout: -1, tag: 0)
        } else {
            showAlertWithTitle("Error", andMessage: "Send Error.");
        }
    }
    
    @objc func connectToServer() {
        portField.resignFirstResponder()
        IPAddressField.resignFirstResponder()
        
        clientSocket = GCDAsyncSocket()
        clientSocket.delegate = self
        clientSocket.delegateQueue = DispatchQueue.main
        
        if let host = IPAddressField.text {
            if let port = UInt16(portField.text!) {
                do {
                    //加了超时后，如果没有连接上，也会调用disconnect？而且不加超时也会，而且都是很快的调用的，时间跟超时时间不搭嘎
                    //呀呀呀，这个超时还真的有用的。如果输入的是无效的IP，它会立刻invokedisconnect，但是如果是有效的，它就会在我给定时间内尝试连接，这样就是1.5加上下面的延时1.5为3s。
                    try clientSocket.connect(toHost: host, onPort: port, withTimeout: 1.5)
                    
                    navigationItem.rightBarButtonItem = spinnerBtn
                    UIView.animate(withDuration: 0.5) {
                        self.view.backgroundColor = UIColor.gray
                    }
                    
                    //由于此时还不算连接成功，为0
//                    print(clientSocket.localPort)
//                    print(clientSocket.connectedPort)
                    
                    //连接成功后会有代理触发（invoke）
                    return
                } catch {
                    showAlertWithTitle("Error", andMessage: error.localizedDescription)
                    return
                }
            }
        }
        
        showAlertWithTitle("Error", andMessage: "Please write valid data.")
        
    }
    
    @objc func disConnect() {
        clientSocket.disconnect()
    }
    
    //MARK: - GCDAsyncSocketDelegate
    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [unowned self] in
            UIView.animate(withDuration: 0.25) {
                self.view.backgroundColor = UIColor.white
            }
            self.navigationItem.rightBarButtonItem = self.disConnectBtn
        }
        isConnected = true
        statusField.text = "Status: " + host + ":" + String(port)  + " 已连接"
        clientSocket.readData(withTimeout: -1, tag: 0)
        
        //因为连接成功，所以此时两个输出一样，因为它们本来就是用一个。
        //local是指我自己这个客户端，connected是指对方的服务器。
        //与自己创建服务器得到的newSocket的两者相反（以下一句话纯属本人理解：因为newSocket会指代服务器衍生出的socket，对面客户端也是有一个socket的，但他们是同一个）。
//        print(clientSocket.localPort)
//        print(sock.localPort)
        connectDevicesInfo = "服务器地址:" + host + ":" + String(port) + "\n"
        connectDevicesInfo += "本地客户端:" + clientSocket.localHost! + ":" + String(clientSocket.localPort)
        
    }
    
    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        //如果触发这个的时候根本没有连着，那就证明是刚要连接而且连接失败了
        if !isConnected {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [unowned self] in
                UIView.animate(withDuration: 0.5) {
                    self.view.backgroundColor = UIColor.white
                }
                self.showAlertWithTitle("Error", andMessage: "连接请求超时")
                self.navigationItem.rightBarButtonItem = self.connectBtn
            }
        } else {
            statusField.text = "Status: 无连接"
            connectDevicesInfo = "服务器地址：\n本地客户端:\n"
            isConnected = false
            self.navigationItem.rightBarButtonItem = self.connectBtn
        }
        
    }
    
    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        //以下两句打印出来的是ascii码居然，比如1是31？,感觉可能在转到nsdata的时候使用编码utf8可能会好？？
//        let receiveData = NSData(data: data)
//        let receiveMassage = receiveData.description
        
        let receiveSStr = NSString(data: data, encoding: String.Encoding.utf8.rawValue)
        let receiveStr = receiveSStr!.description
        
        receiveInfo += receiveStr
        
        print(receiveInfo)
        
        clientSocket.readData(withTimeout: -1, tag: 0)
    }
    
    
    //MARK: - extralTask
    func showAlertWithTitle(_ title:String?, andMessage message:String?) {
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(ac, animated: true)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == sendField {
            sendAction(sendBtn)
        } else if textField == IPAddressField {
            portField.becomeFirstResponder()
        } else if textField == portField {
            connectToServer()
        }
        
        return true
    }
    
    func convertToEscapeData() -> Data? {
        guard let sendStr = sendField.text else { return nil }
        var sendStrCopy = sendStr
        var slashIndexs = [String.Index]()
        while sendStrCopy.contains(#"\"#) {
            let index = sendStrCopy.firstIndex(of: "\\")!
            
            let secondIndex = sendStrCopy.index(after: index)
            
            switch sendStrCopy[secondIndex] {
            case "0":
                sendStrCopy.insert("\0", at: index)
                sendStrCopy.remove(at: secondIndex)
                sendStrCopy.remove(at: secondIndex)
            case "t":
                sendStrCopy.insert("\t", at: index)
                sendStrCopy.remove(at: secondIndex)
                sendStrCopy.remove(at: secondIndex)
            case "n":
                sendStrCopy.insert("\n", at: index)
                sendStrCopy.remove(at: secondIndex)
                sendStrCopy.remove(at: secondIndex)
            case "r":
                sendStrCopy.insert("\r", at: index)
                sendStrCopy.remove(at: secondIndex)
                sendStrCopy.remove(at: secondIndex)
            case "\\":
                slashIndexs.append(index)
                sendStrCopy.remove(at: index)
                sendStrCopy.remove(at: index)
            case "u":
                var number = 0
                var indexcc = sendStrCopy.index(after: secondIndex)
                
                let indexstart = sendStrCopy.index(after: indexcc)
                indexcc = sendStrCopy.index(after: indexcc)
                
                while(sendStrCopy[indexcc] != "}") {
                    number += 1
                    indexcc = sendStrCopy.index(after: indexcc)
                }
                
                var valueString = sendStrCopy[indexstart..<indexcc]
                if valueString.hasPrefix("0x") && number>=2 {
                    valueString.removeFirst()
                    valueString.removeFirst()
                    
                    if let uint8 = UInt8(valueString, radix: 16) {
                        sendStrCopy.insert(Character(UnicodeScalar(uint8)), at: index)
                        
                        for _ in 0...3+number {
                            sendStrCopy.remove(at: secondIndex)
                        }
                    }
                } else if let uint8 = UInt8(valueString) {
                    sendStrCopy.insert(Character(UnicodeScalar(uint8)), at: index)
                    
                    for _ in 0...3+number {
                        sendStrCopy.remove(at: secondIndex)
                    }
                }
            default:
                break
            }
        }
        for index in slashIndexs.reversed() {
            sendStrCopy.insert(#"\"#, at: index)
        }
        
        print(sendStrCopy)
        
        return sendStrCopy.data(using: .utf8)
    }
    
    //这个应该不是textField的代理，就是在一个地方点击后，触发的。可以写resignFirstRespond，但是我这个点在textView里面它们可以收回，而且textField这里不止一个，我就不在这里面写了。我之前还拖一个touch进去，看起来不用了。
//    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
//        sendField.resignFirstResponder()
//    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
