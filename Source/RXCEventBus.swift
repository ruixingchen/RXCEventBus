//
//  RXCEventBus.swift
//  RXCEventBusExample
//
//  Created by ruixingchen on 2019/7/18.
//  Copyright © 2019 ruixingchen. All rights reserved.
//

import Foundation

///describe a receiver
public protocol REBEventBusReceiver: AnyObject {
    func eventBus(didReceive event:REBEventProtocol)
}

///describe an event
public protocol REBEventProtocol {
    var eventType:String {get}
    var eventSubtype:String? {get}
    ///we can pass an object to all receivers
    var object:Any? {get}
    var userInfo:[AnyHashable:Any]? {get}
}

///a simple implementation of REBEventProtocol
public struct REBEvent: REBEventProtocol {
    public var eventType: String
    public var eventSubtype: String?
    public var object: Any?
    public var userInfo: [AnyHashable : Any]?

    init(eventType:String, subtype:String?=nil) {
        self.eventType = eventType
        self.eventSubtype = subtype
    }

}

extension RXCEventBus {

    public enum ReceiveMode: Equatable {

        ///receive all events
        case all
        ///only receive events with specific eventType
        case eventType(String)
        ///only receive events with specific eventType and eventSubtype
        case subtype(String, String)

        ///custom receive mode, use a match closure to match the event
        ///the first string is for identifing the receiver, should be a unique string while uuid is recommended, if you want to remove a receiver with custom mode, should save the identifier and pass back it in the unregister function
        case custom(String, ((REBEventProtocol)->Bool)?)

        public static func == (lhs: RXCEventBus.ReceiveMode, rhs: RXCEventBus.ReceiveMode) -> Bool {
            switch (lhs, rhs) {
            case (.all, .all):
                return true
            case (.eventType(let l), .eventType(let r)):
                return l == r
            case (.subtype(let l1, let l2), .subtype(let r1, let r2)):
                return l1 == r1 && l2 == r2
            case (.custom(let id1, _), .custom(let id2, _)):
                return id1 == id2
            default:
                return false
            }
        }

    }

    fileprivate class ReceiverRegistration: Equatable {

        ///if the receiver pointer is equal and receive mode is equal, I think this two trgistrations are equal
        static func == (lhs: RXCEventBus.ReceiverRegistration, rhs: RXCEventBus.ReceiverRegistration) -> Bool {
            if lhs.receiver !== rhs.receiver {return false}
            if lhs.receiveMode != rhs.receiveMode {return false}
            return true
        }
        ///do not retain receiver
        weak var receiver:AnyObject?
        let receiveMode:ReceiveMode
        ///the queue the call in, default for current queue (call directly)
        var queue:DispatchQueue?
        ///the closure to call
        var closure:((REBEventProtocol)->Void)?
        ///the selector to call
        var selector:Selector?

        init(receiver: AnyObject, receiveMode:ReceiveMode) {
            self.receiver = receiver
            self.receiveMode = receiveMode
        }

        func fireIfMatched(event:REBEventProtocol) {
            if self.match(event: event) {
                self.fire(event: event)
            }
        }

        func match(event:REBEventProtocol)->Bool {
            switch self.receiveMode {
            case .all:
                return true
            case .eventType(let type):
                return event.eventType == type
            case .subtype(let type, let subtype):
                return event.eventType == type && event.eventSubtype == subtype
            case .custom(_, let closure):
                assert(closure != nil, "Custom ReceiveMode Match Closure Should Not Be Nil")
                if let c = closure {
                    return c(event)
                }else {
                    return false
                }
            }
        }

        func fire(event: REBEventProtocol) {
            let fireClosure:()->Void = {
                if let closure = self.closure {
                    closure(event)
                }else if let s = self.selector, let r = self.receiver {
                    let _ = r.perform(s, with: event)
                }else if let r = self.receiver as? REBEventBusReceiver {
                    r.eventBus(didReceive: event)
                }
            }
            if let queue = self.queue {
                queue.async {
                    fireClosure()
                }
            }else {
                fireClosure()
            }
        }
    }

}

///A simple event bus, no need to remove observer when deinit
public final class RXCEventBus {

