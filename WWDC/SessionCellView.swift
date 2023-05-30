//
//  SessionCellView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 13/05/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Cocoa
import Combine

final class SessionCellView: NSView {

    private var cancellables: Set<AnyCancellable> = []

    var viewModel: SessionViewModel? {
        didSet {
            guard viewModel !== oldValue else { return }

            thumbnailImageView.image = #imageLiteral(resourceName: "noimage")
            bindUI()
        }
    }

    private weak var imageDownloadOperation: Operation?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        buildUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        imageDownloadOperation?.cancel()

        downloadedImageView.isHidden = true
        favoritedImageView.isHidden = true
    }

    private func bindUI() {
        cancellables = []

        guard let viewModel = viewModel else { return }

        viewModel.rxTitle.removeDuplicates().receive(on: DispatchQueue.main).replaceError(with: "").assign(to: \.stringValue, onWeak: titleLabel).store(in: &cancellables)
        viewModel.rxSubtitle.removeDuplicates().receive(on: DispatchQueue.main).replaceError(with: "").assign(to: \.stringValue, onWeak: subtitleLabel).store(in: &cancellables)
        viewModel.rxContext.driveUI(\.stringValue, on: contextLabel, default: "").store(in: &cancellables)

        viewModel.rxIsFavorite.toggled().driveUI(\.isHidden, on: favoritedImageView, default: true).store(in: &cancellables)
        viewModel.rxIsDownloaded.toggled().driveUI(\.isHidden, on: downloadedImageView, default: true).store(in: &cancellables)

        let isSnowFlake = Publishers.Zip(viewModel.rxIsCurrentlyLive, viewModel.rxIsLab)

        isSnowFlake.map({ !$0.0 && !$0.1 }).driveUI(\.isHidden, on: snowFlakeView, default: true).store(in: &cancellables)
        isSnowFlake.map({ $0.0 || $0.1 }).driveUI(\.isHidden, on: thumbnailImageView, default: true).store(in: &cancellables)

        isSnowFlake.replaceErrorWithEmpty().sink(receiveValue: { [weak self] (isLive: Bool, isLab: Bool) -> Void in
            if isLive {
                self?.snowFlakeView.image = #imageLiteral(resourceName: "live-indicator")
            } else if isLab {
                self?.snowFlakeView.image = #imageLiteral(resourceName: "lab-indicator")
            }
        }).store(in: &cancellables)

        viewModel.rxImageUrl.removeDuplicates().replaceErrorWithEmpty().compacted().sink { [weak self] imageUrl in
            self?.imageDownloadOperation?.cancel()

            self?.imageDownloadOperation = ImageDownloadCenter.shared.downloadImage(from: imageUrl, thumbnailHeight: Constants.thumbnailHeight, thumbnailOnly: true) { [weak self] url, result in
                guard url == imageUrl, result.thumbnail != nil else { return }

                self?.thumbnailImageView.image = result.thumbnail
            }
        }
        .store(in: &cancellables)

        viewModel.rxColor.removeDuplicates().replaceErrorWithEmpty().sink(receiveValue: { [weak self] color in
            self?.contextColorView.color = color
        }).store(in: &cancellables)

        viewModel.rxDarkColor.removeDuplicates().replaceErrorWithEmpty().sink(receiveValue: { [weak self] color in
            self?.snowFlakeView.backgroundColor = color
        }).store(in: &cancellables)

        viewModel.rxProgresses.replaceErrorWithEmpty().sink(receiveValue: { [weak self] progresses in
            if let progress = progresses.first {
                self?.contextColorView.hasValidProgress = true
                self?.contextColorView.progress = progress.relativePosition
            } else {
                self?.contextColorView.hasValidProgress = false
                self?.contextColorView.progress = 0
            }
        }).store(in: &cancellables)

        viewModel.rxSessionType.removeDuplicates().replaceErrorWithEmpty().sink(receiveValue: { [weak self] type in
            guard ![.lab, .session, .labByAppointment].contains(type) else { return }

            switch type {
            case .getTogether:
                self?.thumbnailImageView.image = #imageLiteral(resourceName: "get-together")
            default:
                self?.thumbnailImageView.image = #imageLiteral(resourceName: "special")
            }
        }).store(in: &cancellables)
    }

    private lazy var titleLabel: NSTextField = {
        let l = NSTextField(labelWithString: "")
        l.font = .systemFont(ofSize: 14, weight: .medium)
        l.textColor = .primaryText
        l.cell?.backgroundStyle = .emphasized
        l.lineBreakMode = .byTruncatingTail

        return l
    }()

    private lazy var subtitleLabel: NSTextField = {
        let l = NSTextField(labelWithString: "")
        l.font = .systemFont(ofSize: 12)
        l.textColor = .secondaryText
        l.cell?.backgroundStyle = .emphasized
        l.lineBreakMode = .byTruncatingTail

        return l
    }()

    private lazy var contextLabel: NSTextField = {
        let l = NSTextField(labelWithString: "")
        l.font = .systemFont(ofSize: 12)
        l.textColor = .tertiaryText
        l.cell?.backgroundStyle = .emphasized
        l.lineBreakMode = .byTruncatingTail

        return l
    }()

    private lazy var thumbnailImageView: WWDCImageView = {
        let v = WWDCImageView()

        v.heightAnchor.constraint(equalToConstant: 48).isActive = true
        v.widthAnchor.constraint(equalToConstant: 85).isActive = true
        v.backgroundColor = .black

        return v
    }()

    private lazy var snowFlakeView: WWDCImageView = {
        let v = WWDCImageView()

        v.heightAnchor.constraint(equalToConstant: 48).isActive = true
        v.widthAnchor.constraint(equalToConstant: 85).isActive = true
        v.isHidden = true
        v.image = #imageLiteral(resourceName: "lab-indicator")

        return v
    }()

    private lazy var contextColorView: TrackColorView = {
        let v = TrackColorView()

        v.widthAnchor.constraint(equalToConstant: 4).isActive = true

        return v
    }()

    private lazy var textStackView: NSStackView = {
        let v = NSStackView(views: [self.titleLabel, self.subtitleLabel, self.contextLabel])

        v.orientation = .vertical
        v.alignment = .leading
        v.distribution = .equalSpacing
        v.spacing = 0

        return v
    }()

    private lazy var favoritedImageView: WWDCImageView = {
        let v = WWDCImageView()

        v.heightAnchor.constraint(equalToConstant: 14).isActive = true
        v.drawsBackground = false
        v.image = #imageLiteral(resourceName: "star-small")

        return v
    }()

    private lazy var downloadedImageView: WWDCImageView = {
        let v = WWDCImageView()

        v.heightAnchor.constraint(equalToConstant: 11).isActive = true
        v.drawsBackground = false
        v.image = #imageLiteral(resourceName: "download-small")

        return v
    }()

    private lazy var iconsStackView: NSStackView = {
        let v = NSStackView(views: [])

        v.distribution = .gravityAreas
        v.orientation = .vertical
        v.spacing = 4
        v.addView(self.favoritedImageView, in: .top)
        v.addView(self.downloadedImageView, in: .bottom)
        v.translatesAutoresizingMaskIntoConstraints = false

        v.widthAnchor.constraint(equalToConstant: 12).isActive = true

        return v
    }()

    private func buildUI() {
        wantsLayer = true

        contextColorView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        snowFlakeView.translatesAutoresizingMaskIntoConstraints = false
        textStackView.translatesAutoresizingMaskIntoConstraints = false
        iconsStackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(contextColorView)
        addSubview(thumbnailImageView)
        addSubview(snowFlakeView)
        addSubview(textStackView)
        addSubview(iconsStackView)

        contextColorView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10).isActive = true
        contextColorView.topAnchor.constraint(equalTo: topAnchor, constant: 8).isActive = true
        contextColorView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8).isActive = true

        thumbnailImageView.centerYAnchor.constraint(equalTo: contextColorView.centerYAnchor).isActive = true
        thumbnailImageView.leadingAnchor.constraint(equalTo: contextColorView.trailingAnchor, constant: 8).isActive = true
        snowFlakeView.centerYAnchor.constraint(equalTo: thumbnailImageView.centerYAnchor).isActive = true
        snowFlakeView.centerXAnchor.constraint(equalTo: thumbnailImageView.centerXAnchor).isActive = true

        textStackView.centerYAnchor.constraint(equalTo: thumbnailImageView.centerYAnchor, constant: -1).isActive = true
        textStackView.leadingAnchor.constraint(equalTo: thumbnailImageView.trailingAnchor, constant: 8).isActive = true
        textStackView.trailingAnchor.constraint(equalTo: iconsStackView.leadingAnchor, constant: -2).isActive = true

        iconsStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4).isActive = true
        iconsStackView.topAnchor.constraint(equalTo: textStackView.topAnchor).isActive = true
        iconsStackView.bottomAnchor.constraint(equalTo: textStackView.bottomAnchor).isActive = true

        downloadedImageView.isHidden = true
        favoritedImageView.isHidden = true
    }

}
