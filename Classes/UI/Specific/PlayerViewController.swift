//
//  PlayerViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 1/6/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit

class PlayerViewController: UIViewController {
    let coverArtView = CachedImageView()
    let titleLabel = UILabel()
    let artistLabel = UILabel()
    let playButton = UIButton(type: .custom)
    let spinner = UIActivityIndicatorView(activityIndicatorStyle: .gray)
    let prevButton = UIButton(type: .custom)
    let nextButton = UIButton(type: .custom)
    let elapsedLabel = UILabel()
    let remainingLabel = UILabel()
    let progressSlider = UISlider()
    var progressDisplayLink: CADisplayLink!
    
    let tapRecognizer = UITapGestureRecognizer()
    let swipeRecognizer = UISwipeGestureRecognizer()
    
    var coverArtViewSize: CGFloat {
        return UIDevice.current.orientation.isLandscape ? 150 : 320
    }
    
    var coverArtViewTopOffset: CGFloat {
        let height = (UIDevice.current.orientation.isLandscape ? portraitScreenSize.width : portraitScreenSize.height)
        return height * 0.1
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .lightGray
        
        coverArtView.isUserInteractionEnabled = true
        self.view.addSubview(coverArtView)
        coverArtView.snp.makeConstraints { make in
            make.width.equalTo(coverArtViewSize)
            make.height.equalTo(coverArtViewSize)
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(coverArtViewTopOffset)
        }
        
        progressSlider.minimumValue = 0.0
        progressSlider.maximumValue = 1.0
        progressSlider.isContinuous = false
        progressSlider.addTarget(self, action: #selector(progressSliderValueChanged), for: .valueChanged)
        progressSlider.addTarget(self, action: #selector(progressSliderTouchDown), for: .touchDown)
        progressSlider.addTarget(self, action: #selector(progressSliderTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        self.view.addSubview(progressSlider)
        progressSlider.snp.makeConstraints { make in
            make.width.equalTo(280)
            make.height.equalTo(30)
            make.centerX.equalTo(coverArtView)
            make.top.equalTo(coverArtView.snp.bottom).offset(20)
        }
        
        elapsedLabel.textColor = .black
        elapsedLabel.font = .systemFont(ofSize: 13)
        elapsedLabel.textAlignment = .right
        self.view.addSubview(elapsedLabel)
        elapsedLabel.snp.makeConstraints { make in
            make.centerY.equalTo(progressSlider)
            make.right.equalTo(progressSlider.snp.left).offset(-5)
            make.width.equalTo(50)
            make.height.equalTo(30)
        }
        
        remainingLabel.textColor = .black
        remainingLabel.font = .systemFont(ofSize: 13)
        remainingLabel.textAlignment = .left
        self.view.addSubview(remainingLabel)
        remainingLabel.snp.makeConstraints { make in
            make.centerY.equalTo(progressSlider)
            make.left.equalTo(progressSlider.snp.right).offset(5)
            make.width.equalTo(50)
            make.height.equalTo(30)
        }
        
        progressDisplayLink = CADisplayLink(target: self, selector: #selector(updateProgress))
        progressDisplayLink.isPaused = true
        progressDisplayLink.add(to: RunLoop.main, forMode: .defaultRunLoopMode)
        
        titleLabel.textColor = .black
        titleLabel.font = .systemFont(ofSize: 18)
        titleLabel.textAlignment = .center
        self.view.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(progressSlider.snp.bottom).offset(20)
            make.width.equalTo(300)
            make.height.equalTo(30)
        }
        
        artistLabel.textColor = .darkGray
        artistLabel.font = .systemFont(ofSize: 16)
        artistLabel.textAlignment = .center
        self.view.addSubview(artistLabel)
        artistLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(titleLabel.snp.bottom)
            make.width.equalTo(300)
            make.height.equalTo(30)
        }
        
        playButton.setTitleColor(.black, for: UIControlState())
        playButton.titleLabel?.font = .systemFont(ofSize: 35)
        playButton.addTarget(self, action: #selector(playPause), for: .touchUpInside)
        self.view.addSubview(playButton)
        playButton.snp.makeConstraints { make in
            make.width.equalTo(40)
            make.height.equalTo(40)
            make.centerX.equalToSuperview()
            make.top.equalTo(artistLabel.snp.bottom).offset(20)
        }
        
        spinner.hidesWhenStopped = true
        self.view.addSubview(spinner)
        spinner.snp.makeConstraints { make in
            make.centerX.equalTo(playButton)
            make.centerY.equalTo(playButton)
        }
        
        prevButton.setTitleColor(.black, for: UIControlState())
        prevButton.titleLabel?.font = .systemFont(ofSize: 35)
        prevButton.setTitle("«", for: UIControlState())
        prevButton.addTarget(self, action: #selector(previousSong), for: .touchUpInside)
        self.view.addSubview(prevButton)
        prevButton.snp.makeConstraints { make in
            make.width.equalTo(40)
            make.height.equalTo(40)
            make.right.equalTo(playButton.snp.left).offset(-20)
            make.centerY.equalTo(playButton).offset(-2)
        }
        
        nextButton.setTitleColor(.black, for: UIControlState())
        nextButton.titleLabel?.font = .systemFont(ofSize: 35)
        nextButton.setTitle("»", for: UIControlState())
        nextButton.addTarget(self, action: #selector(nextSong), for: .touchUpInside)
        self.view.addSubview(nextButton)
        nextButton.snp.makeConstraints { make in
            make.width.equalTo(40)
            make.height.equalTo(40)
            make.left.equalTo(playButton.snp.right).offset(20)
            make.centerY.equalTo(playButton).offset(-2)
        }
        
        updatePlayButton()
        updateCurrentSong()
        updateProgress()
        
        if AudioEngine.si().isPlaying() {
            playbackStarted()
        }
        
        NotificationCenter.addObserver(onMainThread: self, selector: #selector(playbackStarted), name: ISMSNotification_SongPlaybackStarted, object: nil)
        NotificationCenter.addObserver(onMainThread: self, selector: #selector(playbackPaused), name: ISMSNotification_SongPlaybackPaused, object: nil)
        NotificationCenter.addObserver(onMainThread: self, selector: #selector(playbackEnded), name: ISMSNotification_SongPlaybackEnded, object: nil)
        NotificationCenter.addObserver(onMainThread: self, selector: #selector(indexChanged), name: ISMSNotification_CurrentPlaylistIndexChanged, object: nil)
        
        tapRecognizer.addTarget(self, action: #selector(hidePlayer))
        coverArtView.addGestureRecognizer(tapRecognizer)
        
        swipeRecognizer.direction = .down
        swipeRecognizer.addTarget(self, action: #selector(hidePlayer))
        self.view.addGestureRecognizer(swipeRecognizer)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coverArtView.snp.updateConstraints { make in
            make.height.equalTo(coverArtViewSize)
            make.width.equalTo(coverArtViewSize)
            make.top.equalToSuperview().offset(coverArtViewTopOffset)
        }
        
        coordinator.animate(alongsideTransition: { context in
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
    deinit {
        NotificationCenter.removeObserver(onMainThread: self, name: ISMSNotification_SongPlaybackStarted, object: nil)
        NotificationCenter.removeObserver(onMainThread: self, name: ISMSNotification_SongPlaybackPaused, object: nil)
        NotificationCenter.removeObserver(onMainThread: self, name: ISMSNotification_SongPlaybackEnded, object: nil)
        NotificationCenter.removeObserver(onMainThread: self, name: ISMSNotification_CurrentPlaylistIndexChanged, object: nil)
    }
    
    @objc fileprivate func playPause() {
        if !AudioEngine.si().isStarted() {
            spinner.startAnimating()
        }
        
        PlayQueue.si.playPause()
    }
    
    @objc fileprivate func previousSong() {
        PlayQueue.si.playPreviousSong()
    }
    
    @objc fileprivate func nextSong() {
        PlayQueue.si.playNextSong()
    }
    
    @objc fileprivate func playbackStarted() {
        spinner.stopAnimating()
        updatePlayButton()
        progressDisplayLink.isPaused = false
    }
    
    @objc fileprivate func playbackPaused() {
        updatePlayButton()
        progressDisplayLink.isPaused = true
    }
    
    @objc fileprivate func playbackEnded() {
        updatePlayButton()
        progressDisplayLink.isPaused = true
    }
    
    @objc fileprivate func indexChanged() {
        updateCurrentSong()
    }
    
    fileprivate func updatePlayButton(_ playing: Bool = AudioEngine.si().isPlaying()) {
        if playing {
            playButton.setTitle("Ⅱ", for: UIControlState())
        } else {
            playButton.setTitle("▶", for: UIControlState())
        }
    }
    
    fileprivate func updateCurrentSong() {
        let currentSong = PlayQueue.si.currentDisplaySong
        if let coverArtId = currentSong?.coverArtId {
            coverArtView.loadImage(coverArtId: coverArtId, size: .player)
        } else {
            coverArtView.setDefaultImage(forSize: .player)
        }
        titleLabel.text = currentSong?.title
        artistLabel.text = currentSong?.artistDisplayName
    }
    
    @objc fileprivate func updateProgress() {
        let progress = AudioEngine.si().progress()
        let progressPercent = AudioEngine.si().progressPercent()
        
        progressSlider.value = Float(progressPercent)
        elapsedLabel.text = NSString.formatTime(progress)
        if let duration = PlayQueue.si.currentDisplaySong?.duration, let formattedTime = NSString.formatTime(Double(duration) - progress) {
            remainingLabel.text = "-\(formattedTime)"
        }
    }
    
    @objc fileprivate func progressSliderTouchDown() {
        progressDisplayLink.isPaused = true
    }
    
    @objc fileprivate func progressSliderTouchUp() {
        progressDisplayLink.isPaused = false
    }
    
    @objc fileprivate func progressSliderValueChanged() {
        AudioEngine.si().seekToPosition(inPercent: Double(progressSlider.value), fadeVolume: true)
    }
    
    @objc fileprivate func hidePlayer() {
        self.dismiss(animated: true, completion: nil)
    }
}
