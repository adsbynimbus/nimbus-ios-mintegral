//
//  MintegralExtension.swift
//  Nimbus
//  Created on 4/1/25
//  Copyright © 2025 Nimbus Advertising Solutions Inc. All rights reserved.
//

import NimbusKit
import MTGSDK
import UIKit

/// Nimbus extension for Mintegral.
///
/// Enables Mintegral rendering when included in `Nimbus.initialize(...)`.
/// Supports dynamic enable/disable at runtime.
///
/// ### Notes:
///   - Instantiate within the `Nimbus.initialize` block; the extension is installed and enabled automatically.
///   - Disable rendering with `MintegralExtension.disable()`.
///   - Re-enable rendering with `MintegralExtension.enable()`.
public struct MintegralExtension: NimbusRequestExtension, NimbusRenderExtension {
    @_documentation(visibility: internal)
    public var interceptor: any NimbusRequest.Interceptor
    
    @_documentation(visibility: internal)
    public var enabled = true
    
    @_documentation(visibility: internal)
    public var network: String { "mintegral" }
    
    @_documentation(visibility: internal)
    public var controllerType: AdController.Type { NimbusMintegralAdController.self }
    
    /// Creates a Mintegral extension.
    ///
    /// - Parameter appId: Mintegral App Id. If provided, Nimbus initializes the Mintegral SDK automatically.
    /// - Parameter appKey: Mintegral App Key. If provided, Nimbus initializes the Mintegral SDK automatically.
    ///
    /// ##### Usage
    /// ```swift
    /// Nimbus.initialize(publisher: "<publisher>", apiKey: "<apiKey>") {
    ///     MintegralExtension(appId: "<appId>", appKey: "<appKey>") // Enables Mintegral rendering
    /// }
    /// ```
    public init(appId: String? = nil, appKey: String? = nil) {
        interceptor = NimbusMintegralRequestInterceptor()
        
        guard let appId, let appKey else {
            Nimbus.Log.lifecycle.debug("Skipping Mintegral SDK initialization, appId or apiKey was not provided")
            return
        }
        
        MTGSDK.sharedInstance().setAppID(appId, apiKey: appKey)
        Nimbus.Log.lifecycle.debug("Mintegral SDK initalization completed")
    }
    
    @_documentation(visibility: internal)
    public func coppaDidChange(coppa: Bool) {
        MintegralRequestBridge.set(coppa: coppa)
    }
}

public extension MintegralExtension {
    /**
     The UIView returned from this method should have all of the data set from the native ad
     on children views such as the call to action, image data, title, privacy icon etc.
     The view returned from this method should not be attached to the container passed in as
     it will be attached at a later time during the rendering process.
     
     NOTE: DO NOT set MTGMediaView.delegate. Nimbus uses this delegate and forwards events as NimbusEvent. You may
     listen set AdController.delegate and listen to didReceiveNimbusEvent() and didReceiveNimbusError() instead.
     
     - Parameters:
       - container: The container the layout will be attached to
       - campaign: The Mintegral campaign with the relevant ad information
     
     - Returns: Your custom UIView. DO NOT attach the view to the hierarchy yourself.
     */
    @MainActor
    @preconcurrency
    static var nativeAdViewProvider: ((_ container: UIView, _ campaign: MTGCampaign) -> MintegralNativeAdViewType)?
}
