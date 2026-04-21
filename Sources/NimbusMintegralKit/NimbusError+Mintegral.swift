//
//  NimbusError+Mintegral.swift
//  NimbusMintegralKit
//
//  Created on 2/23/26.
//  Copyright © 2026 Nimbus Advertising Solutions Inc. All rights reserved.
//

import NimbusKit

extension NimbusError.Domain {
    static let mintegral = Self(rawValue: "mintegral")
}

extension NimbusError {
    static func mintegral(reason: Reason = .failure, stage: Stage, detail: String? = nil) -> NimbusError {
        NimbusError(reason: reason, domain: .mintegral, stage: stage, detail: detail)
    }
}
