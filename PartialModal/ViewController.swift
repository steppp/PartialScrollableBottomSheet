//
//  ViewController.swift
//  PartialModal
//
//  Created by Stefano Andriolo on 06/10/20.
//

import UIKit

class ViewController: UIViewController {
    
    weak var partialView: PartialScrollableView!
    let initialVisibleHeight: CGFloat = 500.0
    
    // this will change to move the partial view up and down
    var topConstraint: NSLayoutConstraint!
    var topConstraintValueWhenPanStarts: CGFloat = .zero
    var startingPanPointY: CGFloat = .zero
    
    let minimumViewHeightDifferencePercentage: CGFloat = 5.0
    let midViewHeightDifferencePercentage: CGFloat = 55.0
    let maximumViewHeightDifferencePercentage: CGFloat = 85.0
    var minimumViewHeightDifference: CGFloat = .zero
    var midViewHeightDifference: CGFloat = .zero
    var maximumViewHeightDifference: CGFloat = .zero

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setupSubview()
        self.applyStyle(to: self.partialView)
        
        self.minimumViewHeightDifference = self.view.frame.height *
            self.minimumViewHeightDifferencePercentage / 100.0
        self.midViewHeightDifference = self.view.frame.height *
            self.midViewHeightDifferencePercentage / 100.0
        self.maximumViewHeightDifference = self.view.frame.height *
            self.maximumViewHeightDifferencePercentage / 100.0
    }
    
    private func setupSubview() {
        let viewToBeAdded = PartialScrollableView(delegate: self)
        self.view.addSubview(viewToBeAdded)
        
        self.addConstraints(to: viewToBeAdded)
        self.partialView = viewToBeAdded
    }
    
    private func addConstraints(to view: UIView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        
        self.topConstraint = view.topAnchor.constraint(
            equalTo: self.view.safeAreaLayoutGuide.topAnchor,
            constant: self.view.safeAreaLayoutGuide.layoutFrame.height - self.initialVisibleHeight)
        
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.widthAnchor),
            view.heightAnchor.constraint(equalTo: self.view.heightAnchor),
            view.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor),
            self.topConstraint
        ])
    }
    
    private func applyStyle(to view: UIView) {
        view.clipsToBounds = true
        view.layer.cornerRadius = 20.0
        view.backgroundColor = UIColor.systemBackground
    }
    
    private func checkBoundsAndUpdate(viewHeightWithValue height: CGFloat,
                                      positionState shouldUpdatePositionState: Bool) {
        self.topConstraint.constant = min(self.maximumViewHeightDifference,
                                          max(self.minimumViewHeightDifference, height))
        
        if shouldUpdatePositionState {
            self.updatePositionState()
        }
    }
    
    private func updatePositionState() {
        var positionState = PositionState.progressing
        if self.topConstraint.constant == minimumViewHeightDifference {
            positionState = .top
        } else if self.topConstraint.constant == midViewHeightDifference {
            positionState = .mid
        } else if self.topConstraint.constant == maximumViewHeightDifference {
            positionState = .bottom
        }
        
        self.partialView.superviewPositionStateUpdated(to: positionState)
    }
    
    private func getMidPoints(from array: [CGFloat]) -> [CGFloat] {
        return array.enumerated().compactMap { (index, el) -> CGFloat? in
            (array.startIndex..<array.endIndex ~= index + 1 ? array[index + 1] : nil)
                .flatMap { next in
                    (el + next) * 0.5
                }
        }
    }
    
    private func getIndexOfClosestValue(to value: CGFloat, from array: [CGFloat]) -> Int {
        return [array.enumerated().map { (i, el) in
            (i, abs(el - value))
        }.min { (t1, t2) -> Bool in
            t1.1 < t2.1
        }].compactMap { $0?.0 }[0]
    }
    
    enum PositionState: String, CaseIterable {
        case top, progressing, mid, bottom
    }
}

extension ViewController: PartialScrollableViewDelegate {
    func scrollStarted(at location: CGPoint) {
        self.topConstraintValueWhenPanStarts = self.topConstraint.constant
        self.startingPanPointY = location.y
    }
    
    func scrollUpdated(with value: CGPoint) {
        let newConstantValue =
            self.topConstraintValueWhenPanStarts - (self.startingPanPointY - value.y)
        self.checkBoundsAndUpdate(viewHeightWithValue: newConstantValue, positionState: true)
    }
    
    func resizeWindowHeight(from offsetValue: CGFloat) {
        let newConstantValue = self.topConstraint.constant - offsetValue
        self.checkBoundsAndUpdate(viewHeightWithValue: newConstantValue, positionState: true)
    }
    
    func scrollEnded(_ scrollView: UIScrollView, withVelocity velocity: CGFloat) {
        var viewHeightUpdateValue: CGFloat = self.maximumViewHeightDifference
        
        let treshold: CGFloat = 0.4
        // checkpoints stored from top to bottom
        let checkpoints = [self.minimumViewHeightDifference,
                           self.midViewHeightDifference,
                           self.maximumViewHeightDifference]
        let indexOfNearestCheckpoint = self.getIndexOfClosestValue(to: self.topConstraint.constant,
                                                                   from: checkpoints)

        if scrollView.contentOffset.y == .zero && abs(velocity) > treshold {
            // check whether the constraint value is below the nearest value or not
            let isBelowCheckpoint = checkpoints[indexOfNearestCheckpoint] < self.topConstraint.constant
            if velocity > 0 {
                // going up
                if isBelowCheckpoint {
                    // below: set the constraint to the nearest value
                    viewHeightUpdateValue = checkpoints[indexOfNearestCheckpoint]
                } else {
                    // above: set the constraint to the previous (higher) checkpoint
                    // prevent the index from going out of bounds due to the animation (?)
                    let previousIndex = indexOfNearestCheckpoint - 1
                    viewHeightUpdateValue = checkpoints[previousIndex < 0 ? 0 : previousIndex]
                }
            } else {
                // going down
                if isBelowCheckpoint {
                    // below: set the constraint to the next (lower) checkpoint
                    // prevent the index from going out of bounds due to the animation (?)
                    let nextIndex = indexOfNearestCheckpoint + 1
                    viewHeightUpdateValue = checkpoints[nextIndex < checkpoints.count ?
                                                            nextIndex : checkpoints.count - 1]
                } else {
                    // above: set the constrant to the nearest value
                    viewHeightUpdateValue = checkpoints[indexOfNearestCheckpoint]
                }
            }
        } else {
            viewHeightUpdateValue = checkpoints[indexOfNearestCheckpoint]
        }
        
        
        let animationTimingParameters = UISpringTimingParameters(mass: 2.0,
                                                                 stiffness: 200.0,
                                                                 damping: 30.0,
                                                                 initialVelocity: .init(dx: 0,
                                                                                        dy: 1.0))
        let animator = UIViewPropertyAnimator(duration: 0.2,
                                              timingParameters: animationTimingParameters)
        animator.addAnimations {
            self.checkBoundsAndUpdate(viewHeightWithValue: viewHeightUpdateValue,
                                      positionState: false)
            self.view.layoutIfNeeded()
        }

        animator.startAnimation()
        animator.addCompletion { _ in
            self.updatePositionState()
        }
    }
}
