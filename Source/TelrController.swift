//
//  TelrController.swift
//  TelrSDK
//
//  Created by Telr Sdk on 10/02/2020.
//  Copyright (c) 2020 Telr Sdk. All rights reserved.
//

import UIKit

import WebKit

public protocol TelrControllerDelegate {
    
    func didPaymentCancel()
    
    func didPaymentSuccess(response:TelrResponseModel)
    
    func didPaymentFail(messge:String)
}

public class TelrController: UIViewController, XMLParserDelegate {

    @objc var webView : WKWebView = WKWebView()
    
    var actInd: UIActivityIndicatorView?
    
    public var delegate : TelrControllerDelegate?
    
    private var _paymentRequest:PaymentRequest?
    
    private var _code:String?
    
    private var _status:String?
    
    private var _avs:String?
    
    private var _ca_valid:String?
    
    private var _cardCode:String?
    
    private var _cardLast4:String?
    
    private var _cvv:String?
    
    private var _tranRef:String?
    
    private var _transFirstRef:String?
    
    private var _trace:String?
    
    private var _cardFirst6:String?

    public var paymentRequest:PaymentRequest{
        get{
            return _paymentRequest!
           }
        set{
            _paymentRequest = newValue
            _paymentRequest?.deviceType = "iPhone"
            _paymentRequest?.deviceId = UIDevice.current.identifierForVendor!.uuidString
        }
    }
    
    public var customBackButton : UIButton?
    
    public override func viewDidLoad() {
        super.viewDidLoad()

        self.addBackButton()
        
        DispatchQueue.main.async {
            
            self.navigationController?.presentationController?.presentedView?.gestureRecognizers?[0].isEnabled = false
            
            self.createWebView()
                   
        }

        self.loadPaymentPage()
        
    }
    
    func addBackButton() {
        
        if let customBackButton = self.customBackButton {
            
            customBackButton.addTarget(self, action: #selector(self.backAction(_:)), for: .touchUpInside)
            
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: customBackButton)
        
        }else{
            
            let backButton = UIButton(type: .custom)
            
            backButton.setTitle("Back", for: .normal)
            
            backButton.setTitleColor(backButton.tintColor, for: .normal)
            
            backButton.addTarget(self, action: #selector(self.backAction(_:)), for: .touchUpInside)
            
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: backButton)
        }
       
    }
    @objc func backAction(_ sender: UIButton) {
       
        self.delegate?.didPaymentCancel()
    
        self.dismiss(animated: true, completion: nil)
    
        let _ = self.navigationController?.popViewController(animated: true)
    }
    @objc func createWebView() {

            
        let configuration = WKWebViewConfiguration()
            
        let viewBack = UIView()
        
        viewBack.backgroundColor = .white
        
        viewBack.frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.height)
        
        webView = WKWebView(frame: CGRect.zero, configuration: configuration)
            
        webView.frame = CGRect(x: 0, y: 0, width: viewBack.bounds.width, height: viewBack.bounds.height)
            
        webView.navigationDelegate = self
        
        webView.uiDelegate = self
        
        webView.navigationDelegate = self
        
        webView.backgroundColor = .white
        
        webView.scrollView.delegate = self
        
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        webView.scrollView.alwaysBounceHorizontal = false
        
