//
//  NimbusMintegralAdControllerTests.swift
//  NimbusMintegralKit
//  Created on 10/21/26
//  Copyright © 2026 Nimbus Advertising Solutions Inc. All rights reserved.
//

import Testing
@testable import NimbusMintegralKit
@testable import NimbusKit
import UIKit
import MTGSDK
import MTGSDKBanner
import MTGSDKNewInterstitial
import MTGSDKReward

private let unitId = "test-unit-id"
private let bidToken = "test-bid-token"
private let sourceType = MTGAdSourceType(rawValue: 1)! // MTGAD_SOURCE_API_OFFER

@Suite("Mintegral AdController tests")
@MainActor
struct NimbusMintegralAdControllerTests {

    // MARK: - Banner

    @Test func bannerAdEventsGetFired() throws {
        let (adController, delegate) = makeAdController(.banner)

        let banner = adController.buildBannerAd(adUnitId: unitId)
        #expect(adController.bannerAd === banner)
        #expect(adController.nativeAdManager == nil)
        #expect(adController.interstitialAdManager == nil)
        #expect(banner.viewController === presenter)

        let mtg = try #require(banner.delegate, "banner delegate not wired")
        #expect(mtg === adController)

        mtg.adViewLoadSuccess(banner)
        #expect(delegate.events == [.loaded])

        #expect(adController.adView.subviews.isEmpty)
        adController.start()
        #expect(adController.adView.subviews.first === banner)

        mtg.adViewWillLogImpression(banner)
        #expect(delegate.events == [.loaded, .impression])

        mtg.adViewDidClicked(banner)
        #expect(delegate.events == [.loaded, .impression, .clicked])
        #expect(delegate.lastError == nil)

        mtg.adViewClosed(banner)
        #expect(delegate.lastError == nil)
        #expect(delegate.events.last == .destroyed)
    }

    @Test func bannerAdGetsDestroyedOnError() throws {
        let (adController, delegate) = makeAdController(.banner)
        let banner = adController.buildBannerAd(adUnitId: unitId)
        let mtg = try #require(banner.delegate, "banner delegate not wired")

        mtg.adViewLoadFailedWithError(mintegralError, adView: banner)

        expectMintegralError(delegate)
        #expect(delegate.events.last == .destroyed)
    }

    // MARK: - Native

    @Test func nativeAdManagerEventsGetFired() throws {
        let (adController, delegate) = makeAdController(.native)

        let manager = adController.buildNativeAdManager(adUnitId: unitId)
        #expect(adController.nativeAdManager === manager)
        #expect(adController.bannerAd == nil)
        #expect(adController.interstitialAdManager == nil)

        let mtg = try #require(manager.delegate, "native manager delegate not wired")
        #expect(mtg === adController)

        // Swap in a manager that records registerView instead of touching the real SDK
        let mockManager = MockBidNativeAdManager(placementId: nil, unitID: unitId, presenting: presenter)
        adController.nativeAdManager = mockManager

        let nativeView = MockNativeAdView()
        MintegralExtension.nativeAdViewProvider = { _, _ in nativeView }
        defer { MintegralExtension.nativeAdViewProvider = nil }

        let campaign = MTGCampaign()

        adController.start()
        #expect(adController.adView.subviews.isEmpty)

        mtg.nativeAdsLoaded?([campaign], bidNativeManager: manager)
        #expect(delegate.events == [.loaded])
        #expect(delegate.lastError == nil)

        // Rendered and registered with Mintegral
        #expect(adController.adView.subviews.first === nativeView)
        #expect(mockManager.registeredView === nativeView)
        #expect(mockManager.registeredCampaign === campaign)
        #expect(mockManager.registeredClickableViews.count == nativeView.clickableViews.count)
        #expect(nativeView.mockMediaView.sourceCampaign === campaign)
        #expect(nativeView.mockMediaView.sourceUnitId == unitId)

        mtg.nativeAdImpression?(with: sourceType, bidNativeManager: manager)
        #expect(delegate.events == [.loaded, .impression])

        mtg.nativeAdDidClick?(campaign, bidNativeManager: manager)
        #expect(delegate.events == [.loaded, .impression, .clicked])
        #expect(delegate.lastError == nil)
    }

