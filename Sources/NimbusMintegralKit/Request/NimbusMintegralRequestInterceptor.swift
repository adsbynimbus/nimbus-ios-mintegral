//
//  NimbusMintegralRequestInterceptor.swift
//  Nimbus
//  Created on 10/30/24
//  Copyright © 2024 Nimbus Advertising Solutions Inc. All rights reserved.
//

import Foundation
import NimbusKit
import MTGSDK
import MTGSDKBidding

final class NimbusMintegralRequestInterceptor {
    private let bridge: MintegralRequestBridgeType
    
    init(bridge: MintegralRequestBridgeType = MintegralRequestBridge()) {
        self.bridge = bridge
    }
}

extension NimbusMintegralRequestInterceptor: NimbusRequest.Interceptor {
    func modifyRequest(request: NimbusRequest) async throws -> [NimbusRequest.Delta] {
        let data = await bridge.tokenData
        
        try Task.checkCancellation()
        
        return [.init(target: .user, key: "mintegral_sdk", value: data)]
    }
}