        if #available(iOS 11.0, *) {
            webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        } else {
            // Fallback on earlier versions
        }
        
        webView.scrollView.alwaysBounceVertical = false
        
        webView.scrollView.isDirectionalLockEnabled = true
        
        webView.backgroundColor = UIColor.white
        
        webView.isMultipleTouchEnabled = false
        
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        viewBack.addSubview(webView)
        
        self.view.addSubview(viewBack)
        
        self.showActivityIndicatory(uiView: self.webView)
            
    }
    
    func showActivityIndicatory(uiView: UIView) {
        
        actInd = UIActivityIndicatorView()
        
        actInd?.frame = CGRect(x: 0.0, y: -20, width: 40.0, height: 40.0);
        
        actInd?.center = uiView.center
        
        actInd?.hidesWhenStopped = true
        
        if #available(iOS 13.0, *) {
            actInd?.style = UIActivityIndicatorView.Style.medium
        } else {
            // Fallback on earlier versions
            actInd?.style = UIActivityIndicatorView.Style.gray
        }
        
        actInd?.color = .black
        
        uiView.addSubview(actInd!)
        
        actInd?.startAnimating()
    }
    
   
    
    @objc func loadPaymentPage(){
    
            let xml:String = self.initiatePaymentGateway(paymentRequest:self.paymentRequest)
            let data = xml.data(using: .utf8)
            let url = URL(string:"https://secure.telr.com/gateway/mobile.xml")
               
            if let newurl = url{
                   
                var request = URLRequest(url: newurl)
                
                request.httpMethod = "post"
                
                request.httpBody = data
                   
                URLSession.shared.dataTask(with: request, completionHandler: { data, response, error -> Void in
                    
                    
                    if let data = data{


                        let parser = XMLParser(data: data)
                        parser.delegate = self
                        parser.parse()

                        let xmlresponse = XML.parse(data)

                        if let message = xmlresponse["mobile","auth","message"].text{
                            print(message)
                            DispatchQueue.main.async {
                                self.delegate?.didPaymentFail(messge: message)

                                self.dismiss(animated: true, completion: nil)

                                let _ = self.navigationController?.popViewController(animated: true)
                            }

                        }else{

                            let start = xmlresponse["mobile","webview","start"]

                            let code = xmlresponse["mobile","webview","code"]

                            self._code = code.text!

                            let newurl = URL(string:start.text!)

                            let newrequest = URLRequest(url: newurl!)

                            DispatchQueue.main.async {

                                self.webView.load(newrequest)

                            }

                        }

                    }
                   
                    
                    if error != nil {
                        DispatchQueue.main.async {
                            self.delegate?.didPaymentFail(messge: "Network error!")
                               
                            self.dismiss(animated: true, completion: nil)
                               
                            let _ = self.navigationController?.popViewController(animated: true)
                        }
                    }
                    
                   
                }).resume()
               
            }
    }
    
    private func initiateStatusRequest(key:String, store:String, complete:String) -> String{
        let xmlString =  """
         <?xml version=\"1.0\"?>
         <mobile>
             <store>\(store)</store>
             <key>\(key)</key>
             <complete>\(complete)</complete>
         </mobile>
         """
        return xmlString
    }
    
    private func checkStatus(key:String, store:String, complete:String, completionHandler:@escaping (Bool) -> ()) -> Void{
        
        let completeURL = "https://secure.telr.com/gateway/mobile_complete.xml"
        
        let xml:String = initiateStatusRequest(key:key, store:store, complete: complete)

        print(xml)
       
        let data = xml.data(using: .utf8)
        
        let url = URL(string:completeURL)
        
        if let newurl = url{
            
            var request = URLRequest(url: newurl)
            
            request.httpMethod = "post"
            
            request.httpBody = data
            
            URLSession.shared.dataTask(with: request, completionHandler: { data, response, error -> Void in
               
                if let data = data{

                    let str = String(decoding: data, as: UTF8.self)

                    let xmlresponse = XML.parse(data)

                    print("=======\(str)=======")


                    let statusMessage = xmlresponse["mobile","auth","message"]


                    self._code = xmlresponse["mobile","auth","code"].text

                    self._status = xmlresponse["mobile","auth","status"].text

                    self._avs = xmlresponse["mobile","auth","avs"].text

                    self._ca_valid = xmlresponse["mobile","auth","ca_valid"].text

                    self._cardCode = xmlresponse["mobile","auth","cardcode"].text

                    self._cardLast4 = xmlresponse["mobile","auth","cardlast4"].text

                    self._cvv = xmlresponse["mobile","auth","cvv"].text!

                    self._tranRef = xmlresponse["mobile","auth","tranref"].text

                    self._transFirstRef = xmlresponse["mobile","auth","tranfirstref"].text

                    self._trace = xmlresponse["mobile","trace"].text

                    self._cardFirst6 = xmlresponse["mobile","auth","cardfirst6"].text

                    if statusMessage.text == "Authorised"{

                        completionHandler(true)

                    }else{

                        completionHandler(false)

                    }

                }
               
                if error != nil {
                    DispatchQueue.main.async {
                        self.delegate?.didPaymentFail(messge: "Network error!")
                           
                        self.dismiss(animated: true, completion: nil)
                           
                        let _ = self.navigationController?.popViewController(animated: true)
                    }
                }
                
            }).resume()
            
        }
    }
    private func initiatePaymentGateway(paymentRequest: PaymentRequest) -> String{
        let xmlString = """
        <?xml version=\"1.0\"?>
        <mobile>
            <store>\(paymentRequest.store)</store>
            <key>\(paymentRequest.key)</key>
            <device>
                <type>\(paymentRequest.deviceType)</type>
                <id>\(paymentRequest.deviceId)</id>
            </device>
            <app>
                <id>\(paymentRequest.appId)</id>
                <name>\(paymentRequest.appName)</name>
                <user>\(paymentRequest.appUser)</user>
                <version>\(paymentRequest.appVersion)</version>
                <sdk>SDK ver 2.0</sdk>
            </app>
            <tran>
                <test>\(paymentRequest.transTest)</test>
                <type>\(paymentRequest.transType)</type>
                <class>\(paymentRequest.transClass)</class>
                <cartid>\(paymentRequest.transCartid)</cartid>
                <description>\(paymentRequest.transDesc)</description>
                <currency>\(paymentRequest.transCurrency)</currency>
                <amount>\(paymentRequest.transAmount)</amount>
                <version>2</version>
                <language>\(paymentRequest.language)</language>
                <ref>\(paymentRequest.transRef)</ref>
                <firstref>\(paymentRequest.transFirstRef)</firstref>
            </tran>
            <billing>
                <email>\(paymentRequest.billingEmail)</email>
                <name>
                    <first>\(paymentRequest.billingFName)</first>
                    <last>\(paymentRequest.billingLName)</last>
                    <title>\(paymentRequest.billingTitle)</title>
                </name>
                <address>
                    <city>\(paymentRequest.city)</city>
                    <country>\(paymentRequest.country)</country>
                    <region>\(paymentRequest.region)</region>
                    <line1>\(paymentRequest.address)</line1>
                </address>
            </billing>
        </mobile>
        """
        return xmlString
    }
   

}

