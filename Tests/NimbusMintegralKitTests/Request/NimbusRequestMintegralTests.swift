//
//  NimbusRequestMintegralTests.swift
//  Nimbus
//  Created on 11/12/24
//  Copyright © 2024 Nimbus Advertising Solutions Inc. All rights reserved.
//

@testable import NimbusMintegralKit
@testable import NimbusKit
import Testing

@Suite("Mintegral NimbusRequest extension") struct MintegralRequestExtensionTests {
    
    let interceptor = NimbusMintegralRequestInterceptor(
        bridge: MockRequestBridge([
            "buyeruid": "abcd1234",
            "sdkv": "7.8.0"
        ])
    )
    
    @Test("request gets modified")
    func requestGetsModified() async throws {
        let ad = try await Nimbus.bannerAd(position: "banner", size: .banner)
        let info = try await NimbusRequest(from: ad.adRequest!.request)
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

    @MainActor
    private func createNimbusAd(_ network: String) -> NimbusResponse {
        NimbusResponse(id: "", bid: .init(mtype: .static, adm: "", price: 0, ext: .init(omp: .init(buyer: network, buyerPlacementId: nil))))
    }
}
