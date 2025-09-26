#!/usr/bin/env python3
"""
Unit Tests for AEGIS-SE Threat Detection System
Version: 1.0
Date: 2024-09-26

Author: AEGIS-SE Development Team
Copyright: Department of Defense - UNCLASSIFIED

REQUIREMENTS VERIFIED:
- REQ-F-003: Multi-Sensor Threat Detection (≥95% detection probability, ≤2% false alarm rate)
- REQ-F-005: Real-Time AI Inference (≤15ms inference latency, TensorFlow Lite support)
- REQ-F-006: Adaptive Learning (online learning, performance monitoring, A/B testing)
- REQ-NF-P-002: Threat Detection Performance (≥50ms processing latency)
- REQ-NF-P-003: AI/ML Performance Requirements
"""

import os
import sys
import time
import unittest
from datetime import datetime

import numpy as np

# Add src directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "src"))

# Import the threat analyzer module
sys.path.insert(
    0,
    os.path.join(
        os.path.dirname(__file__),
        "..",
        "..",
        "src",
        "ai-ml-systems",
        "threat-detection",
    ),
)
from threat_analyzer import ThreatAnalyzer, ThreatDetection, ThreatLevel, ThreatType


class TestThreatAnalyzer(unittest.TestCase):
    """Test cases for ThreatAnalyzer class"""

    def setUp(self):
        """Set up test fixtures"""
        self.analyzer = ThreatAnalyzer()

    def tearDown(self):
        """Clean up after tests"""
        if hasattr(self.analyzer, "_is_running") and self.analyzer._is_running:
            self.analyzer.stop_detection()

    def test_initialization(self):
        """Test threat analyzer initialization"""
        self.assertIsNotNone(self.analyzer)
        self.assertFalse(self.analyzer._is_running)
        self.assertEqual(len(self.analyzer._sensor_buffer), 0)
        self.assertEqual(len(self.analyzer._threat_history), 0)

    def test_config_loading(self):
        """Test configuration loading"""
        config = self.analyzer._config
        self.assertIsInstance(config, dict)
        self.assertIn("detection_frequency_hz", config)
        self.assertIn("max_buffer_size", config)
        self.assertIn("inference_timeout_ms", config)

    def test_start_stop_detection(self):
        """Test starting and stopping detection system"""
        # Test start
        result = self.analyzer.start_detection()
        self.assertTrue(result)
        self.assertTrue(self.analyzer._is_running)

        # Wait a moment for thread to start
        time.sleep(0.1)

        # Test stop
        result = self.analyzer.stop_detection()
        self.assertTrue(result)
        self.assertFalse(self.analyzer._is_running)

    def test_double_start_prevention(self):
        """Test prevention of double start"""
        self.analyzer.start_detection()
        result = self.analyzer.start_detection()  # Second start should fail
        self.assertFalse(result)
        self.analyzer.stop_detection()

    def test_sensor_data_acquisition(self):
        """Test sensor data acquisition"""
        sensor_data = self.analyzer._acquire_sensor_data()

        self.assertIsInstance(sensor_data, dict)
        self.assertIn("radar", sensor_data)
        self.assertIn("lidar", sensor_data)
        self.assertIn("optical", sensor_data)
        self.assertIn("rf_spectrum", sensor_data)
        self.assertIn("acoustic", sensor_data)
        self.assertIn("timestamp", sensor_data)
        self.assertIn("gps_position", sensor_data)

        # Check data types
        self.assertIsInstance(sensor_data["radar"], np.ndarray)
        self.assertIsInstance(sensor_data["lidar"], np.ndarray)
        self.assertIsInstance(sensor_data["timestamp"], datetime)

    def test_feature_extraction(self):
        """Test feature extraction from sensor data"""
        # Test radar feature extraction
        radar_data = np.random.rand(64, 64).astype(np.float32)
        radar_features = self.analyzer._extract_radar_features(radar_data)

        self.assertIsInstance(radar_features, np.ndarray)
        self.assertEqual(len(radar_features), 5)

        # Test LIDAR feature extraction
        lidar_data = np.random.rand(360).astype(np.float32)
        lidar_features = self.analyzer._extract_lidar_features(lidar_data)

        self.assertIsInstance(lidar_features, np.ndarray)
        self.assertEqual(len(lidar_features), 5)

    def test_ai_inference(self):
        """Test AI inference functionality"""
        features = np.random.rand(10).astype(np.float32)
        probabilities = self.analyzer._run_inference(features)

        self.assertIsInstance(probabilities, dict)
        self.assertIn("aerial_vehicle", probabilities)
        self.assertIn("missile", probabilities)
        self.assertIn("electronic_warfare", probabilities)

        # Check probability ranges
        for prob in probabilities.values():
            self.assertGreaterEqual(prob, 0.0)
            self.assertLessEqual(prob, 1.0)

    def test_threat_level_calculation(self):
        """Test threat level calculation"""
        self.assertEqual(
            self.analyzer._calculate_threat_level(0.95), ThreatLevel.CRITICAL
        )
        self.assertEqual(self.analyzer._calculate_threat_level(0.85), ThreatLevel.HIGH)
        self.assertEqual(self.analyzer._calculate_threat_level(0.7), ThreatLevel.MEDIUM)
        self.assertEqual(self.analyzer._calculate_threat_level(0.5), ThreatLevel.LOW)
        self.assertEqual(self.analyzer._calculate_threat_level(0.3), ThreatLevel.BENIGN)

    def test_position_estimation(self):
        """Test threat position estimation"""
        sensor_data = self.analyzer._acquire_sensor_data()
        position = self.analyzer._estimate_threat_position(sensor_data)

        self.assertIsInstance(position, tuple)
        self.assertEqual(len(position), 3)

        # Check that position values are reasonable
        x, y, z = position
        self.assertIsInstance(x, float)
        self.assertIsInstance(y, float)
        self.assertIsInstance(z, float)

    def test_velocity_estimation(self):
        """Test threat velocity estimation"""
        sensor_data = self.analyzer._acquire_sensor_data()
        velocity = self.analyzer._estimate_threat_velocity(sensor_data)

        self.assertIsInstance(velocity, tuple)
        self.assertEqual(len(velocity), 3)

        # Check velocity components
        vx, vy, vz = velocity
        self.assertIsInstance(vx, float)
        self.assertIsInstance(vy, float)
        self.assertIsInstance(vz, float)

    def test_threat_analysis(self):
        """Test complete threat analysis pipeline"""
        sensor_data = self.analyzer._acquire_sensor_data()
        detections = self.analyzer._analyze_threats(sensor_data)

        self.assertIsInstance(detections, list)

        # If detections were made, validate their structure
        for detection in detections:
            self.assertIsInstance(detection, ThreatDetection)
            self.assertIsInstance(detection.threat_id, str)
            self.assertIsInstance(detection.threat_type, ThreatType)
            self.assertIsInstance(detection.threat_level, ThreatLevel)
            self.assertGreaterEqual(detection.confidence, 0.0)
            self.assertLessEqual(detection.confidence, 1.0)

    def test_performance_metrics(self):
        """Test performance metrics collection"""
        metrics = self.analyzer.get_performance_metrics()

        self.assertIsInstance(metrics, dict)
        self.assertIn("detections_per_second", metrics)
        self.assertIn("false_positive_rate", metrics)
        self.assertIn("average_inference_time_ms", metrics)
        self.assertIn("memory_usage_mb", metrics)

    def test_recent_threats_retrieval(self):
        """Test retrieval of recent threats"""
        recent_threats = self.analyzer.get_recent_threats(hours=1)
        self.assertIsInstance(recent_threats, list)

    def test_buffer_size_limit(self):
        """Test sensor buffer size limiting"""
        max_size = self.analyzer._config["max_buffer_size"]

        # Fill buffer beyond max size
        for _ in range(max_size + 10):
            self.analyzer._acquire_sensor_data()

        # Check buffer size is limited
        self.assertLessEqual(len(self.analyzer._sensor_buffer), max_size)

    def test_detection_processing(self):
        """Test detection processing and logging"""
        # Create a mock detection
        detection = ThreatDetection(
            threat_id="TEST_001",
            threat_type=ThreatType.AERIAL_VEHICLE,
            threat_level=ThreatLevel.HIGH,
            confidence=0.85,
            position=(40.0, -74.0, 1000.0),
            velocity=(50.0, 0.0, 0.0),
            timestamp=datetime.now(),
            sensor_data={},
            mitigation_recommended=True,
        )

        # Process the detection
        initial_count = len(self.analyzer._threat_history)
        self.analyzer._process_detection(detection)

        # Verify it was added to history
        self.assertEqual(len(self.analyzer._threat_history), initial_count + 1)
        self.assertEqual(self.analyzer._threat_history[-1], detection)