extension TelrController : WKNavigationDelegate, WKUIDelegate, UIScrollViewDelegate{
    
     public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        actInd?.startAnimating()
        
        actInd?.isHidden = false
        
        decisionHandler(.allow)

     }

     public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
         
        actInd?.startAnimating()
              
        actInd?.isHidden = false

     }

     public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
         
        actInd?.stopAnimating()
        
        actInd?.isHidden = true
        
        DispatchQueue.main.async {
            self.delegate?.didPaymentFail(messge: "Network error!")
               
            self.dismiss(animated: true, completion: nil)
               
            let _ = self.navigationController?.popViewController(animated: true)
        }
        
    }

    func webViewDidStartLoad(_ : WKWebView) {
         
        actInd?.startAnimating()
         
        actInd?.isHidden = false
     
    }

    func webViewDidFinishLoad(_ : WKWebView){
         
        actInd?.stopAnimating()
        
        actInd?.isHidden = true
       
    }
       
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
          
        actInd?.stopAnimating()
           
        actInd?.isHidden = true
          
          
        if (webView.url?.path.contains("webview_close.html"))!{
            
               self.checkStatus(key: self.paymentRequest.key, store: self.paymentRequest.store, complete: self._code!)
               {
                   done in
                   let when = DispatchTime.now() + 0  // No waiting time
                   DispatchQueue.main.asyncAfter(deadline: when) {
                    let telrResponseModel = TelrResponseModel()
                    
                    if(done){
                           
                        telrResponseModel.message = "Your transaction is successful \(String(describing: self._trace))"
                        telrResponseModel.code = self._code
                                     
                        telrResponseModel.status = self._status
                                      
                        telrResponseModel.ca_valid = self._ca_valid
                                     
                        telrResponseModel.avs = self._avs
                                     
                        telrResponseModel.cardCode = self._cardCode
                                     
                        telrResponseModel.cardLast4 = self._cardLast4
                                    
                        telrResponseModel.cvv = self._cvv
                                     
                        telrResponseModel.tranRef = self._tranRef
                                     
                        telrResponseModel.trace = self._trace
                                     
                        telrResponseModel.cardFirst6 = self._cardFirst6
                                    
                        self.delegate?.didPaymentSuccess(response: telrResponseModel)
                                                  
                        self.dismiss(animated: true, completion: nil)
                                                  
                        let _ = self.navigationController?.popViewController(animated: true)
                       
                    }else{
                          
                        DispatchQueue.main.async {
                            self.delegate?.didPaymentFail(messge: "Network error!")
                               
                            self.dismiss(animated: true, completion: nil)
                               
                            let _ = self.navigationController?.popViewController(animated: true)
                        }
                      
                    }
                       
           
    
                }
               
            }
           
        }
    }
   
}
//
//extension String{
//    // remove amp; from string
//func removeAMPSemicolon() -> String{
//    return replacingOccurrences(of: "amp;", with: "")
//}
//
//// replace "&" with "And" from string
//func replaceAnd() -> String{
//    return replacingOccurrences(of: "&", with: "And")
//}
//
//// replace "\n" with "" from string
//func removeNewLine() -> String{
//    return replacingOccurrences(of: "\n", with: "")
//}
//
//func replaceAposWithApos() -> String{
//    return replacingOccurrences(of: "Andapos;", with: "'")
//}
//}
//
//class ParseXMLData: NSObject, XMLParserDelegate {
//
//var parser: XMLParser
//var elementArr = [String]()
//var arrayElementArr = [String]()
//var str = "{"
//
//init(xml: String) {
//    parser = XMLParser(data: xml.replaceAnd().replaceAposWithApos().data(using: String.Encoding.utf8)!)
//    super.init()
//    parser.delegate = self
//}
//
//func parseXML() -> String {
//    parser.parse()
//
//    // Do all below steps serially otherwise it may lead to wrong result
//    for i in self.elementArr{
//        if str.contains("\(i)@},\"\(i)\":"){
//            if !self.arrayElementArr.contains(i){
//                self.arrayElementArr.append(i)
//            }
//        }
//        str = str.replacingOccurrences(of: "\(i)@},\"\(i)\":", with: "},") //"\(element)@},\"\(element)\":"
//    }
//
//    for i in self.arrayElementArr{
//        str = str.replacingOccurrences(of: "\"\(i)\":", with: "\"\(i)\":[") //"\"\(arrayElement)\":}"
//    }
//
//    for i in self.arrayElementArr{
//        str = str.replacingOccurrences(of: "\(i)@}", with: "\(i)@}]") //"\(arrayElement)@}"
//    }
//
//    for i in self.elementArr{
//        str = str.replacingOccurrences(of: "\(i)@", with: "") //"\(element)@"
//    }
//
//    // For most complex xml (You can ommit this step for simple xml data)
//    self.str = self.str.removeNewLine()
//    self.str = self.str.replacingOccurrences(of: ":[\\s]?\"[\\s]+?\"#", with: ":{", options: .regularExpression, range: nil)
//
//    return self.str.replacingOccurrences(of: "\\", with: "").appending("}")
//}
//
//// MARK: XML Parser Delegate
//func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
//
//    //print("\n Start elementName: ",elementName)
//
//    if !self.elementArr.contains(elementName){
//        self.elementArr.append(elementName)
//    }
//
//    if self.str.last == "\""{
//        self.str = "\(self.str),"
//    }
//
//    if self.str.last == "}"{
//        self.str = "\(self.str),"
//    }
//
//    self.str = "\(self.str)\"\(elementName)\":{"
//
//    var attributeCount = attributeDict.count
//    for (k,v) in attributeDict{
//        //print("key: ",k,"value: ",v)
//        attributeCount = attributeCount - 1
//        let comma = attributeCount > 0 ? "," : ""
//        self.str = "\(self.str)\"_\(k)\":\"\(v)\"\(comma)" // add _ for key to differentiate with attribute key type
//    }
//}
//
//func parser(_ parser: XMLParser, foundCharacters string: String) {
//    if self.str.last == "{"{
//        self.str.removeLast()
//        self.str = "\(self.str)\"\(string)\"#" // insert pattern # to detect found characters added
//    }
//}
//
//func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
//
//    //print("\n End elementName \n",elementName)
//    if self.str.last == "#"{ // Detect pattern #
//        self.str.removeLast()
//    }else{
//        self.str = "\(self.str)\(elementName)@}"
//    }
//}
//}










