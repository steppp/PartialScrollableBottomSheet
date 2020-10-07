//
//  PartialViewGestureRecognizerDelegate.swift
//  PartialModal
//
//  Created by Stefano Andriolo on 06/10/20.
//

import UIKit

class PartialScrollableView: UIView {
    
    var touchesDelegate: PartialScrollableViewDelegate
    var startingTouchLocation: CGPoint
    
    var innerScrollView: UIScrollView
    var superviewScrollState: ViewController.PositionState
    var lastScrollViewPanGestureY: CGFloat
    
    init(delegate: PartialScrollableViewDelegate) {
        self.touchesDelegate = delegate
        self.startingTouchLocation = .zero
        self.innerScrollView = UIScrollView()
        self.superviewScrollState = .progressing
        self.lastScrollViewPanGestureY = .zero
        
        super.init(frame: CGRect.zero)
        self.setupInnerScrollView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /* - TODO: these two methods should be moved to a specific view inside this one but
            OUTSIDE the scroll view (i.e. a tooltip on the top
 */
//    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
//        // - TODO: choose if touches should be dispatched to the underlying scroll view instead
//
//        if let touch = touches.first {
//            self.startingTouchLocation = touch.location(in: self.superview)
//            self.touchesDelegate.scrollStarted(at: self.startingTouchLocation)
//        }
//
//        super.touchesBegan(touches, with: event)
//    }
//
//    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
//        // - TODO: choose if touches should be dispatched to the underlying scroll view instead
//
//        if let touch = touches.first {
//            self.touchesDelegate.scrollUpdated(with: touch.location(in: self.superview))
//        }
//
//        super.touchesMoved(touches, with: event)
//    }
    
    private func setupInnerScrollView() {
        self.innerScrollView.delegate = self
        self.innerScrollView.contentSize = CGSize(width: self.frame.width,
                                                  height: 69.0 * 20)
        self.innerScrollView.isScrollEnabled = true
        self.innerScrollView.alwaysBounceVertical = false
        self.innerScrollView.translatesAutoresizingMaskIntoConstraints = false
        
        self.addSubview(self.innerScrollView)
        
        NSLayoutConstraint.activate([
            self.innerScrollView.topAnchor.constraint(equalTo: self.topAnchor),
            self.innerScrollView.heightAnchor.constraint(equalTo: self.heightAnchor, multiplier: 0.5),
            self.innerScrollView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            self.innerScrollView.widthAnchor.constraint(equalTo: self.widthAnchor)
        ])
        
        let contentView = UIView(frame: CGRect(x: .zero, y: .zero,
                                               width: self.frame.width, height: self.frame.height))
        contentView.translatesAutoresizingMaskIntoConstraints = false
        self.innerScrollView.addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: self.innerScrollView.topAnchor),
            contentView.heightAnchor.constraint(equalTo: self.innerScrollView.heightAnchor),
//            contentView.trailingAnchor.constraint(equalTo: self.innerScrollView.trailingAnchor),
            contentView.widthAnchor.constraint(equalTo: self.innerScrollView.widthAnchor)
        ])
        
        for i in 0..<20 {
            let rect = CGRect(x: .zero, y: .zero, width: self.frame.width, height: 69)
            let rectView = UIView(frame: rect)
            rectView.backgroundColor = i % 2 == 0 ? UIColor.systemBlue : UIColor.systemGreen
            contentView.addSubview(rectView)
            
            rectView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                rectView.topAnchor.constraint(equalTo: contentView.topAnchor,
                                              constant: CGFloat(i) * 69.0),
//                rectView.trailingAnchor.constraint(equalTo: self.innerScrollView.trailingAnchor),
                rectView.heightAnchor.constraint(equalToConstant: 69),
                rectView.widthAnchor.constraint(equalTo: contentView.widthAnchor)
            ])
        }
    }
    
    
}

protocol PartialScrollableViewDelegate {
    func scrollStarted(at location: CGPoint)
    
    func scrollUpdated(with value: CGPoint)
    
    func resizeWindowHeight(from offsetValue: CGFloat)
    
    func scrollEnded(withVelocity velocity: CGFloat)
    // - TODO: add logic based on velocity
}

extension PartialScrollableView: UIScrollViewDelegate {
    // see https://stackoverflow.com/a/51768193
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        debugPrint("will begin dragging")
        self.lastScrollViewPanGestureY = .zero
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if self.shouldMoveParentWindow(insteadOf: scrollView) {
//            debugPrint("should move parent window")
            self.translateParentWindow(insteadOf: scrollView)
        } else {
            // save anyway the y component of the last reported value of the gesture recognizer
            // so the view can be resized smoothly when the scroll view reaches the top/bottom
            // without jumps
            self.lastScrollViewPanGestureY =
                scrollView.panGestureRecognizer.translation(in: self).y
            scrollView.showsVerticalScrollIndicator = true
        }
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint,
                                   targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        self.touchesDelegate.scrollEnded(withVelocity: velocity.y)
        
        debugPrint("dragging ended")
        debugPrint(self.superviewScrollState.rawValue)
        if self.superviewScrollState == .progressing ||
            self.superviewScrollState == .bottom {
            debugPrint("prohibited scrolling mitigation")
            targetContentOffset.pointee = .zero
            scrollView.isScrollEnabled = false
            scrollView.showsVerticalScrollIndicator = false
        }
        
        scrollView.isScrollEnabled = true
    }
}

// - MARK: Scroll logic-related methods
extension PartialScrollableView {
    func superviewPositionStateUpdated(to value: ViewController.PositionState) {
        self.superviewScrollState = value
        
//        debugPrint("partial scrollable view state has been updated to \(value)")
    }
    
    private func shouldMoveParentWindow(insteadOf scrollview: UIScrollView) -> Bool {
        let offsetY = scrollview.contentOffset.y
        if self.superviewScrollState == .top {
            return offsetY < 0
        }
        
        if self.superviewScrollState == .bottom {
            return offsetY > 0
        }
        
        return true // self.superviewScrollState == .progressing
    }
    
    private func translateParentWindow(insteadOf scrollview: UIScrollView) {
        let translation = scrollview.panGestureRecognizer.translation(in: self)
        let delta = self.lastScrollViewPanGestureY - translation.y
        self.lastScrollViewPanGestureY = translation.y
        
        scrollview.contentOffset = .zero // when parent window is moving, the scrollview must not
        self.touchesDelegate.resizeWindowHeight(from: delta)
    }
}