    @Test func nativeMediaViewEventsGetFired() throws {
        let (adController, delegate) = makeAdController(.native)

        let manager = adController.buildNativeAdManager(adUnitId: unitId)
        let mtg = try #require(manager.delegate, "native manager delegate not wired")
        adController.nativeAdManager = MockBidNativeAdManager(placementId: nil, unitID: unitId, presenting: presenter)

        let nativeView = MockNativeAdView()
        MintegralExtension.nativeAdViewProvider = { _, _ in nativeView }
        defer { MintegralExtension.nativeAdViewProvider = nil }

        let campaign = MTGCampaign()
        adController.start()
        mtg.nativeAdsLoaded?([campaign], bidNativeManager: manager)
        #expect(delegate.events == [.loaded])

        // The media view delegate is set by the adapter during render
        let media = try #require(nativeView.mediaView.delegate, "media view delegate not wired")
        #expect(media === adController)

        media.nativeAdImpression?(with: sourceType, mediaView: nativeView.mediaView)
        #expect(delegate.events == [.loaded, .impression])

        media.nativeAdDidClick?(campaign)
        #expect(delegate.events == [.loaded, .impression, .clicked])
        #expect(delegate.lastError == nil)
    }

    @Test func nativeAdGetsDestroyedOnError() throws {
        let (adController, delegate) = makeAdController(.native)
        let manager = adController.buildNativeAdManager(adUnitId: unitId)
        let mtg = try #require(manager.delegate, "native manager delegate not wired")

        mtg.nativeAdsFailedToLoadWithError?(mintegralError, bidNativeManager: manager)

        expectMintegralError(delegate)
        #expect(delegate.events.last == .destroyed)
    }

    @Test func nativeAdWithoutCampaignGetsDestroyed() throws {
        let (adController, delegate) = makeAdController(.native)
        let manager = adController.buildNativeAdManager(adUnitId: unitId)
        let mtg = try #require(manager.delegate, "native manager delegate not wired")

        mtg.nativeAdsLoaded?([], bidNativeManager: manager)

        #expect(delegate.lastError?.detail == "MTGCampaign not found in native ad")
        #expect(!delegate.events.contains(.loaded))
        #expect(delegate.events.last == .destroyed)
    }

    /// Mintegral may return the campaign before Nimbus calls start(); the adapter must keep it and render on start.
    @Test func nativeAdRendersWhenStartedAfterLoad() throws {
        let (adController, delegate) = makeAdController(.native)

        let manager = adController.buildNativeAdManager(adUnitId: unitId)
        let mtg = try #require(manager.delegate, "native manager delegate not wired")
        let mockManager = MockBidNativeAdManager(placementId: nil, unitID: unitId, presenting: presenter)
        adController.nativeAdManager = mockManager

        let nativeView = MockNativeAdView()
        MintegralExtension.nativeAdViewProvider = { _, _ in nativeView }
        defer { MintegralExtension.nativeAdViewProvider = nil }

        let campaign = MTGCampaign()
        mtg.nativeAdsLoaded?([campaign], bidNativeManager: manager)
        #expect(delegate.events == [.loaded])
        #expect(adController.adView.subviews.isEmpty)

        adController.start()

        #expect(delegate.lastError == nil)
        #expect(adController.adView.subviews.first === nativeView)
        #expect(mockManager.registeredCampaign === campaign)
        #expect(nativeView.mockMediaView.sourceCampaign === campaign)
    }

    // MARK: - Interstitial

    @Test func interstitialAdEventsGetFired() throws {
        let (adController, delegate) = makeAdController(.interstitial)

        let manager = adController.buildInterstitialAdManager(adUnitId: unitId)
        #expect(adController.interstitialAdManager === manager)
        #expect(adController.bannerAd == nil)
        #expect(adController.nativeAdManager == nil)

        let mtg = try #require(manager.delegate, "interstitial delegate not wired")
        #expect(mtg === adController)

        // Swap in a manager that records show(from:) instead of presenting for real
        let mockManager = MockInterstitialBidAdManager(placementId: "", unitId: unitId, delegate: nil)
        adController.interstitialAdManager = mockManager

        mtg.newInterstitialBidAdResourceLoadSuccess?(manager)
        #expect(delegate.events == [.loaded])
        #expect(mockManager.presentedFrom == nil)

        adController.start()
        #expect(mockManager.presentedFrom === presenter)

        mtg.newInterstitialBidAdShowSuccess?(withBidToken: bidToken, adManager: manager)
        #expect(delegate.events == [.loaded, .impression])

        mtg.newInterstitialBidAdClicked?(manager)
        #expect(delegate.events == [.loaded, .impression, .clicked])

        mtg.newInterstitialBidAdPlayCompleted?(manager)
        #expect(delegate.events == [.loaded, .impression, .clicked, .completed])

        mtg.newInterstitialBidAdEndCardShowSuccess?(manager)
        #expect(delegate.events == [.loaded, .impression, .clicked, .completed, .endCardImpression])
        #expect(delegate.lastError == nil)

        mtg.newInterstitialBidAdDismissed?(withConverted: true, adManager: manager)
        #expect(delegate.lastError == nil)
        #expect(!delegate.events.contains(.rewardEarned))
        #expect(delegate.events.last == .destroyed)
    }

