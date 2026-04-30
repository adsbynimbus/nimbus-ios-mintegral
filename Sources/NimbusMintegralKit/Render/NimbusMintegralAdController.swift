//
//  NimbusMintegralAdController.swift
//  Nimbus
//  Created on 10/30/24
//  Copyright © 2024 Nimbus Advertising Solutions Inc. All rights reserved.
//

import UIKit
import NimbusKit
import MTGSDK
import MTGSDKBidding
import MTGSDKBanner
import MTGSDKNewInterstitial
import MTGSDKReward

/// Mintegral mute state must be set before the ad is loaded.
/// That is why the volume property has no didSet hooks and only
/// considers the state of the property in load() method.
final class NimbusMintegralAdController: AdController,
                                         @preconcurrency MTGBannerAdViewDelegate,
                                         @preconcurrency MTGBidNativeAdManagerDelegate,
                                         @preconcurrency MTGMediaViewDelegate,
                                         @preconcurrency MTGNewInterstitialBidAdDelegate,
                                         @preconcurrency MTGRewardAdLoadDelegate,
                                         @preconcurrency MTGRewardAdShowDelegate {
    
    // MARK: - Properties
    
    // MARK: - Mintegral ad types
    private var bannerAd: MTGBannerAdView?
    private var interstitialAdManager: MTGNewInterstitialBidAdManager?
    private var nativeAdManager: MTGBidNativeAdManager?
    
    override class func setup(
        response: NimbusResponse,
        container: UIView,
        adPresentingViewController: UIViewController?
    ) -> AdController {
        let adController = Self.init(
            response: response,
            isBlocking: false,
            isRewarded: false,
            container: container,
            adPresentingViewController: adPresentingViewController
        )
        
        return adController
    }
    
    override class func setupBlocking(
        response: NimbusResponse,
        isRewarded: Bool,
        adPresentingViewController: UIViewController
    ) -> AdController {
        let adController = Self.init(
            response: response,
            isBlocking: true,
            isRewarded: isRewarded,
            container: nil,
            adPresentingViewController: adPresentingViewController
        )
        
        return adController
    }
    
    @MainActor
    override func load() {
        guard let adUnitId = response.bid.ext?.omp?.buyerPlacementId else {
            sendNimbusError(.mintegral(reason: .invalidState, stage: .render, detail: "Ad unit id is missing"))
            return
        }
        
        switch adRenderType {
        case .banner:            
            bannerAd = MTGBannerAdView(
                bannerAdViewWithAdSize: response.bid.size,
                placementId: nil,
                unitId: adUnitId,
                rootViewController: adPresentingViewController
            )
            bannerAd?.delegate = self
            bannerAd?.viewController = adPresentingViewController
            bannerAd?.loadBannerAd(withBidToken: response.bid.adm)
        case .native:
            nativeAdManager = MTGBidNativeAdManager(
                placementId: nil,
                unitID: adUnitId,
                presenting: adPresentingViewController
            )
            nativeAdManager?.delegate = self
            nativeAdManager?.load(withBidToken: response.bid.adm)
            
        case .interstitial:
            interstitialAdManager = MTGNewInterstitialBidAdManager(
                placementId: "",
                unitId: adUnitId,
                delegate: self
            )
            interstitialAdManager?.playVideoMute = volume <= 0
            interstitialAdManager?.loadAd(withBidToken: response.bid.adm)
        case .rewarded:
            MTGBidRewardAdManager.sharedInstance().playVideoMute = volume <= 0
            MTGBidRewardAdManager.sharedInstance().loadVideo(
                withBidToken: response.bid.adm,
                placementId: nil,
                unitId: adUnitId,
                delegate: self
            )
        @unknown default:
            sendNimbusError(.mintegral(reason: .unsupported, stage: .render, detail: "adRenderType: \(adRenderType.rawValue)"))
        }
    }
    
    @MainActor
    func presentIfNeeded(campaign: MTGCampaign? = nil) {
        guard started, adState == .ready else { return }
        guard let adUnitId = response.bid.ext?.omp?.buyerPlacementId else {
            sendNimbusError(.mintegral(reason: .invalidState, stage: .render, detail: "Ad unit id is missing"))
            return
        }
        
        adState = .resumed
        
        if let bannerAd {
            adView.addSubview(bannerAd)
        } else if let nativeAdManager, let campaign {
            guard let nativeAdViewProvider = MintegralExtension.nativeAdViewProvider else {
                sendNimbusError(.mintegral(reason: .misconfiguration, stage: .render, detail: "MintegralExtension.nativeAdViewProvider must be set to render native ads"))
                return
            }
            
            let nativeView = nativeAdViewProvider(adView, campaign)
            nativeView.translatesAutoresizingMaskIntoConstraints = false
            nativeView.mediaView.delegate = self
            nativeView.mediaView.setMediaSourceWith(campaign, unitId: adUnitId)
            
            adView.addSubview(nativeView)
            
            NSLayoutConstraint.activate([
                nativeView.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
                nativeView.trailingAnchor.constraint(equalTo: adView.trailingAnchor),
                nativeView.topAnchor.constraint(equalTo: adView.topAnchor),
                nativeView.bottomAnchor.constraint(equalTo: adView.bottomAnchor)
            ])
            
            nativeAdManager.registerView(
                forInteraction: nativeView,
                withClickableViews: nativeView.clickableViews,
                with: campaign
            )
        } else if let interstitialAdManager, let adPresentingViewController {
            interstitialAdManager.show(from: adPresentingViewController)
        } else if case .rewarded = adRenderType, let adPresentingViewController {
            MTGBidRewardAdManager.sharedInstance().showVideo(
                withPlacementId: nil,
                unitId: adUnitId,
                userId: nil,
                delegate: self,
                viewController: adPresentingViewController
            )
        } else {
            sendNimbusError(.mintegral(reason: .invalidState, stage: .render, detail: "Ad \(adRenderType) is invalid and could not be presented."))
        }
    }
    
    override func onStart() {
        Task { @MainActor in
            presentIfNeeded()
        }
    }
    
    override func onDestroy() {
        bannerAd = nil
        interstitialAdManager = nil
    }
    
    // MARK: - Banner Delegate
    
    func adViewLoadSuccess(_ adView: MTGBannerAdView!) {
        Task { @MainActor in
            adState = .ready
            sendNimbusEvent(.loaded)
            presentIfNeeded()
        }
    }
    
    func adViewWillLogImpression(_ adView: MTGBannerAdView!) {
        Task { @MainActor in sendNimbusEvent(.impression) }
    }
    
    func adViewDidClicked(_ adView: MTGBannerAdView!) {
        Task { @MainActor in sendNimbusEvent(.clicked) }
    }
    
    func adViewClosed(_ adView: MTGBannerAdView!) {
        Task { @MainActor in destroy() }
    }
    
    func adViewLoadFailedWithError(_ error: (any Error)!, adView: MTGBannerAdView!) {
        Task { @MainActor in
            sendNimbusError(.mintegral(stage: .render, detail: error.localizedDescription))
        }
    }
    
    func adViewWillLeaveApplication(_ adView: MTGBannerAdView!) {}
    func adViewWillOpenFullScreen(_ adView: MTGBannerAdView!) {}
    func adViewCloseFullScreen(_ adView: MTGBannerAdView!) {}
    
    // MARK: - Native Delegate
    
    func nativeAdsLoaded(_ nativeAds: [Any]?, bidNativeManager: MTGBidNativeAdManager) {
        Task { @MainActor in
            guard let campaign = nativeAds?.first as? MTGCampaign else {
                sendNimbusError(.mintegral(
                    reason: .invalidState,
                    stage: .render,
                    detail: "MTGCampaign not found in native ad")
                )
                return
            }
            
            sendNimbusEvent(.loaded)
            
            adState = .ready
            presentIfNeeded(campaign: campaign)
        }
    }
    
    func nativeAdsFailedToLoadWithError(_ error: any Error, bidNativeManager: MTGBidNativeAdManager) {
        Task { @MainActor in
            sendNimbusError(.mintegral(stage: .render, detail: error.localizedDescription))
        }
    }
    
    func nativeAdImpression(with type: MTGAdSourceType, bidNativeManager: MTGBidNativeAdManager) {
        Task { @MainActor in sendNimbusEvent(.impression) }
    }
    
    func nativeAdDidClick(_ nativeAd: MTGCampaign, bidNativeManager: MTGBidNativeAdManager) {
        Task { @MainActor in sendNimbusEvent(.clicked) }
    }
    
    func nativeAdImpression(with type: MTGAdSourceType, mediaView: MTGMediaView) {
        Task { @MainActor in sendNimbusEvent(.impression) }
    }
    
    func nativeAdDidClick(_ nativeAd: MTGCampaign) {
        Task { @MainActor in sendNimbusEvent(.clicked) }
    }
    
    // MARK: - Interstitial Delegate
    
    func newInterstitialBidAdResourceLoadSuccess(_ adManager: MTGNewInterstitialBidAdManager) {
        Task { @MainActor in
            adState = .ready
            sendNimbusEvent(.loaded)
            presentIfNeeded()
        }
    }
    
    func newInterstitialBidAdShowSuccess(withBidToken bidToken: String, adManager: MTGNewInterstitialBidAdManager) {
        Task { @MainActor in sendNimbusEvent(.impression) }
    }
    
    func newInterstitialBidAdClicked(_ adManager: MTGNewInterstitialBidAdManager) {
        Task { @MainActor in sendNimbusEvent(.clicked) }
    }
    
    func newInterstitialBidAdLoadFail(_ error: any Error, adManager: MTGNewInterstitialBidAdManager) {
        Task { @MainActor in
            sendNimbusError(.mintegral(stage: .render, detail: error.localizedDescription))
        }
    }
    
    func newInterstitialBidAdShowFail(_ error: any Error, adManager: MTGNewInterstitialBidAdManager) {
        Task { @MainActor in
            sendNimbusError(.mintegral(stage: .render, detail: error.localizedDescription))
        }
    }
    
    func newInterstitialBidAdDismissed(withConverted converted: Bool, adManager: MTGNewInterstitialBidAdManager) {
        Task { @MainActor in destroy() }
    }
    
    func newInterstitialBidAdEndCardShowSuccess(_ adManager: MTGNewInterstitialBidAdManager) {
        Task { @MainActor in sendNimbusEvent(.endCardImpression) }
    }
    
    // MARK: - Rewarded Delegate
    
    func onVideoAdLoadSuccess(_ placementId: String?, unitId: String?) {
        Task { @MainActor in
            adState = .ready
            sendNimbusEvent(.loaded)
            presentIfNeeded()
        }
    }
    
    func onVideoAdShowSuccess(_ placementId: String?, unitId: String?) {
        Task { @MainActor in sendNimbusEvent(.impression) }
    }
    
    func onVideoAdClicked(_ placementId: String?, unitId: String?) {
        Task { @MainActor in sendNimbusEvent(.clicked) }
    }
    
    func onVideoAdLoadFailed(_ placementId: String?, unitId: String?, error: any Error) {
        Task { @MainActor in
            sendNimbusError(.mintegral(stage: .render, detail: error.localizedDescription))
        }
    }
    
    func onVideoAdShowFailed(_ placementId: String?, unitId: String?, withError error: any Error) {
        Task { @MainActor in
            sendNimbusError(.mintegral(stage: .render, detail: error.localizedDescription))
        }
    }
    
    func onVideoEndCardShowSuccess(_ placementId: String?, unitId: String?) {
        Task { @MainActor in sendNimbusEvent(.endCardImpression) }
    }
    
    func onVideoAdDismissed(
        _ placementId: String?,
        unitId: String?,
        withConverted converted: Bool,
        withRewardInfo rewardInfo: MTGRewardAdInfo?
    ) {
        Task { @MainActor in
            sendNimbusEvent(converted ? .rewardEarned : .skipped)
            destroy()
        }
    }
}

// Internal: Do NOT implement delegate conformance as separate extensions as the methods won't not be found in runtime when built as a static library
