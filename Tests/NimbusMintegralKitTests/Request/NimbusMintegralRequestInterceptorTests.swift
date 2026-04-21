//
//  NimbusMintegralRequestInterceptorTests.swift
//  Nimbus
//  Created on 11/12/24
//  Copyright © 2024 Nimbus Advertising Solutions Inc. All rights reserved.
//

import XCTest
@testable import NimbusMintegralKit
@testable import NimbusKit
import MTGSDK
import Testing

@Suite("Mintegral request interceptor tests")
struct NimbusMintegralRequestInterceptorTests {
    
    let bridge: MockRequestBridge
    let interceptor: NimbusMintegralRequestInterceptor
    
    init() {
        self.bridge = MockRequestBridge([
            "buyeruid": "abcd1234",
            "sdkv": "7.8.0"
        ])
        
        self.interceptor = NimbusMintegralRequestInterceptor(bridge: bridge)
    }
    
    @Test func mintegralTokenDataIsReturned() async throws {
        let info = try await NimbusRequest(from: Nimbus.bannerAd(position: "test", size: .banner).adRequest!.request)
        let deltas = try await interceptor.modifyRequest(request: info)
        
        let expectedValue: [String: String] = [
            "sdkv": "7.8.0",
            "buyeruid": "abcd1234"
        ]
        
        #expect(deltas.count == 1)
        #expect(deltas[0].target == .user)
        #expect(deltas[0].key == "mintegral_sdk")
        #expect(deltas[0].value as? [String: String] == expectedValue)
    }
    
    @Test
    @MainActor
    func mintegralTokenDataGetsInsertedIntoRequest() async throws {
        let ad = try Nimbus.rewardedAd(position: "position")
        ad.adRequest!.request.interceptors = [interceptor]
        
        try await ad.adRequest!.request.modifyRequestWithExtras(
            configuration: Nimbus.configuration,
            vendorId: "",
            appVersion: "1.0.0"
        )
        
        let tokenData = ad.adRequest!.request.user?.ext?.extras["mintegral_sdk"] as? [String: String]
        #expect(tokenData?["sdkv"] == "7.8.0")
        #expect(tokenData?["buyeruid"] == "abcd1234")
    }
    
    @MainActor
    private func createNimbusAd(network: String) -> NimbusResponse {
        NimbusResponse(id: "", bid: .init(mtype: .static, adm: "", price: 0, ext: .init(omp: .init(buyer: network, buyerPlacementId: nil))))
    }
}

class MockRequestBridge: MintegralRequestBridgeType, @unchecked Sendable {
    let onTokenData: [String: String]
    var coppa: Bool? = nil
    
    init(_ onTokenData: [String: String]) {
        self.onTokenData = onTokenData
    }
    
    // override to avoid interacting with Mintegral SDK as it crashes in test environment
    func set(coppa: Bool?) {
        self.coppa = coppa
    }
    
    var tokenData: [String : String] { onTokenData }
}
