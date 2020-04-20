import Flutter
import UIKit
import Braintree
import BraintreeDropIn

public class SwiftFlutterBraintreePlugin: NSObject, FlutterPlugin, BTViewControllerPresentingDelegate, BTAppSwitchDelegate {
    
    
    
    var isHandlingResult: Bool = false
    
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_braintree.drop_in", binaryMessenger: registrar.messenger())
        
        let instance = SwiftFlutterBraintreePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "start" {
            guard !isHandlingResult else { result(FlutterError(code: "drop_in_already_running", message: "Cannot launch another Drop-in activity while one is already running.", details: nil)); return }
            
            isHandlingResult = true
            
            let dropInRequest = BTDropInRequest()
            
            if let amount = string(for: "amount", in: call) {
                dropInRequest.threeDSecureRequest?.amount = NSDecimalNumber(string: amount)
            }
            
            if let requestThreeDSecureVerification = bool(for: "requestThreeDSecureVerification", in: call) {
                dropInRequest.threeDSecureVerification = requestThreeDSecureVerification
            }
            
            if let vaultManagerEnabled = bool(for: "vaultManagerEnabled", in: call) {
                dropInRequest.vaultManager = vaultManagerEnabled
            }
            
            let clientToken = string(for: "clientToken", in: call)
            let tokenizationKey = string(for: "tokenizationKey", in: call)
            
            guard let authorization = clientToken ?? tokenizationKey else {
                result(FlutterError(code: "braintree_error", message: "Authorization not specified (no clientToken or tokenizationKey)", details: nil))
                isHandlingResult = false
                return
            }
            
            let dropInController = BTDropInController(authorization: authorization, request: dropInRequest) { (controller, braintreeResult, error) in
                controller.dismiss(animated: true, completion: nil)
                
                self.handle(braintreeResult: braintreeResult, error: error, flutterResult: result)
                self.isHandlingResult = false
            }
            
            guard let existingDropInController = dropInController else {
                result(FlutterError(code: "braintree_error", message: "BTDropInController not initialized (no API key or request specified?)", details: nil))
                isHandlingResult = false
                return
            }
            
            UIApplication.shared.keyWindow?.rootViewController?.present(existingDropInController, animated: true, completion: nil)
        }
        else if call.method == "requestPaypalNonce" {
            guard let request = map(for: "request", in: call),
                let amount = request["amount"] as? String,
                let authorization = string(for: "authorization", in: call),
                let braintreeClient = BTAPIClient(authorization: authorization)
                else {
                    return
            }
            let payPalDriver = BTPayPalDriver(apiClient: braintreeClient)
            payPalDriver.viewControllerPresentingDelegate = self
            payPalDriver.appSwitchDelegate = self
            let payPalRequest = BTPayPalRequest(amount: amount)
            payPalDriver.requestOneTimePayment(payPalRequest) { (tokenizedPayPalAccount, error) -> Void in
                
                print(#function)
                print("tokenizedPayPalAccount:\(tokenizedPayPalAccount),error:\(error)")
                
            }
            
        }
        else {
            result(FlutterMethodNotImplemented)
        }
    }
    
    
    private func handle(braintreeResult: BTDropInResult?, error: Error?, flutterResult: FlutterResult) {
        if error != nil {
            flutterResult(FlutterError(code: "braintree_error", message: error?.localizedDescription, details: nil))
        }
        else if braintreeResult?.isCancelled ?? false {
            flutterResult(nil)
        }
        else if let braintreeResult = braintreeResult {
            let nonceResultDict: [String: Any?] = ["nonce": braintreeResult.paymentMethod?.nonce,
                                                   "typeLabel": braintreeResult.paymentMethod?.type,
                                                   "description": braintreeResult.paymentMethod?.localizedDescription,
                                                   "isDefault": braintreeResult.paymentMethod?.isDefault]
            
            let resultDict: [String: Any?] = ["paymentMethodNonce": nonceResultDict]
            
            flutterResult(resultDict)
        }
    }
    
    
    private func string(for key: String, in call: FlutterMethodCall) -> String? {
        return (call.arguments as? [String: Any])?[key] as? String
    }
    
    
    private func bool(for key: String, in call: FlutterMethodCall) -> Bool? {
        return (call.arguments as? [String: Any])?[key] as? Bool
    }
    
    private func map(for key: String, in call: FlutterMethodCall) -> [String:Any]? {
        return (call.arguments as? [String: Any])?[key] as? [String:Any]
    }
    
    
    // Mark - BTViewControllerPresentingDelegate, BTAppSwitchDelegate
    public func paymentDriver(_ driver: Any, requestsPresentationOf viewController: UIViewController) {
        print(#function)
        
    }
    
    public func paymentDriver(_ driver: Any, requestsDismissalOf viewController: UIViewController) {
        print(#function)
    }
    
    public func appSwitcherWillPerformAppSwitch(_ appSwitcher: Any) {
        print(#function)
    }
    
    public func appSwitcher(_ appSwitcher: Any, didPerformSwitchTo target: BTAppSwitchTarget) {
        print(#function)
    }
    
    public func appSwitcherWillProcessPaymentInfo(_ appSwitcher: Any) {
        print(#function)
    }
    
}
