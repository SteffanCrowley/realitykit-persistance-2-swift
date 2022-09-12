//
//  Coordinator.swift
//  realitykit-persistnance-2-swift
//
//  Created by steffan crowley on 9/12/22.
//

import Foundation
import ARKit
import RealityKit

class Coordinator: NSObject, ARSessionDelegate {
    
    let vm: ViewModel
    var arView: ARView?
    
    init(vm: ViewModel) {
        self.vm = vm
    }

    @objc func onTap(_ recognizer: UITapGestureRecognizer) {
        
        guard let arView = arView else {
            return
        }

        let location = recognizer.location(in: arView)
        let results = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .horizontal)
        
        if let result = results.first {
            
            let arAnchor = ARAnchor(name: "boxAnchor", transform: result.worldTransform)
            
            let anchor = AnchorEntity(anchor: arAnchor)
            let box = ModelEntity(mesh: MeshResource.generateBox(size: 0.1), materials: [SimpleMaterial(color: .green, isMetallic: true)])
            
            //this allows us to interact with entity
            box.generateCollisionShapes(recursive: true)
            
            arView.session.add(anchor: arAnchor)
            anchor.addChild(box)
            arView.scene.addAnchor(anchor)
            
            //install basic translation, rotation, and scale gestures to our model
            arView.installGestures(for: box)
        }
    }
    
    
    func clearWorldMap() {
        
        guard let arView = arView else {
            return
        }
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        arView.session.run(configuration, options: [.removeExistingAnchors, .resetTracking])
        
        let userDefaults = UserDefaults.standard
        userDefaults.removeObject(forKey: "worldMap")
        userDefaults.synchronize()
        
        vm.isSaved = false
        
    }
    
    func loadWorldMap() {
        
        guard let arView = arView else {
            return
        }
        
        let userDefaults = UserDefaults.standard
        
        if let data = userDefaults.data(forKey: "worldMap") {
            
            print(data)
            
            guard let worldMap = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) else {
                return
            }
            
            for anchor in worldMap.anchors {
                let anchorEntity = AnchorEntity(anchor: anchor)
                let box = ModelEntity(mesh: MeshResource.generateBox(size: 0.1), materials: [SimpleMaterial(color: .green, isMetallic: true)])
                
                //this allows us to interact with entity
                box.generateCollisionShapes(recursive: true)
                
                anchorEntity.addChild(box)
                arView.scene.addAnchor(anchorEntity)
                
                //install basic translation, rotation, and scale gestures to our model
                arView.installGestures(for: box)
                
            }
            
            
            let configuration = ARWorldTrackingConfiguration()
            configuration.initialWorldMap = worldMap
            configuration.planeDetection = .horizontal
            
            arView.session.run(configuration)
            
            
        }
        
    }
    
    func saveWorldMap() {
        
        guard let arView = arView else {
            return
        }
        
        arView.session.getCurrentWorldMap { [weak self] worldMap, error in
           
            if let error = error {
                print(error)
                return
            }
            
            if let worldMap = worldMap {
                
                guard let data = try? NSKeyedArchiver.archivedData(withRootObject: worldMap, requiringSecureCoding: true) else {
                    return
                }
                
                let userDefaults = UserDefaults.standard
                userDefaults.set(data, forKey: "worldMap")
                userDefaults.synchronize() // leave out synchronize, it will be saved on its own
                
                self?.vm.isSaved = true
                
            }
        }
        
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        
        switch frame.worldMappingStatus {
            case .notAvailable:
                vm.worldMapStatus = .notAvailable
            case .limited:
                vm.worldMapStatus = .limited
            case .extending:
                vm.worldMapStatus = .extending
            case .mapped:
                vm.worldMapStatus = .mapped
            @unknown default:
                fatalError()
        }
    }
}