    @Test func interstitialAdGetsDestroyedOnLoadError() throws {
        let (adController, delegate) = makeAdController(.interstitial)
        let manager = adController.buildInterstitialAdManager(adUnitId: unitId)
        let mtg = try #require(manager.delegate, "interstitial delegate not wired")

        mtg.newInterstitialBidAdLoadFail?(mintegralError, adManager: manager)

        expectMintegralError(delegate)
        #expect(delegate.events.last == .destroyed)
    }

    @Test func interstitialAdGetsDestroyedOnShowError() throws {
        let (adController, delegate) = makeAdController(.interstitial)
        let manager = adController.buildInterstitialAdManager(adUnitId: unitId)
        let mtg = try #require(manager.delegate, "interstitial delegate not wired")
        adController.interstitialAdManager = MockInterstitialBidAdManager(placementId: "", unitId: unitId, delegate: nil)

        mtg.newInterstitialBidAdResourceLoadSuccess?(manager)
        adController.start()
        mtg.newInterstitialBidAdShowFail?(mintegralError, adManager: manager)

        expectMintegralError(delegate)
        #expect(delegate.events.last == .destroyed)
    }

    // MARK: - Rewarded

    @Test func rewardedAdEventsGetFired() throws {
        let (adController, delegate) = makeAdController(.rewarded)

        let rewardManager = MockBidRewardAdManager()
        adController.rewardAdManager = rewardManager
        adController.load()

        #expect(adController.bannerAd == nil)
        #expect(adController.nativeAdManager == nil)
        #expect(adController.interstitialAdManager == nil)
        #expect(rewardManager.loadedBidToken == bidToken)
        #expect(rewardManager.loadedUnitId == unitId)

        let load = try #require(rewardManager.loadDelegate, "rewarded load delegate not wired")
        #expect(load === adController)

        load.onVideoAdLoadSuccess?(nil, unitId: unitId)
        #expect(delegate.events == [.loaded])
        #expect(rewardManager.showDelegate == nil)

        adController.start()
        #expect(rewardManager.presentedFrom === presenter)
        #expect(rewardManager.shownUnitId == unitId)

        let show = try #require(rewardManager.showDelegate, "rewarded show delegate not wired")
        #expect(show === adController)

        show.onVideoAdShowSuccess?(nil, unitId: unitId)
        #expect(delegate.events == [.loaded, .impression])

        show.onVideoAdClicked?(nil, unitId: unitId)
        #expect(delegate.events == [.loaded, .impression, .clicked])

        show.onVideoPlayCompleted?(nil, unitId: unitId)
        #expect(delegate.events == [.loaded, .impression, .clicked, .completed])

        show.onVideoEndCardShowSuccess?(nil, unitId: unitId)
        #expect(delegate.events == [.loaded, .impression, .clicked, .completed, .endCardImpression])
        #expect(delegate.lastError == nil)

        show.onVideoAdDismissed?(nil, unitId: unitId, withConverted: true, withRewardInfo: nil)
        #expect(delegate.lastError == nil)
        #expect(Array(delegate.events.suffix(2)) == [.rewardEarned, .destroyed])
    }

    @Test func rewardedAdSendsSkippedWhenNotConverted() throws {
        let (adController, delegate) = makeAdController(.rewarded)

        let rewardManager = MockBidRewardAdManager()
        adController.rewardAdManager = rewardManager
        adController.load()

        let load = try #require(rewardManager.loadDelegate, "rewarded load delegate not wired")
        load.onVideoAdLoadSuccess?(nil, unitId: unitId)
        adController.start()

        let show = try #require(rewardManager.showDelegate, "rewarded show delegate not wired")
        show.onVideoAdShowSuccess?(nil, unitId: unitId)
        show.onVideoAdDismissed?(nil, unitId: unitId, withConverted: false, withRewardInfo: nil)

        #expect(delegate.lastError == nil)
        #expect(!delegate.events.contains(.rewardEarned))
        #expect(Array(delegate.events.suffix(2)) == [.skipped, .destroyed])
    }

    @Test func rewardedAdGetsDestroyedOnLoadError() throws {
        let (adController, delegate) = makeAdController(.rewarded)

        let rewardManager = MockBidRewardAdManager()
        adController.rewardAdManager = rewardManager
        adController.load()

        let load = try #require(rewardManager.loadDelegate, "rewarded load delegate not wired")
        load.onVideoAdLoadFailed?(nil, unitId: unitId, error: mintegralError)

        expectMintegralError(delegate)
        #expect(delegate.events.last == .destroyed)
    }