    public static let shared:RXCEventBus = RXCEventBus()

    fileprivate lazy var allReceiveModeReceivers:NSMutableArray = NSMutableArray()
    fileprivate lazy var eventTypeReceivers:NSMutableDictionary = NSMutableDictionary()
    fileprivate lazy var subTypeReceivers:NSMutableDictionary = NSMutableDictionary() //[String:[String:[ReceiverRegistration]]] = [:]
    fileprivate lazy var customReceivers:NSMutableArray = NSMutableArray()

    ///register a receiver with a closure
    @discardableResult
    public func register(receiver:AnyObject, receiveMode:ReceiveMode,queue:DispatchQueue?, allowDuplication:Bool=true, handleClosure: @escaping (REBEventProtocol)->Void)->AnyObject {
        let registration = ReceiverRegistration(receiver: receiver, receiveMode: receiveMode)
        registration.closure = handleClosure
        registration.queue = queue
        self._register(registration: registration, allowDuplication: allowDuplication)
        return registration
    }

    ///register a receiver with a selector
    @discardableResult
    public func register(receiver:AnyObject, receiveMode:ReceiveMode, queue:DispatchQueue?, allowDuplication:Bool=true, selector:Selector)->AnyObject {
        let registration = ReceiverRegistration(receiver: receiver, receiveMode: receiveMode)
        registration.selector = selector
        registration.queue = queue
        self._register(registration: registration, allowDuplication: allowDuplication)
        return registration
    }

    ///register a receiver when it is a REBEventBusReceiver, will call the didReceive function directly
    @discardableResult
    public func register(receiver:REBEventBusReceiver, receiveMode:ReceiveMode, queue:DispatchQueue?, allowDuplication:Bool=true)->AnyObject {
        let registration = ReceiverRegistration(receiver: receiver, receiveMode: receiveMode)
        registration.queue = queue
        self._register(registration: registration, allowDuplication: allowDuplication)
        return registration
    }

    ///unregister the receiver for all modes
    public func unregister(receiver:AnyObject) {
        self._unregister(all: receiver)
    }

    ///unregister the receiver for a specific mode
    public func unregister(receiver:AnyObject, receiveMode:ReceiveMode) {
        self._unregister(receiver: receiver, receiveMode: receiveMode)
    }

    fileprivate func _register(registration:ReceiverRegistration, allowDuplication:Bool) {

        let containsClosure:(Any)->Bool = {
            ($0 as! ReceiverRegistration) == registration
        }

        switch registration.receiveMode {
        case .all:
            objc_sync_enter(self.allReceiveModeReceivers)
            defer {objc_sync_exit(self.allReceiveModeReceivers)}

            if allowDuplication || !self.allReceiveModeReceivers.contains(where: containsClosure) {
                self.allReceiveModeReceivers.add(registration)
            }
        case .eventType(let type):
            objc_sync_enter(self.eventTypeReceivers)
            defer {objc_sync_exit(self.eventTypeReceivers)}

            var array:NSMutableArray! = self.eventTypeReceivers[type] as? NSMutableArray
            if array == nil {
                array = NSMutableArray()
                self.eventTypeReceivers[type] = array
            }
            if allowDuplication || !array.contains(where: containsClosure) {
                array.add(registration)
            }
        case .subtype(let type, let subtype):
            objc_sync_enter(self.subTypeReceivers)
            defer {objc_sync_exit(self.subTypeReceivers)}

            var dict_1:NSMutableDictionary! = self.subTypeReceivers[type] as? NSMutableDictionary
            if dict_1 == nil {
                dict_1 = NSMutableDictionary()
                self.subTypeReceivers[type] = dict_1
            }
            var array_2:NSMutableArray! = dict_1[subtype] as? NSMutableArray
            if array_2 == nil {
                array_2 = NSMutableArray()
                dict_1[subtype] = array_2
            }
            if allowDuplication || !array_2.contains(where: containsClosure) {
                array_2.add(registration)
            }
        case .custom(_, _):
            objc_sync_enter(self.customReceivers)
            defer {objc_sync_exit(self.customReceivers)}

            if allowDuplication || !self.customReceivers.contains(where: containsClosure) {
                self.customReceivers.add(registration)
            }
        }
    }