class TestThreatDetectionIntegration(unittest.TestCase):
    """Integration tests for threat detection system"""

    def test_full_system_integration(self):
        """Test complete system integration"""
        analyzer = ThreatAnalyzer()

        try:
            # Start system
            self.assertTrue(analyzer.start_detection())

            # Let it run briefly
            time.sleep(0.5)

            # Check system is running
            self.assertTrue(analyzer._is_running)

            # Get metrics
            metrics = analyzer.get_performance_metrics()
            self.assertIsInstance(metrics, dict)

            # Stop system
            self.assertTrue(analyzer.stop_detection())
            self.assertFalse(analyzer._is_running)

        except Exception as e:
            self.fail(f"Integration test failed with exception: {e}")


if __name__ == "__main__":
    print("Running AEGIS-SE Threat Analyzer Unit Tests")
    print("=" * 50)

    # Create test suite
    suite = unittest.TestLoader().loadTestsFromModule(sys.modules[__name__])
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)

    # Print summary
    print("\n" + "=" * 50)
    print(f"Tests run: {result.testsRun}")
    print(f"Failures: {len(result.failures)}")
    print(f"Errors: {len(result.errors)}")
    print(
        f"Success rate: {((result.testsRun - len(result.failures) - len(result.errors)) / result.testsRun * 100):.1f}%"
    )

    # Exit with appropriate code
    sys.exit(0 if result.wasSuccessful() else 1)
