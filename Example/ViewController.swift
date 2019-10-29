//
//  ViewController.swift
//  Example
//
//  Created by ruixingchen on 10/29/19.
//  Copyright © 2019 ruixingchen. All rights reserved.
//

import UIKit

@discardableResult
func measureTime(identifier:String,quantity:Int, closure:()->Void)->TimeInterval {
    let start = Date().timeIntervalSince1970
    closure()
    let time = Date().timeIntervalSince1970 - start
    print("\(identifier)测量结束: \(String.init(format: "%.6f", time)), 单个操作时间:\(String.init(format: "%.6f", time/TimeInterval(quantity)*1000))")
    return time
}

struct LoginManager {

    static func login() {
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(1)) {
            if Bool.random() {
                RXCEventBus.default.post(eventType: EventType.Login.login, subtype: EventType.Login.Subtype.failed, object: nil, userInfo: ["reason": "Network Connection Failed"])
            }else {
                RXCEventBus.default.post(eventType: EventType.Login.login, subtype: EventType.Login.Subtype.success, object: nil, userInfo: ["userName": "User\(Int.random(in: 10000...100000))"])
            }
        }
    }

}

struct EventType {

    struct Login {

        static var login:String {return "login"}

        struct Subtype {
            static var success:String {return "success"}
            static var failed:String {return "failed"}
        }

    }

}

class ViewController: UIViewController, REBEventBusReceiver {

    @IBOutlet weak var stateLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        RXCEventBus.default.register(receiver: self, receiveMode: .subtype(EventType.Login.login, EventType.Login.Subtype.success), queue: DispatchQueue.main) {[weak self] (event) in

            self?.stateLabel.text = "Good Morning, \(event.userInfo?["userName"] ?? "WOW")"
            self?.view.isUserInteractionEnabled = true

        }

        RXCEventBus.default.register(receiver: self, receiveMode: .subtype(EventType.Login.login, EventType.Login.Subtype.failed), queue: DispatchQueue.main) {[weak self] (event) in

            self?.stateLabel.text = "Login Failed: \(event.userInfo?["reason"] ?? "WOW")"
            self?.view.isUserInteractionEnabled = true

        }

    }

    func eventBus(didReceive event: REBEventProtocol) {
        print(event.eventType)
    }

    @IBAction func didTapLoginButton(_ sender: Any) {
        self.view.isUserInteractionEnabled = false
        self.stateLabel.text = "Now Login...."
        LoginManager.login()
    }

    @objc func doSomething(sender:AnyObject?=nil) {
        //print("--")
        if let event = sender as? REBEventProtocol {
            print(event.eventType)
        }
    }

}

extension ViewController {

    func measureInsertAndCallPerformance() {
        let testNum:Int = 10000
        measureEventBus(num: testNum)
        measureArray(num: testNum)
        measureContiguousArray(num: testNum)
        measureMutableArray(num: testNum)
        measurePointerArray(num: testNum)
        measureHashTable(num: testNum)
        measureNotificationCenter(num: testNum)
    }

    func measureEventBus(num:Int) {
        var normalArray:[ViewController] = []
        measureTime(identifier: "Array Add Objects", quantity: num) {
            for _ in 0..<num {
                let vc = ViewController()
                normalArray.append(vc)
                RXCEventBus.default.register(receiver: vc, receiveMode: .custom(UUID().uuidString, {$0.eventType.contains("1")}), selector: #selector(doSomething(sender:)), queue: nil, allowDuplication: true)
            }
        }
        measureTime(identifier: "Array Call", quantity: num) {
            RXCEventBus.default.post(eventType: "111")
        }
    }

    func measureArray(num:Int) {
        var array = Array<ViewController>()
        var normalArray:[ViewController] = []
        measureTime(identifier: "Array Add Objects", quantity: num) {
            for _ in 0..<num {
                let vc = ViewController()
                normalArray.append(vc)
                array.append(vc)
            }
        }
        measureTime(identifier: "Array Call", quantity: num) {
            for i in array {
                i.doSomething()
            }
        }
    }

    func measureContiguousArray(num:Int) {
        var array = ContiguousArray<ViewController>()
        var normalArray:[ViewController] = []
        measureTime(identifier: "ContiguousArray Add Objects", quantity: num) {
            for _ in 0..<num {
                let vc = ViewController()
                normalArray.append(vc)
                array.append(vc)
            }
        }
        measureTime(identifier: "ContiguousArray Call", quantity: num) {
            for i in array {
                i.doSomething()
            }
        }
    }

    func measureMutableArray(num:Int) {
        let array = NSMutableArray()
        var normalArray:[ViewController] = []
        measureTime(identifier: "MutableArray Add Objects", quantity: num) {
            for _ in 0..<num {
                let vc = ViewController()
                normalArray.append(vc)
                array.add(vc)
            }
        }
        measureTime(identifier: "MutableArray Call", quantity: num) {
            for i in array {
                (i as! ViewController).doSomething()
            }
        }
    }

    func measurePointerArray(num:Int) {
        var normalArray:[ViewController] = []
        let pointerArray = NSPointerArray(options: .weakMemory)
        measureTime(identifier: "NSPointerArray Add Objects", quantity: num) {
            for _ in 0..<num {
                let vc = ViewController()
                normalArray.append(vc)
                let pointer = Unmanaged.passUnretained(vc as AnyObject).toOpaque()
                pointerArray.addPointer(pointer)
            }
        }
        measureTime(identifier: "NSPointerArray Call", quantity: num) {
            for i in pointerArray.allObjects {
                if let vc = i as? ViewController {
                    vc.doSomething()
                }
            }
        }
    }

    func measureHashTable(num:Int) {
        var normalArray:[ViewController] = []
        let table:NSHashTable<ViewController> = NSHashTable(options: .weakMemory)
        measureTime(identifier: "NSHashTable Add Objects", quantity: num) {
            for _ in 0..<num {
                let vc = ViewController()
                normalArray.append(vc)
                table.add(vc)
            }
        }
        measureTime(identifier: "NSHashTable Call", quantity: num) {
            for i in table.allObjects {
                i.doSomething()
            }
        }
    }

    func measureNotificationCenter(num:Int) {
        var normalArray:[ViewController] = []
        let center = NotificationCenter.default
        measureTime(identifier: "NotificationCenter Add Objects", quantity: num) {
            for _ in 0..<num {
                let vc = ViewController()
                normalArray.append(vc)
                center.addObserver(vc, selector: #selector(doSomething), name: NSNotification.Name.init("test"), object: nil)
            }
        }
        measureTime(identifier: "NotificationCenter Call", quantity: num) {
            center.post(name: NSNotification.Name.init("test"), object: nil)
        }
    }

}