    ///unregister all receiver with pointer and receiveMode
    fileprivate func _unregister(receiver:AnyObject, receiveMode:ReceiveMode) {

        let predicate:NSPredicate = NSPredicate(block: { (object, _) -> Bool in
            guard let registration = object as? ReceiverRegistration else {return false}
            if registration.receiver == nil {return false}
            return !(registration.receiver === receiver && registration.receiveMode == receiveMode)
        })

        switch receiveMode {
        case .all:
            objc_sync_enter(self.allReceiveModeReceivers)
            defer {objc_sync_exit(self.allReceiveModeReceivers)}
            self.allReceiveModeReceivers.filter(using: predicate)
        case .eventType(let type):
            objc_sync_enter(self.eventTypeReceivers)
            defer {objc_sync_exit(self.eventTypeReceivers)}

            guard let array:NSMutableArray = self.eventTypeReceivers[type] as? NSMutableArray else {return}
            array.filter(using: predicate)
        case .subtype(let type, let subtype):
            objc_sync_enter(self.subTypeReceivers)
            defer {objc_sync_exit(self.subTypeReceivers)}

            guard let dict_1:NSMutableDictionary = self.subTypeReceivers[type] as? NSMutableDictionary else {return}
            guard let array_2:NSMutableArray = dict_1[subtype] as? NSMutableArray else {return}
            array_2.filter(using: predicate)
        case .custom(_, _):
            objc_sync_enter(self.customReceivers)
            defer {objc_sync_exit(self.customReceivers)}
            self.customReceivers.filter(using: predicate)
        }
    }

    ///unregister all receiver with the pointer
    fileprivate func _unregister(all receiver:AnyObject) {
        //the filter predicate
        let predicate:NSPredicate = NSPredicate(block: { (object, _) -> Bool in
            guard let r1 = (object as? ReceiverRegistration)?.receiver else {return false}
            return r1 !== receiver
        })
        if true {
            objc_sync_enter(self.allReceiveModeReceivers)
            defer {objc_sync_exit(self.allReceiveModeReceivers)}
            self.allReceiveModeReceivers.filter(using: predicate)
        }
        if true {
            objc_sync_enter(self.eventTypeReceivers)
            defer {objc_sync_exit(self.eventTypeReceivers)}

            for i in self.eventTypeReceivers {
                (i.value as! NSMutableArray).filter(using: predicate)
            }
        }
        if true {
            objc_sync_enter(self.subTypeReceivers)
            defer {objc_sync_exit(self.subTypeReceivers)}
            for i in self.subTypeReceivers {
                let dict = i.value as! NSMutableDictionary
                for j in dict {
                    (j.value as! NSMutableArray).filter(using: predicate)
                }
            }
        }
        if true {
            objc_sync_enter(self.customReceivers)
            defer {objc_sync_exit(self.customReceivers)}
            self.customReceivers.filter(using: predicate)
        }
    }

    //MARK: - POST

    ///post a event
    fileprivate func _post(event:REBEventProtocol) {
        if true {
            self.allReceiveModeReceivers.forEach({($0 as! ReceiverRegistration).fireIfMatched(event: event)})
        }
        if true {
            for i in self.eventTypeReceivers {
                let array = i.value as! NSMutableArray
                array.forEach({($0 as! ReceiverRegistration).fireIfMatched(event: event)})
            }
        }
        if true {
            for i in self.subTypeReceivers {
                let dict = i.value as! NSMutableDictionary
                for j in dict {
                    let array = j.value as! NSMutableArray
                    array.forEach({($0 as! ReceiverRegistration).fireIfMatched(event: event)})
                }
            }
        }
        if true {
            self.customReceivers.forEach({($0 as! ReceiverRegistration).fireIfMatched(event: event)})
        }
    }

    public func post(event:REBEventProtocol) {
        self._post(event: event)
    }

    public func post(eventType:String, subtype:String?=nil, object:Any?=nil, userInfo:[AnyHashable:Any]?=nil) {
        var event = REBEvent(eventType: eventType, subtype: subtype)
        event.object = object
        event.userInfo = userInfo
        self._post(event: event)
    }

}
