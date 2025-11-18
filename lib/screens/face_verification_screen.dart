import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import '../database/database_helper.dart';
import '../models/user_model.dart';
import '../service/face_verification_service.dart';
import '../navigation/bottom_nav.dart';

class FaceVerificationScreen extends StatefulWidget {
  final int userId;

  const FaceVerificationScreen({super.key, required this.userId});

  @override
  State<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen> {
  final dbHelper = DatabaseHelper.instance;
  final ImagePicker _picker = ImagePicker();

  UserModel? currentUser;
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool isCameraInitialized = false;
  bool isVerifying = false;
  File? capturedImage;
  String? verificationMessage;
  bool? isVerified;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final userData = await dbHelper.getUserById(widget.userId);
    if (userData != null) {
      setState(() {
        currentUser = UserModel.fromMap(userData);
      });
      print('Loaded user: ${currentUser!.name}, Photo: ${currentUser!.photoUrl}');
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();

      if (_cameras == null || _cameras!.isEmpty) {
        print('No cameras available');
        setState(() {
          verificationMessage = 'No camera available on this device';
          isCameraInitialized = false;
        });
        return;
      }

      print('Found ${_cameras!.length} cameras');

      // Try to use front camera first
      CameraDescription? frontCamera;
      CameraDescription? backCamera;

      for (var camera in _cameras!) {
        print('Camera: ${camera.name}, Direction: ${camera.lensDirection}');
        if (camera.lensDirection == CameraLensDirection.front) {
          frontCamera = camera;
        } else if (camera.lensDirection == CameraLensDirection.back) {
          backCamera = camera;
        }
      }

      // Prefer front camera for selfies
      final selectedCamera = frontCamera ?? backCamera ?? _cameras![0];
      print('Selected camera: ${selectedCamera.name}');

      _cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          isCameraInitialized = true;
          verificationMessage = 'Camera ready. Take a selfie to verify.';
        });
        print('Camera initialized successfully');
      }
    } catch (e) {
      print('Camera initialization error: $e');
      setState(() {
        verificationMessage = 'Camera error: $e';
        isCameraInitialized = false;
      });
    }
  }

  Future<void> _captureAndVerify() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera not ready')),
      );
      return;
    }

    setState(() {
      isVerifying = true;
      verificationMessage = 'Capturing image...';
      isVerified = null;
    });

    try {
      // Capture image
      print('Capturing image...');
      final XFile image = await _cameraController!.takePicture();
      final File imageFile = File(image.path);
      print('Image captured: ${image.path}');

      setState(() {
        capturedImage = imageFile;
        verificationMessage = 'Verifying your face...';
      });

      // Verify face
      print('Starting face verification...');
      final result = await FaceVerificationService.verifyFace(
        capturedImage: imageFile,
        profileImagePath: currentUser!.photoUrl ?? 'assets/images/placeholder.jpg',
      );

      print('Verification result: ${result['isVerified']}');

      setState(() {
        isVerified = result['isVerified'];
        verificationMessage = result['message'];
        isVerifying = false;
      });

      // If verified, update database and navigate
      if (result['isVerified']) {
        await dbHelper.updateFaceVerificationStatus(widget.userId, true);
        print('Face verification status updated in database');

        await Future.delayed(const Duration(seconds: 2));

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => BottomNav(userId: widget.userId),
            ),
          );
        }
      }
    } catch (e) {
      print('Error during capture/verification: $e');
      setState(() {
        verificationMessage = 'Error: $e';
        isVerifying = false;
        isVerified = false;
      });
    }
  }

  Future<void> _pickImageFromGallery() async {
    setState(() {
      isVerifying = true;
      verificationMessage = 'Loading image...';
      isVerified = null;
    });

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image == null) {
        setState(() {
          isVerifying = false;
          verificationMessage = 'No image selected';
        });
        return;
      }

      print('Image selected from gallery: ${image.path}');

      setState(() {
        capturedImage = File(image.path);
        verificationMessage = 'Verifying your face...';
      });

      final result = await FaceVerificationService.verifyFace(
        capturedImage: File(image.path),
        profileImagePath: currentUser!.photoUrl ?? 'assets/images/placeholder.jpg',
      );

      setState(() {
        isVerified = result['isVerified'];
        verificationMessage = result['message'];
        isVerifying = false;
      });

      if (result['isVerified']) {
        await dbHelper.updateFaceVerificationStatus(widget.userId, true);

        await Future.delayed(const Duration(seconds: 2));

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => BottomNav(userId: widget.userId),
            ),
          );
        }
      }
    } catch (e) {
      print('Error picking/verifying image: $e');
      setState(() {
        verificationMessage = 'Error: $e';
        isVerifying = false;
        isVerified = false;
      });
    }
  }

  void _retakePhoto() {
    setState(() {
      capturedImage = null;
      isVerified = null;
      verificationMessage = 'Camera ready. Take a selfie to verify.';
    });
  }

  void _skipVerification() {
    // For testing only - remove in production
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip Verification?'),
        content: const Text('This is for testing only. Skip face verification?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await dbHelper.updateFaceVerificationStatus(widget.userId, true);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => BottomNav(userId: widget.userId),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Skip'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Face Verification',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          // Debug button - remove in production
          IconButton(
            icon: const Icon(Icons.skip_next, color: Colors.grey),
            onPressed: _skipVerification,
            tooltip: 'Skip (Debug)',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Instructions
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(
                    Icons.face_retouching_natural,
                    size: 64,
                    color: Color(0xFFFF6B9D),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Verify Your Face',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Take a clear selfie to verify your identity',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // Camera Preview or Captured Image
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isVerified == true
                        ? Colors.green
                        : isVerified == false
                        ? Colors.red
                        : Colors.grey[300]!,
                    width: 3,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: capturedImage != null
                      ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(
                        capturedImage!,
                        fit: BoxFit.cover,
                      ),
                      if (isVerified != null)
                        Container(
                          color: (isVerified!
                              ? Colors.green
                              : Colors.red)
                              .withOpacity(0.2),
                          child: Center(
                            child: Icon(
                              isVerified!
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              size: 100,
                              color: isVerified!
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                        ),
                      if (isVerifying)
                        Container(
                          color: Colors.black.withOpacity(0.5),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  )
                      : isCameraInitialized
                      ? CameraPreview(_cameraController!)
                      : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                          color: Color(0xFFFF6B9D),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            verificationMessage ?? 'Initializing camera...',
                            style: TextStyle(color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Status Message
            if (verificationMessage != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isVerified == true
                      ? Colors.green[50]
                      : isVerified == false
                      ? Colors.red[50]
                      : Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isVerified == true
                        ? Colors.green
                        : isVerified == false
                        ? Colors.red
                        : Colors.blue[300]!,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isVerified == true
                          ? Icons.check_circle
                          : isVerified == false
                          ? Icons.error
                          : Icons.info,
                      color: isVerified == true
                          ? Colors.green
                          : isVerified == false
                          ? Colors.red
                          : Colors.blue[700],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        verificationMessage!,
                        style: TextStyle(
                          color: isVerified == true
                              ? Colors.green[900]
                              : isVerified == false
                              ? Colors.red[900]
                              : Colors.blue[900],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (capturedImage == null) ...[
                    // Capture Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isVerifying || !isCameraInitialized
                            ? null
                            : _captureAndVerify,
                        icon: isVerifying
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                            : const Icon(Icons.camera_alt),
                        label: Text(
                          isVerifying ? 'Verifying...' : 'Take Selfie',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B9D),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Gallery Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: isVerifying ? null : _pickImageFromGallery,
                        icon: const Icon(Icons.photo_library),
                        label: const Text(
                          'Choose from Gallery',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFF6B9D),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(
                            color: Color(0xFFFF6B9D),
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Retake Button
                    if (!isVerifying) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _retakePhoto,
                          icon: const Icon(Icons.refresh),
                          label: const Text(
                            'Retake Photo',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6B9D),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      if (isVerified == false) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _pickImageFromGallery,
                            icon: const Icon(Icons.photo_library),
                            label: const Text(
                              'Try Gallery Photo',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFFF6B9D),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(
                                color: Color(0xFFFF6B9D),
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}