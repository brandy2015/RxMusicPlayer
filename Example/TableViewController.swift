//
//  TableTableViewController.swift
//  Example
//
//  Created by YOSHIMUTA YOHEI on 2019/09/12.
//  Copyright © 2019 YOSHIMUTA YOHEI. All rights reserved.
//
// swiftlint:disable line_length

import RxCocoa
import RxMusicPlayer
import RxSwift
import UIKit

class TableViewController: UITableViewController {

    @IBOutlet private var playButton: UIButton!
    @IBOutlet private var nextButton: UIButton!
    @IBOutlet private var prevButton: UIButton!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var artImageView: UIImageView!
    @IBOutlet private var lyricsLabel: UILabel!
    @IBOutlet private var seekBar: ProgressSlider!
    @IBOutlet private var seekDurationLabel: UILabel!
    @IBOutlet private var durationLabel: UILabel!
    @IBOutlet private var shuffleButton: UIButton!
    @IBOutlet private var repeatButton: UIButton!
    @IBOutlet private var rateButton: UIButton!
    @IBOutlet private var appendButton: UIButton!
    @IBOutlet private var changeButton: UIButton!

    private let disposeBag = DisposeBag()

    // swiftlint:disable cyclomatic_complexity
    override func viewDidLoad() {
        super.viewDidLoad()

        // 1) Create a player
        var items = [
            "https://storage.googleapis.com/great-dev/oss/musicplayer/tagmp3_1473200_1.mp3",
            "https://storage.googleapis.com/great-dev/oss/musicplayer/tagmp3_2160166.mp3",
            "https://storage.googleapis.com/great-dev/oss/musicplayer/tagmp3_4690995.mp3",
            "https://storage.googleapis.com/great-dev/oss/musicplayer/tagmp3_9179181.mp3",
        ]
        .map({ RxMusicPlayerItem(url: URL(string: $0)!) })
        // The default metadata is ignored since this item's original metadata are set already.
        items.append(RxMusicPlayerItem(url: URL(string: "https://storage.googleapis.com/great-dev/oss/musicplayer/bensound-extremeaction.mp3")!,
                                       meta: RxMusicPlayerItem.Meta(title: "defaultTitle",
                                                                    album: "defaultAlbum",
                                                                    artist: "defaultArtist",
                                                                    skipDownloading: false)))
        // The default metadata is used since this item's original metadata are empty.
        items.append(RxMusicPlayerItem(url: URL(string: "https://storage.googleapis.com/great-dev/oss/musicplayer/bensound-littleplanet.mp3")!,
                                       meta: RxMusicPlayerItem.Meta(title: "defaultTitle",
                                                                    album: "defaultAlbum",
                                                                    artist: "defaultArtist")))
        let player = RxMusicPlayer(items: Array(items[0 ..< 4]))!

        // 2) Control views
        player.rx.canSendCommand(cmd: .play)
            .do(onNext: { [weak self] canPlay in
                self?.playButton.setTitle(canPlay ? "Play" : "Pause", for: .normal)
            })
            .drive()
            .disposed(by: disposeBag)

        player.rx.canSendCommand(cmd: .next)
            .drive(nextButton.rx.isEnabled)
            .disposed(by: disposeBag)

        player.rx.canSendCommand(cmd: .previous)
            .drive(prevButton.rx.isEnabled)
            .disposed(by: disposeBag)

        player.rx.canSendCommand(cmd: .seek(seconds: 0, shouldPlay: false))
            .drive(seekBar.rx.isUserInteractionEnabled)
            .disposed(by: disposeBag)

        player.rx.currentItemTitle()
            .drive(titleLabel.rx.text)
            .disposed(by: disposeBag)

        player.rx.currentItemArtwork()
            .drive(artImageView.rx.image)
            .disposed(by: disposeBag)

        player.rx.currentItemLyrics()
            .distinctUntilChanged()
            .do(onNext: { [weak self] _ in
                self?.tableView.reloadData()
            })
            .drive(lyricsLabel.rx.text)
            .disposed(by: disposeBag)

        player.rx.currentItemRestDurationDisplay()
            .map {
                guard let rest = $0 else { return "--:--" }
                return "-\(rest)"
            }
            .drive(durationLabel.rx.text)
            .disposed(by: disposeBag)

        player.rx.currentItemTimeDisplay()
            .drive(seekDurationLabel.rx.text)
            .disposed(by: disposeBag)

        player.rx.currentItemDuration()
            .map { Float($0?.seconds ?? 0) }
            .do(onNext: { [weak self] in
                self?.seekBar.maximumValue = $0
            })
            .drive()
            .disposed(by: disposeBag)

        let seekValuePass = BehaviorRelay<Bool>(value: true)
        player.rx.currentItemTime()
            .withLatestFrom(seekValuePass.asDriver()) { ($0, $1) }
            .filter { $0.1 }
            .map { Float($0.0?.seconds ?? 0) }
            .drive(seekBar.rx.value)
            .disposed(by: disposeBag)
        seekBar.rx.controlEvent(.touchDown)
            .do(onNext: {
                seekValuePass.accept(false)
            })
            .subscribe()
            .disposed(by: disposeBag)
        seekBar.rx.controlEvent(.touchUpInside)
            .do(onNext: {
                seekValuePass.accept(true)
            })
            .subscribe()
            .disposed(by: disposeBag)

        player.rx.currentItemLoadedProgressRate()
            .drive(seekBar.rx.playableProgress)
            .disposed(by: disposeBag)

        player.rx.shuffleMode()
            .do(onNext: { [weak self] mode in
                self?.shuffleButton.setTitle(mode == .off ? "Shuffle" : "No Shuffle", for: .normal)
            })
            .drive()
            .disposed(by: disposeBag)

        player.rx.repeatMode()
            .do(onNext: { [weak self] mode in
                var title = ""
                switch mode {
                case .none: title = "Repeat"
                case .one: title = "Repeat(All)"
                case .all: title = "No Repeat"
                }
                self?.repeatButton.setTitle(title, for: .normal)
            })
            .drive()
            .disposed(by: disposeBag)

        player.rx.playerIndex()
            .do(onNext: { index in
                if index == player.queuedItems.count - 1 {
                    // You can remove the comment-out below to confirm the append().
                    // player.append(items: items)
                }
            })
            .drive()
            .disposed(by: disposeBag)

        // 3) Process the user's input
        let cmd = Driver.merge(
            playButton.rx.tap.asDriver().map { [weak self] in
                if self?.playButton.currentTitle == "Play" {
                    return RxMusicPlayer.Command.play
                }
                return RxMusicPlayer.Command.pause
            },
            nextButton.rx.tap.asDriver().map { RxMusicPlayer.Command.next },
            prevButton.rx.tap.asDriver().map { RxMusicPlayer.Command.previous },
            seekBar.rx.controlEvent(.valueChanged).asDriver()
                .map { [weak self] _ in
                    RxMusicPlayer.Command.seek(seconds: Int(self?.seekBar.value ?? 0),
                                               shouldPlay: false)
                }
                .distinctUntilChanged()
        )
        .startWith(.prefetch)
        .debug()

        // You can remove the comment-out below to confirm changing the current index of music items.
        // Default is 0.
        // player.playIndex = 1

        player.run(cmd: cmd)
            .do(onNext: { status in
                UIApplication.shared.isNetworkActivityIndicatorVisible = status == .loading
            })
            .flatMap { [weak self] status -> Driver<()> in
                guard let weakSelf = self else { return .just(()) }

                switch status {
                case let RxMusicPlayer.Status.failed(err: err):
                    print(err)
                    return Wireframe.promptOKAlertFor(src: weakSelf,
                                                      title: "Error",
                                                      message: err.localizedDescription)

                case let RxMusicPlayer.Status.critical(err: err):
                    print(err)
                    return Wireframe.promptOKAlertFor(src: weakSelf,
                                                      title: "Critical Error",
                                                      message: err.localizedDescription)
                default:
                    print(status)
                }
                return .just(())
            }
            .drive()
            .disposed(by: disposeBag)

        shuffleButton.rx.tap.asDriver()
            .drive(onNext: {
                switch player.shuffleMode {
                case .off: player.shuffleMode = .songs
                case .songs: player.shuffleMode = .off
                }
            })
            .disposed(by: disposeBag)

        repeatButton.rx.tap.asDriver()
            .drive(onNext: {
                switch player.repeatMode {
                case .none: player.repeatMode = .one
                case .one: player.repeatMode = .all
                case .all: player.repeatMode = .none
                }
            })
            .disposed(by: disposeBag)

        rateButton.rx.tap.asDriver()
            .flatMapLatest { [weak self] _ -> Driver<()> in
                guard let weakSelf = self else { return .just(()) }

                return Wireframe.promptSimpleActionSheetFor(
                    src: weakSelf,
                    cancelAction: "Close",
                    actions: PlaybackRateAction.allCases.map {
                        ($0.rawValue, player.desiredPlaybackRate == $0.toFloat)
                })
                    .do(onNext: { [weak self] action in
                        if let rate = PlaybackRateAction(rawValue: action)?.toFloat {
                            player.desiredPlaybackRate = rate
                            self?.rateButton.setTitle(action, for: .normal)
                        }
                    })
                    .map { _ in }
            }
            .drive()
            .disposed(by: disposeBag)

        appendButton.rx.tap.asDriver()
            .do(onNext: {
                let newItems = Array(items[4 ..< 6])
                player.append(items: newItems)
            })
            .drive(onNext: { [weak self] _ in
                self?.appendButton.isEnabled = false
            })
            .disposed(by: disposeBag)

        changeButton.rx.tap.asObservable()
            .flatMapLatest { [weak self] _ -> Driver<()> in
                guard let weakSelf = self else { return .just(()) }

                return Wireframe.promptSimpleActionSheetFor(
                    src: weakSelf,
                    cancelAction: "Close",
                    actions: items.map {
                        ($0.url.lastPathComponent, player.queuedItems.contains($0))
                })
                    .asObservable()
                    .do(onNext: { action in
                        if let idx = player.queuedItems.map({ $0.url.lastPathComponent }).firstIndex(of: action) {
                            try player.remove(at: idx)
                        } else if let idx = items.map({ $0.url.lastPathComponent }).firstIndex(of: action) {
                            for i in (0 ... idx).reversed() {
                                if let prev = player.queuedItems.firstIndex(of: items[i]) {
                                    player.insert(items[idx], at: prev + 1)
                                    break
                                }
                                if i == 0 {
                                    player.insert(items[idx], at: 0)
                                }
                            }
                        }

                        self?.appendButton.isEnabled = !(player.queuedItems.contains(items[4])
                            || player.queuedItems.contains(items[5]))
                    })
                    .asDriver(onErrorJustReturn: "")
                    .map { _ in }
            }
            .asDriver(onErrorJustReturn: ())
            .drive()
            .disposed(by: disposeBag)
    }
}