//
//
////
////  TelrController.swift
////  TelrSDKDemo
////
////  Created by Kondya on 09/09/20.
////  Copyright © 2020 Fortune4. All rights reserved.
////
//
//import UIKit
//
//import SwiftyXMLParser
//
//import WebKit
//
//public protocol TelrControllerDelegate {
//
//    func didPaymentCancel()
//
//    func didPaymentSuccess(response:TelrResponseModel)
//
//    func didPaymentFail(messge:String)
//}
//
//public class TelrController: UIViewController, XMLParserDelegate {
//
//    @objc var webView : WKWebView = WKWebView()
//
//    var actInd: UIActivityIndicatorView?
//
//    var utility:Utility = Utility()
//
//    public var delegate : TelrControllerDelegate?
//
//    private var _paymentRequest:PaymentRequest?
//
//    private var _code:String?
//
//    private var _status:String?
//
//    private var _avs:String?
//
//    private var _ca_valid:String?
//
//    private var _cardCode:String?
//
//    private var _cardLast4:String?
//
//    private var _cvv:String?
//
//    private var _tranRef:String?
//
//    private var _transFirstRef:String?
//
//    private var _trace:String?
//
//    private var _cardFirst6:String?
//
//    public var paymentRequest:PaymentRequest{
//        get{
//            return _paymentRequest!
//           }
//        set{
//            _paymentRequest = newValue
//            _paymentRequest?.deviceType = "iPhone"
//            _paymentRequest?.deviceId = UIDevice.current.identifierForVendor!.uuidString
//        }
//    }
//
//    public var customBackButton : UIButton?
//
//    public override func viewDidLoad() {
//        super.viewDidLoad()
//
//        self.addBackButton()
//
//        DispatchQueue.main.async {
//
//            self.navigationController?.presentationController?.presentedView?.gestureRecognizers?[0].isEnabled = false
//
//            self.createWebView()
//
//        }
//
//        self.loadPaymentPage()
//
//    }
//
//    func addBackButton() {
//
//        if let customBackButton = self.customBackButton {
//
//            customBackButton.addTarget(self, action: #selector(self.backAction(_:)), for: .touchUpInside)
//
//            self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: customBackButton)
//
//        }else{
//
//            let backButton = UIButton(type: .custom)
//
//            backButton.setTitle("Back", for: .normal)
//
//            backButton.setTitleColor(backButton.tintColor, for: .normal)
//
//            backButton.addTarget(self, action: #selector(self.backAction(_:)), for: .touchUpInside)
//
//            self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: backButton)
//        }
//
//    }
//    @objc func backAction(_ sender: UIButton) {
//
//        self.delegate?.didPaymentCancel()
//
//        self.dismiss(animated: true, completion: nil)
//
//        let _ = self.navigationController?.popViewController(animated: true)
//    }
//    @objc func createWebView() {
//
//
//        let configuration = WKWebViewConfiguration()
//
//        let viewBack = UIView()
//
//        viewBack.backgroundColor = .white
//
//        viewBack.frame = CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.height)
//
//        webView = WKWebView(frame: CGRect.zero, configuration: configuration)
//
//        webView.frame = CGRect(x: 0, y: 20, width: viewBack.bounds.width, height: viewBack.bounds.height+20)
//
//        webView.navigationDelegate = self
//
//        webView.uiDelegate = self
//
//        webView.navigationDelegate = self
//
//        webView.backgroundColor = .white
//
//        webView.scrollView.delegate = self
//
//        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
//
//        webView.scrollView.alwaysBounceHorizontal = false
//
//        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
//
//        webView.scrollView.alwaysBounceVertical = false
//
//        webView.scrollView.isDirectionalLockEnabled = true
//
//        webView.backgroundColor = UIColor.white
//
//        webView.isMultipleTouchEnabled = false
//
//        webView.translatesAutoresizingMaskIntoConstraints = false
//
//        viewBack.addSubview(webView)
//
//        self.view.addSubview(viewBack)
//
//        self.showActivityIndicatory(uiView: self.webView)
//
//    }
//
//    func showActivityIndicatory(uiView: UIView) {
//
//        actInd = UIActivityIndicatorView()
//
//        actInd?.frame = CGRect(x: 0.0, y: -20, width: 40.0, height: 40.0);
//
//        actInd?.center = uiView.center
//
//        actInd?.hidesWhenStopped = true
//
//        actInd?.style = UIActivityIndicatorView.Style.medium
//
//        actInd?.color = .black
//
//        uiView.addSubview(actInd!)
//
//        actInd?.startAnimating()
//    }
//
//
//    public func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
//
//        print(elementName + "1")
//
//
//    }
//
//    // 2
//    public func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
//
//        print(elementName + "2")
//
//
//    }
//
//    // 3
//    public func parser(_ parser: XMLParser, foundCharacters string: String) {
//        let data = string.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
//
//        if (!data.isEmpty) {
//            print(data + "+++++")
//        }
//    }
//
//    @objc func loadPaymentPage(){
//
//        if(!self.utility.isJailbroken()){
//
//            let xml:String = self.initiatePaymentGateway(paymentRequest:self.paymentRequest)
//            let data = xml.data(using: .utf8)
//            print("\(xml)")
//            let url = URL(string:"https://secure.telr.com/gateway/mobile.xml")
//
//            if let newurl = url{
//
//                var request = URLRequest(url: newurl)
//
//                request.httpMethod = "post"
//
//                request.httpBody = data
//
//
//
//                URLSession.shared.dataTask(with: request, completionHandler: { data, response, error -> Void in
//
//                    if let data = data{
//
//
//                        let parser = XMLParser(data: data)
//                        parser.delegate = self
//                        parser.parse()
//
//
//
//                        let xmlresponse = XML.parse(data)
//
//                        if let message = xmlresponse["mobile","auth","message"].text{
//                            print(message)
//                            DispatchQueue.main.async {
//                                self.delegate?.didPaymentFail(messge: message)
//
//                                self.dismiss(animated: true, completion: nil)
//
//                                let _ = self.navigationController?.popViewController(animated: true)
//                            }
//
//                        }else{
//
//                            let start = xmlresponse["mobile","webview","start"]
//
//                            let code = xmlresponse["mobile","webview","code"]
//
//                            self._code = code.text!
//
//                            let newurl = URL(string:start.text!)
//
//                            let newrequest = URLRequest(url: newurl!)
//
//                            DispatchQueue.main.async {
//
//                                self.webView.load(newrequest)
//
//                            }
//
//                        }
//
//                    }
//
//                }).resume()
//
//            }
//           }else{
//            DispatchQueue.main.async {
//                self.delegate?.didPaymentFail(messge: "Your device has a security issue, you cannot use the pymentgateway.")
//
//                self.dismiss(animated: true, completion: nil)
//
//                let _ = self.navigationController?.popViewController(animated: true)
//            }
//
//        }
//
//    }
//
//    private func initiateStatusRequest(key:String, store:String, complete:String) -> String{
//        let xmlString =  """
//         <?xml version=\"1.0\"?>
//         <mobile>
//             <store>\(store)</store>
//             <key>\(key)</key>
//             <complete>\(complete)</complete>
//         </mobile>
//         """
//        return xmlString
//    }
//
//    private func checkStatus(key:String, store:String, complete:String, completionHandler:@escaping (Bool) -> ()) -> Void{
//
//        let completeURL = "https://secure.telr.com/gateway/mobile_complete.xml"
//
//        let xml:String = initiateStatusRequest(key:key, store:store, complete: complete)
//
//        print(xml)
//
//        let data = xml.data(using: .utf8)
//
//        let url = URL(string:completeURL)
//
//        if let newurl = url{
//
//            var request = URLRequest(url: newurl)
//
//            request.httpMethod = "post"
//
//            request.httpBody = data
//
//            URLSession.shared.dataTask(with: request, completionHandler: { data, response, error -> Void in
//
//                    if let data = data{
//
//                        let str = String(decoding: data, as: UTF8.self)
//
//                        let xmlresponse = XML.parse(data)
//
//                        print("=======\(str)=======")
//
//
//                        let statusMessage = xmlresponse["mobile","auth","message"]
//
//
//                        self._code = xmlresponse["mobile","auth","code"].text
//
//                        self._status = xmlresponse["mobile","auth","status"].text
//
//                        self._avs = xmlresponse["mobile","auth","avs"].text
//
//                        self._ca_valid = xmlresponse["mobile","auth","ca_valid"].text
//
//                        self._cardCode = xmlresponse["mobile","auth","cardcode"].text
//
//                        self._cardLast4 = xmlresponse["mobile","auth","cardlast4"].text
//
//                        self._cvv = xmlresponse["mobile","auth","cvv"].text!
//
//                        self._tranRef = xmlresponse["mobile","auth","tranref"].text
//
//                        self._transFirstRef = xmlresponse["mobile","auth","tranfirstref"].text
//
//                        self._trace = xmlresponse["mobile","trace"].text
//
//                        self._cardFirst6 = xmlresponse["mobile","auth","cardfirst6"].text
//
//                        if statusMessage.text == "Authorised"{
//
//                            completionHandler(true)
//
//                        }else{
//
//                            completionHandler(false)
//
//                        }
//
//                    }
//
//            }).resume()
//
//        }
//    }
//    private func initiatePaymentGateway(paymentRequest: PaymentRequest) -> String{
//        let xmlString = """
//        <?xml version=\"1.0\"?>
//        <mobile>
//            <store>\(paymentRequest.store)</store>
//            <key>\(paymentRequest.key)</key>
//            <device>
//                <type>\(paymentRequest.deviceType)</type>
//                <id>\(paymentRequest.deviceId)</id>
//            </device>
//            <app>
//                <id>\(paymentRequest.appId)</id>
//                <name>\(paymentRequest.appName)</name>
//                <user>\(paymentRequest.appUser)</user>
//                <version>\(paymentRequest.appVersion)</version>
//                <sdk>SDK ver 2.0</sdk>
//            </app>
//            <tran>
//                <test>\(paymentRequest.transTest)</test>
//                <type>\(paymentRequest.transType)</type>
//                <class>\(paymentRequest.transClass)</class>
//                <cartid>\(paymentRequest.transCartid)</cartid>
//                <description>\(paymentRequest.transDesc)</description>
//                <currency>\(paymentRequest.transCurrency)</currency>
//                <amount>\(paymentRequest.transAmount)</amount>
//                <version>2</version>
//                <language>\(paymentRequest.language)</language>
//                <ref>\(paymentRequest.transRef)</ref>
//                <firstref>\(paymentRequest.transFirstRef)</firstref>
//            </tran>
//            <billing>
//                <email>\(paymentRequest.billingEmail)</email>
//                <name>
//                    <first>\(paymentRequest.billingFName)</first>
//                    <last>\(paymentRequest.billingLName)</last>
//                    <title>\(paymentRequest.billingTitle)</title>
//                </name>
//                <address>
//                    <city>\(paymentRequest.city)</city>
//                    <country>\(paymentRequest.country)</country>
//                    <region>\(paymentRequest.region)</region>
//                    <line1>\(paymentRequest.address)</line1>
//                </address>
//            </billing>
//        </mobile>
//        """
//        return xmlString
//    }
//
//
//}
//
//extension TelrController : WKNavigationDelegate, WKUIDelegate, UIScrollViewDelegate{
//
//     public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
//
//
//        actInd?.startAnimating()
//        actInd?.isHidden = false
//
//        defer {
//
//            decisionHandler(.allow)
//
//        }
//
//        guard let url = navigationAction.request.url else { return }
//
//        print("decidePolicyFor - url: \(url)")
//
//     }
//
//     public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
//
//        actInd?.startAnimating()
//
//        actInd?.isHidden = false
//
//        print("didStartProvisionalNavigation - webView.url: \(String(describing: webView.url?.description))")
//     }
//
//     public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
//
//        actInd?.stopAnimating()
//
//        actInd?.isHidden = true
//
//        let nserror = error as NSError
//
//        if nserror.code != NSURLErrorCancelled {
//
//            webView.loadHTMLString("Page Not Found", baseURL: URL(string: "https://developer.apple.com/"))
//
//
//        }
//
//    }
//
//    func webViewDidStartLoad(_ : WKWebView) {
//
//        actInd?.startAnimating()
//
//        actInd?.isHidden = false
//
//    }
//
//    func webViewDidFinishLoad(_ : WKWebView){
//
//        actInd?.stopAnimating()
//
//        actInd?.isHidden = true
//
//    }
//
//    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
//
//        actInd?.stopAnimating()
//
//        actInd?.isHidden = true
//
//
//        if (webView.url?.path.contains("webview_close.html"))!{
//               self.checkStatus(key: self.paymentRequest.key, store: self.paymentRequest.store, complete: self._code!){
//                   done in
//                   let when = DispatchTime.now() + 0  // No waiting time
//                   DispatchQueue.main.asyncAfter(deadline: when) {
//                    let telrResponseModel = TelrResponseModel()
//
//                    if(done){
//
//                        telrResponseModel.message = "Your transaction is successful \(String(describing: self._trace))"
//                        telrResponseModel.code = self._code
//
//                        telrResponseModel.status = self._status
//
//                        telrResponseModel.ca_valid = self._ca_valid
//
//                        telrResponseModel.avs = self._avs
//
//                        telrResponseModel.cardCode = self._cardCode
//
//                        telrResponseModel.cardLast4 = self._cardLast4
//
//                        telrResponseModel.cvv = self._cvv
//
//                        telrResponseModel.tranRef = self._tranRef
//
//                        telrResponseModel.transFirstRef = self._transFirstRef
//
//                        telrResponseModel.trace = self._trace
//
//                        telrResponseModel.cardFirst6 = self._cardFirst6
//
//                        self.delegate?.didPaymentSuccess(response: telrResponseModel)
//
//                        self.dismiss(animated: true, completion: nil)
//
//                        let _ = self.navigationController?.popViewController(animated: true)
//
//                    }else{
//
//                        DispatchQueue.main.async {
//                            self.delegate?.didPaymentFail(messge: "Network error!")
//
//                            self.dismiss(animated: true, completion: nil)
//
//                            let _ = self.navigationController?.popViewController(animated: true)
//                        }
//
//                    }
//
//
//
//                }
//
//            }
//
//        }
//
//        let viewPortjs = "var myCustomViewport = 'width = " + String(describing: self.webView.frame.size.width) +
//               "px'; " +
//               "var viewportElement = document.querySelector('meta[name=viewport]');" +
//               "if (viewportElement) {viewportElement.content = myCustomViewport;} " +
//               "else {viewportElement = document.createElement('meta');" +
//               "viewportElement.name = 'viewport';" +
//               "viewportElement.content = myCustomViewport;" +
//           "document.getElementsByTagName('head')[0].appendChild(viewportElement);}"
//
//        evaluateJavascript(viewPortjs)
//
//    }
//    private func evaluateJavascript(_ javascript: String, sourceURL: String? = nil, completion: ((_ error: String?) -> Void)? = nil) {
//
//        var javascript = javascript
//
//        // Adding a sourceURL comment makes the javascript source visible when debugging the simulator via Safari in Mac OS
//
//        if let sourceURL = sourceURL {
//
//            javascript = "//# sourceURL=\(sourceURL).js\n" + javascript
//
//        }
//
//        webView.evaluateJavaScript(javascript) { _, error in
//
//            completion?(error?.localizedDescription)
//
//        }
//
//    }
//}
//


//
//
//
//
//if let data = data{
//    let xmlStr = String(decoding: data, as: UTF8.self)
//    print(xmlStr)
//    let parser = ParseXMLData(xml: xmlStr)
//    let jsonStr = parser.parseXML()
//    print(jsonStr)
//    let data = jsonStr.data(using: .utf8)!
//    do {
//        if let json = try JSONSerialization.jsonObject(with: data, options : .allowFragments) as? Dictionary<String,Any>
//        {
//            print(json)
//            if let mobile = json["mobile"] as? Dictionary<String,Any> {
//                if let webview = mobile["webview"] as? Dictionary<String,Any> {
//
//                    if let code = webview["code"] as? String {
//
//                        self._code = code
//
//                    }
//                    if let start = webview["start"] as? String {
//
//                        self._start = start
//                        guard let start = self._start else {return}
//                        guard let newurl = URL(string:start) else { return }
//                        let newrequest = URLRequest(url: newurl)
//                        DispatchQueue.main.async {
//                            self.webView.load(newrequest)
//                        }
//                    }
//
//                }
//            }
//
//        }else{
//            print("bad json")
//
//        }
//    } catch let error as NSError {
//        print(error)
//
//    }
//
//
//}