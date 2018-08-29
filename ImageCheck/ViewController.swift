//
//  ViewController.swift
//  ImageCheck
//
//  Created by Desmond Koh on 21/8/18.
//  Copyright © 2018 Desmond Koh. All rights reserved.
//

import UIKit
import AVKit
import Vision
import ImageIO

//laksa_curry_noodles_tom_yum_noodle_soup

class ViewController: UIViewController
{
    
    //MARK: - Outlets
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var imageName: UILabel!
    @IBOutlet weak var imageAccuracy: UILabel!
    @IBOutlet weak var cameraButton: UIButton!
    @IBOutlet weak var realTimeButton: UIButton!
    var session = AVCaptureSession()
    
    // MARK: - lifecycles
    override func viewDidLoad() {
        super.viewDidLoad()
        //Configures AVCaptureSession

    }
    
    // MARK: - CoreML Model Setup
    lazy var classificationModelRequest: VNCoreMLRequest =
    {
        do
        {
            //Core ML automatically generates a Swift class that provides easy access to your ML model
            let model = try VNCoreMLModel(for: ImageClassifier().model)
            // Creates a request using the model declared above
            
            //
            let request = VNCoreMLRequest(model: model, completionHandler: { [weak self] request, error in
                self?.processClassifications(for: request, error: error)
            })
            request.imageCropAndScaleOption = .centerCrop
            return request
        } catch { fatalError("Failed to load Vision ML model: \(error)") }
    }()
    
    
    // MARK: - CoreML
    // Tells the delegate when a new frame is created from the live view
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection)
    {
        // Creates a pixel buffer from the passed in media (from the delegate)
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        //create a classification Request
        let request = classificationModelRequest
        // Attempts to process the image for Classification
        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:]).perform([request])
    }
    
    //Updates for selected images
    func updateClassifications(for image: UIImage)
    {
        imageName.text = "Classifying..."
        //correct orientations
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        guard let ciImage = CIImage(image: image) else { fatalError("Unable to create \(CIImage.self) from \(image).") }
        
        DispatchQueue.global(qos: .userInitiated).async
            {
                let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation)
                do { try handler.perform([self.classificationModelRequest]) }
                catch { print("Failed to perform classification.\n\(error.localizedDescription)") }
        }
    }
    
    /// Updates the UI with the results of the classification from request
    func processClassifications(for request: VNRequest, error: Error?)
    {
        DispatchQueue.main.async
            {
                guard let results = request.results else {
                    self.imageName.text = "Unable to classify image."
                    return
                }
                
                let observation = results as! [VNClassificationObservation]
                
                if observation.isEmpty { self.imageName.text = "Nothing recognized." }
                else
                {
                    // Assigns the first result (if it exists) to firstObject
                    guard let firstObject = observation.first else
                    {
                        self.imageName.text = "Unable to classify image.\n\(error!.localizedDescription)"
                        return
                    }
                    
                    // Displays the label on screen
                    self.imageName.text = firstObject.identifier.capitalized
                    // Displays the confidence on screen
                    self.imageAccuracy.text = String(format: "Accuracy:  %.2f%%", firstObject.confidence * 100)
                    print(firstObject.identifier.capitalized)
                }
        }
    }
    
    // MARK: -  Image IO Actions
    @IBAction func takePicture()
    {
        // Show options for the source picker only if the camera is available.
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else
        {
            presentPhotoPicker(sourceType: .photoLibrary); return
        }
        
        let photoSourcePicker = UIAlertController()
        let takePhoto = UIAlertAction(title: "Take Photo", style: .default)
        {   [unowned self] _ in
            self.presentPhotoPicker(sourceType: .camera)
        }
        let choosePhoto = UIAlertAction(title: "Choose Photo", style: .default)
        {   [unowned self] _ in
            self.presentPhotoPicker(sourceType: .photoLibrary)
        }
        
        photoSourcePicker.addAction(takePhoto)
        photoSourcePicker.addAction(choosePhoto)
        photoSourcePicker.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(photoSourcePicker, animated: true)
    }
    
    //real time scanning of food images
    @IBAction func realTimeScanning()
    {
        
        if session.isRunning {
            session.stopRunning();
            imageView.layer.sublayers = nil;
            session = AVCaptureSession()
            self.imageName.text = "What is the image?"
            self.imageAccuracy.text = "Accuracy"
            
        }
        else { configureAVSession();session.startRunning() }
    }
    
    //check if camera is available
    func presentPhotoPicker(sourceType: UIImagePickerController.SourceType)
    {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = sourceType
        present(picker, animated: true)
    }

}


// MARK: - AVKit
extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    // Configures AVCaptureSession
    func configureAVSession() {
    // Checks if camera exist on current device
    guard let device = AVCaptureDevice.default(for: .video) else { return }
    
    // Creates an AVCaptureDeviceInput (camera input) from device
    guard let deviceInput = try? AVCaptureDeviceInput(device: device) else { return }
    
    // Creates an AVCaptureSession
    
    //session.sessionPreset = .hd4K3840x2160 // Sets bitrate and quality to UHD
    session.sessionPreset = .hd1920x1080 // Sets bitrate and quality to FHD
    //session.sessionPreset = .hd1280x720 // Sets bitrate and quality to HD
    
    // Creates a layer for input to view
    let previewLayer = AVCaptureVideoPreviewLayer(session: session)
    previewLayer.frame = view.frame //use the view size for full screen
    imageView.layer.addSublayer(previewLayer) //Add layer to imageView
    
    // Creates an instance of AVCaptureVideoDataOutput()
    let output = AVCaptureVideoDataOutput()
    output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "queue"))
    
    //add AVCaptureVideoDataOutput to  AVCaptureSession
    session.addOutput(output)
    
    //add AVCaptureDeviceInput to  AVCaptureSession
    session.addInput(deviceInput)

    // run session!
    //session.startRunning()
}
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    // MARK: - Handling Image Picker Selection
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        
        // We always expect `imagePickerController(:didFinishPickingMediaWithInfo:)` to supply the original image.
        let image = info[UIImagePickerController.InfoKey.originalImage] as! UIImage
        imageView.image = image
        updateClassifications(for: image)
    }
}

extension CGImagePropertyOrientation{
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        }
    }
}

