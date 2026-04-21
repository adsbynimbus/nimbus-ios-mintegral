//
//  MintegralRequestBridge.swift
//  Nimbus
//  Created on 3/7/25
//  Copyright © 2025 Nimbus Advertising Solutions Inc. All rights reserved.
//

import MTGSDK
import MTGSDKBidding

protocol MintegralRequestBridgeType: Sendable {
    @MainActor var tokenData: [String: String] { get }
}

final class MintegralRequestBridge: MintegralRequestBridgeType {
    public init() {}
    
    // Mintegral singleton should only be accessed from the main thread as their documentation recommends.
    @inlinable
    @MainActor
    public static func set(coppa: Bool) {
        MTGSDK.sharedInstance().coppa = coppa ? .yes : .no
    }
    
    // Mintegral singleton should only be accessed from the main thread as their documentation recommends.
    @MainActor public var tokenData: [String: String] {
        [
            "buyeruid": MTGBiddingSDK.buyerUID(),
            "sdkv": MTGSDK.sdkVersion()
        ]
    }
}
