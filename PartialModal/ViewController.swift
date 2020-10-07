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
    let maximumViewHeightDifferencePercentage: CGFloat = 85.0
    var minimumViewHeightDifference: CGFloat = .zero
    var maximumViewHeightDifference: CGFloat = .zero

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor.red
        self.setupSubview()
    }
    
    override func viewDidLayoutSubviews() {
        // this must be done after the views have been layed out to allow constraints
        // to give the partialView its correct size
        self.applyStyle(to: self.partialView)
        
        self.minimumViewHeightDifference = self.view.frame.height *
            self.minimumViewHeightDifferencePercentage / 100.0
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
        if self.topConstraint.constant == minimumViewHeightDifference {
            self.partialView.superviewPositionStateUpdated(to: .top)
        } else if self.topConstraint.constant == maximumViewHeightDifference {
            self.partialView.superviewPositionStateUpdated(to: .bottom)
        } else {
            self.partialView.superviewPositionStateUpdated(to: .progressing)
        }
    }
    
    enum PositionState: String {
        case top, progressing, bottom
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
    
    func scrollEnded(withVelocity velocity: CGFloat) {
        debugPrint(velocity)
        // if velocity > ~0.2, go to the next checkpoint in that direction
        
        let animationTimingParameters = UISpringTimingParameters(mass: 2.0,
                                                                 stiffness: 200.0,
                                                                 damping: 30.0,
                                                                 initialVelocity: .init(dx: 0,
                                                                                        dy: velocity * 4))
        let animator = UIViewPropertyAnimator(duration: 0.2,
                                              timingParameters: animationTimingParameters)
        let maxMinMidPointY =
            (self.minimumViewHeightDifference + self.maximumViewHeightDifference) * 0.5
        var viewHeightUpdateValue: CGFloat = self.maximumViewHeightDifference
        
        if self.minimumViewHeightDifference..<maxMinMidPointY ~= self.topConstraint.constant {
            // expand to top
            viewHeightUpdateValue = self.minimumViewHeightDifference
        } else if maxMinMidPointY..<self.maximumViewHeightDifference ~= self.topConstraint.constant {
            viewHeightUpdateValue = self.maximumViewHeightDifference
        }
                
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

