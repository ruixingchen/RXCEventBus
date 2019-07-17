//
//  RXCEventBus.swift
//  RXCEventBusExample
//
//  Created by ruixingchen on 2019/7/18.
//  Copyright © 2019 ruixingchen. All rights reserved.
//

import Foundation
#if canImport(RXCWeakReferenceArray)
import RXCWeakReferenceArray
#endif

public protocol REBEventBusReceiver: AnyObject {
    func eventBus(bus:RXCEventBus, didReceive event:REBEventProtocol)
}

public protocol REBEventProtocol {
    var eventType:String {get}
    var eventSubtype:String? {get}
    var userInfo:[AnyHashable:Any]? {get}
}

public class REBEvent: REBEventProtocol {
    public var eventType: String = ""
    public var eventSubtype: String?
    public var userInfo: [AnyHashable : Any]?
}

public class RXCEventBus {

    public static let main:RXCEventBus = RXCEventBus()

    private let receivers:RXCWeakReferenceArray<REBEventBusReceiver> = RXCWeakReferenceArray(option: .weakMemory, compactCycle: 10)

    public func addReceiver(object:REBEventBusReceiver) {
        self.receivers.add(object)
    }

    public func removeReceiver(object:REBEventBusReceiver) {
        self.receivers.removeAll(where: {$0 as AnyObject === object as AnyObject})
    }

    public func post(event:REBEventProtocol) {
        for i in self.receivers {
            i.eventBus(bus: self, didReceive: event)
        }
    }

    public func post(event:REBEventProtocol, queue:DispatchQueue?) {
        if let q = queue {
            q.async {
                self.post(event: event)
            }
        }else {
            self.post(event: event)
        }
    }

    public func post(event:REBEventProtocol, operationQueue:OperationQueue?) {
        if let q = operationQueue {
            q.addOperation {
                self.post(event: event)
            }
        }else {
            self.post(event: event)
        }
    }

    public func postOnMain(event:REBEventProtocol) {
        self.post(event: event, queue: DispatchQueue.main)
    }

}
