//
//  MintegralNativeAdViewType.swift
//  Nimbus
//  Created on 4/1/25
//  Copyright © 2025 Nimbus Advertising Solutions Inc. All rights reserved.
//

import UIKit
import MTGSDK

/**
 A `UIView` subclass capable of presenting Mintegral native ads.
 
 Pass an instance conforming to this protocol to `MintegralExtension.nativeAdViewProvider`
 to render a native Moloco ad.
 */
public protocol MintegralNativeAdViewType: UIView {
    /**
     Array of clickable views.
     
     It's recommended to implement this as a computed property, making
     it very easy to return the views you consider clickable, for instance:
     ```swift
     class MyNativeView: UIView, NimbusMintegralNativeAdViewType {
        let mediaView: MTGMediaView
        let installButton: UIButton
        
        var clickableViews: [mediaView, installButton]
     }
     ```
     */
    var clickableViews: [UIView] { get }
    
    /**
     Mintegral Media View.
     
     - Please DO NOT call `setMediaSourceWith(campaign, unitId: adUnitId)` as we call it upon retrieving the view.
     - Please DO NOT set delegate as we will override it in order to track impression (and possibly other) events.
     All events will be forwarded as a NimbusEvent that you can listen to.
     */
    var mediaView: MTGMediaView { get }
}