    @Test func rewardedAdGetsDestroyedOnShowError() throws {
        let (adController, delegate) = makeAdController(.rewarded)

        let rewardManager = MockBidRewardAdManager()
        adController.rewardAdManager = rewardManager
        adController.load()

        let load = try #require(rewardManager.loadDelegate, "rewarded load delegate not wired")
        load.onVideoAdLoadSuccess?(nil, unitId: unitId)
        adController.start()

        let show = try #require(rewardManager.showDelegate, "rewarded show delegate not wired")
        show.onVideoAdShowFailed?(nil, unitId: unitId, withError: mintegralError)

        expectMintegralError(delegate)
        #expect(delegate.events.last == .destroyed)
    }

    // MARK: - Helpers

    /// Fresh per test: Swift Testing creates a new suite instance for every @Test.
    private let container = UIView()
    
    /// AdController holds adPresentingViewController weakly, so it must outlive the test body.
    private let presenter = UIViewController()
    
    private let mintegralError = NSError(
        domain: "com.mintegral",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Mintegral test error"]
    )

    enum Format { case banner, native, interstitial, rewarded }
    
    private func makeAdController(_ format: Format) -> (NimbusMintegralAdController, MockDelegate) {
        let response: NimbusResponse = switch format {
        case .banner, .interstitial:
            .init(id: "", bid: .init(mtype: .static, adm: bidToken, price: 0, ext: .init(omp: .init(buyer: "mintegral", buyerPlacementId: unitId))))
        case .native:
            .init(id: "", bid: .init(mtype: .native, adm: bidToken, price: 0, ext: .init(omp: .init(buyer: "mintegral", buyerPlacementId: unitId))))
        case .rewarded:
            .init(id: "", bid: .init(mtype: .video, adm: bidToken, price: 0, ext: .init(omp: .init(buyer: "mintegral", buyerPlacementId: unitId))))
        }
        
        let adController = NimbusMintegralAdController(
            response: response,
            isBlocking: format == .interstitial || format == .rewarded,
            isRewarded: format == .rewarded,
            container: container,
            adPresentingViewController: presenter
        )
        let delegate = MockDelegate()
        adController.delegate = delegate
        return (adController, delegate)
    }
    
    private func expectMintegralError(_ delegate: MockDelegate, sourceLocation: SourceLocation = #_sourceLocation) {
        let error = delegate.lastError
        #expect(error != nil, sourceLocation: sourceLocation)
        #expect(error!.domain == NimbusError.Domain(rawValue: "mintegral"), sourceLocation: sourceLocation)
        #expect(error!.detail == "Mintegral test error", sourceLocation: sourceLocation)
    }
}

// MARK: - Mocks

class MockDelegate: AdController.Delegate {
    var events: [AdEvent] = []
    var lastError: NimbusError?

    func didReceiveNimbusEvent(event: NimbusKit.AdEvent) {
        events.append(event)
    }

    func didReceiveNimbusError(error: NimbusKit.NimbusError) {
        lastError = error
    }
}

final class MockBidNativeAdManager: MTGBidNativeAdManager {
    var registeredView: UIView?
    var registeredClickableViews: [Any] = []
    var registeredCampaign: MTGCampaign?

    override func registerView(forInteraction view: UIView, withClickableViews clickableViews: [Any], with campaign: MTGCampaign) {
        registeredView = view
        registeredClickableViews = clickableViews
        registeredCampaign = campaign
    }
}

final class MockMediaView: MTGMediaView {
    var sourceCampaign: MTGCampaign?
    var sourceUnitId: String?

    override func setMediaSourceWith(_ campaign: MTGCampaign, unitId: String) {
        sourceCampaign = campaign
        sourceUnitId = unitId
    }
}

final class MockNativeAdView: UIView, MintegralNativeAdViewType {
    let mockMediaView = MockMediaView(frame: .zero)

    var mediaView: MTGMediaView { mockMediaView }
    var clickableViews: [UIView] { [mockMediaView] }
}

final class MockInterstitialBidAdManager: MTGNewInterstitialBidAdManager {
    weak var presentedFrom: UIViewController?

    override func show(from viewController: UIViewController) {
        presentedFrom = viewController
    }
}

final class MockBidRewardAdManager: MTGBidRewardAdManager {
    weak var loadDelegate: (any MTGRewardAdLoadDelegate)?
    weak var showDelegate: (any MTGRewardAdShowDelegate)?
    weak var presentedFrom: UIViewController?
    var loadedBidToken: String?
    var loadedUnitId: String?
    var shownUnitId: String?

    override func loadVideo(
        withBidToken bidToken: String,
        placementId: String?,
        unitId: String,
        delegate: (any MTGRewardAdLoadDelegate)?
    ) {
        loadedBidToken = bidToken
        loadedUnitId = unitId
        loadDelegate = delegate
    }

    override func showVideo(
        withPlacementId placementId: String?,
        unitId: String,
        userId: String?,
        delegate: (any MTGRewardAdShowDelegate)?,
        viewController: UIViewController
    ) {
        shownUnitId = unitId
        showDelegate = delegate
        presentedFrom = viewController
    }
}
