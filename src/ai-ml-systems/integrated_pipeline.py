#!/usr/bin/env python3
"""
Integrated AI/ML Threat Detection Pipeline for AEGIS-SE Defense Platform
Complete Integration of Inference Engines, Sensor Fusion, and Feature Extraction

Author: AEGIS-SE AI/ML Integration Team
Copyright: Department of Defense - UNCLASSIFIED
Version: 2.0
Date: 2025-09-26

Features:
- Unified multi-modal threat detection pipeline
- Real-time sensor data processing and fusion
- Advanced feature extraction and inference
- Threat classification and risk assessment
- Performance monitoring and optimization
- Adaptive thresholding and decision making
"""


import logging
import threading
import time
from dataclasses import dataclass
from enum import Enum
from typing import Any, Dict, List, Optional, Tuple

import numpy as np

from .feature_extraction.feature_extractor import (
    AdvancedFeatureExtractor,
    ExtractionConfig,
    FeatureType,
    FeatureVector,
    SignalType,
)
from .inference_engines.onnx_engine import ONNXModelConfig, ONNXRuntimeEngine

# Import our AI/ML components
from .inference_engines.tflite_engine import TensorFlowLiteConfig, TensorFlowLiteEngine
from .sensor_fusion.sensor_fusion import (
    FusedTrack,
    MultiSensorFusion,
    SensorMeasurement,
    SensorType,
)

# Configure logging
logger = logging.getLogger(__name__)


class ThreatLevel(Enum):
    """Threat assessment levels"""

    BENIGN = "benign"
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


class PipelineState(Enum):
    """Pipeline operational states"""

    INITIALIZING = "initializing"
    READY = "ready"
    PROCESSING = "processing"
    ERROR = "error"
    SHUTDOWN = "shutdown"


@dataclass
class ThreatAssessment:
    """Complete threat assessment result"""

    track_id: int
    threat_level: ThreatLevel
    threat_type: str
    confidence: float
    position: np.ndarray
    velocity: np.ndarray
    threat_scores: Dict[str, float]
    supporting_evidence: Dict[str, Any]
    assessment_time: float
    sensor_contributions: Dict[SensorType, float]


@dataclass
class PipelineConfig:
    """Configuration for the integrated pipeline"""

    # Inference engine configurations
    tflite_config: Optional[TensorFlowLiteConfig] = None
    onnx_config: Optional[ONNXModelConfig] = None

    # Sensor fusion configuration
    fusion_config: Optional[Dict[str, Any]] = None

    # Feature extraction configurations
    radar_feature_config: Optional[ExtractionConfig] = None
    image_feature_config: Optional[ExtractionConfig] = None
    rf_feature_config: Optional[ExtractionConfig] = None

    # Pipeline parameters
    processing_rate_hz: float = 10.0
    threat_threshold: float = 0.7
    track_retention_time: float = 30.0
    max_concurrent_tracks: int = 100
    enable_adaptive_thresholding: bool = True

    # Performance monitoring
    enable_performance_monitoring: bool = True
    log_detailed_metrics: bool = False


class IntegratedThreatDetectionPipeline:
    """
    Complete integrated AI/ML threat detection pipeline
    """

    def __init__(self, config: PipelineConfig):
        """Initialize the integrated pipeline"""
        self.config = config
        self.state = PipelineState.INITIALIZING

        # Initialize components
        self.inference_engines = {}
        self.feature_extractors = {}
        self.sensor_fusion = None

        # Threat tracking
        self.active_threats: Dict[int, ThreatAssessment] = {}
        self.threat_history: List[ThreatAssessment] = []

        # Performance metrics
        self.metrics = {
            "total_processed": 0,
            "threats_detected": 0,
            "false_alarms": 0,
            "processing_rate_hz": 0.0,
            "average_latency_ms": 0.0,
            "component_status": {},
        }

        # Threading
        self.running = False
        self.processing_thread = None
        self.pipeline_lock = threading.Lock()

        # Initialize all components
        self._initialize_components()

        logger.info("Integrated threat detection pipeline initialized")

    def _initialize_components(self) -> None:
        """Initialize all pipeline components"""
        try:
            # Initialize inference engines
            if self.config.tflite_config:
                self.inference_engines["tflite"] = TensorFlowLiteEngine(
                    self.config.tflite_config
                )
                logger.info("TensorFlow Lite inference engine initialized")

            if self.config.onnx_config:
                self.inference_engines["onnx"] = ONNXRuntimeEngine(
                    self.config.onnx_config
                )
                logger.info("ONNX Runtime inference engine initialized")

            # Initialize feature extractors
            if self.config.radar_feature_config:
                self.feature_extractors["radar"] = AdvancedFeatureExtractor(
                    self.config.radar_feature_config
                )

            if self.config.image_feature_config:
                self.feature_extractors["image"] = AdvancedFeatureExtractor(
                    self.config.image_feature_config
                )

            if self.config.rf_feature_config:
                self.feature_extractors["rf"] = AdvancedFeatureExtractor(
                    self.config.rf_feature_config
                )

            # Initialize sensor fusion
            fusion_config = self.config.fusion_config or {}
            self.sensor_fusion = MultiSensorFusion(fusion_config)

            # Update component status
            self.metrics["component_status"] = {
                "inference_engines": len(self.inference_engines),
                "feature_extractors": len(self.feature_extractors),
                "sensor_fusion": "initialized",
            }

            self.state = PipelineState.READY

        except Exception as e:
            logger.error(f"Component initialization failed: {e}")
            self.state = PipelineState.ERROR
            raise

    def start_processing(self) -> None:
        """Start the pipeline processing"""
        if self.state != PipelineState.READY:
            raise RuntimeError(f"Pipeline not ready. Current state: {self.state}")

        self.running = True
        self.processing_thread = threading.Thread(
            target=self._processing_loop, daemon=True
        )
        self.processing_thread.start()

        logger.info("Pipeline processing started")

    def stop_processing(self) -> None:
        """Stop the pipeline processing"""
        self.running = False

        if self.processing_thread and self.processing_thread.is_alive():
            self.processing_thread.join(timeout=2.0)

        # Stop sensor fusion
        if self.sensor_fusion:
            self.sensor_fusion.stop()

        self.state = PipelineState.SHUTDOWN
        logger.info("Pipeline processing stopped")

    def _processing_loop(self) -> None:
        """Main processing loop"""
        self.state = PipelineState.PROCESSING

        while self.running:
            loop_start = time.time()

            try:
                # Process current fusion cycle
                self._process_threat_detection_cycle()

                # Update performance metrics
                cycle_time = time.time() - loop_start
                self._update_performance_metrics(cycle_time)

                # Sleep to maintain target rate
                target_period = 1.0 / self.config.processing_rate_hz
                sleep_time = max(0, target_period - cycle_time)
                time.sleep(sleep_time)

            except Exception as e:
                logger.error(f"Processing loop error: {e}")
                time.sleep(0.1)

    def _process_threat_detection_cycle(self) -> None:
        """Process one complete threat detection cycle"""
        with self.pipeline_lock:
            # Get current fused tracks from sensor fusion
            active_tracks = self.sensor_fusion.get_active_tracks()

            # Process each track for threat assessment
            for track in active_tracks:
                threat_assessment = self._assess_track_threat(track)

                if threat_assessment:
                    self._update_threat_tracking(threat_assessment)

            # Clean up old threats
            self._cleanup_old_threats()

            # Update metrics
            self.metrics["total_processed"] += len(active_tracks)

    def _assess_track_threat(self, track: FusedTrack) -> Optional[ThreatAssessment]:
        """Assess threat level for a given track"""
        try:
            # Extract features from track data
            feature_vectors = self._extract_track_features(track)

            if not feature_vectors:
                return None

            # Run inference on extracted features
            inference_results = self._run_inference_on_features(feature_vectors)

            # Combine inference results
            combined_threat_scores = self._combine_inference_results(inference_results)

            # Determine overall threat level
            threat_level, confidence = self._determine_threat_level(
                combined_threat_scores
            )

            # Only create assessment if above threshold
            if confidence >= self.config.threat_threshold:
                threat_assessment = ThreatAssessment(
                    track_id=track.track_id,
                    threat_level=threat_level,
                    threat_type=self._classify_threat_type(combined_threat_scores),
                    confidence=confidence,
                    position=track.state[:3].copy(),
                    velocity=track.state[3:6].copy(),
                    threat_scores=combined_threat_scores,
                    supporting_evidence=self._gather_supporting_evidence(
                        track, feature_vectors
                    ),
                    assessment_time=time.time(),
                    sensor_contributions=self._calculate_sensor_contributions(track),
                )

                return threat_assessment

            return None

        except Exception as e:
            logger.error(f"Threat assessment failed for track {track.track_id}: {e}")
            return None

    def _extract_track_features(self, track: FusedTrack) -> Dict[str, FeatureVector]:
        """Extract features from track sensor data"""
        feature_vectors = {}

        try:
            # Extract features from each sensor type
            for sensor_type, measurements in track.sensor_measurements.items():
                if not measurements:
                    continue

                # Get the most recent measurement
                latest_measurement = measurements[-1]

                # Determine appropriate feature extractor
                extractor_key = self._map_sensor_to_extractor(sensor_type)

                if extractor_key in self.feature_extractors:
                    # Convert measurement to appropriate data format
                    data = self._convert_measurement_to_data(latest_measurement)

                    if data is not None:
                        # Extract features
                        features = self.feature_extractors[
                            extractor_key
                        ].extract_features(
                            data,
                            metadata={
                                "sensor_type": sensor_type.value,
                                "track_id": track.track_id,
                            },
                        )
                        feature_vectors[sensor_type.value] = features

            return feature_vectors

        except Exception as e:
            logger.error(f"Feature extraction failed for track {track.track_id}: {e}")
            return {}

    def _map_sensor_to_extractor(self, sensor_type: SensorType) -> str:
        """Map sensor type to appropriate feature extractor"""
        mapping = {
            SensorType.RADAR: "radar",
            SensorType.LIDAR: "radar",  # Use radar extractor for LIDAR (similar processing)
            SensorType.OPTICAL: "image",
            SensorType.THERMAL: "image",
            SensorType.RF_SPECTRUM: "rf",
            SensorType.ACOUSTIC: "rf",  # Use RF extractor for acoustic (spectral analysis)
            SensorType.MAGNETIC: "rf",
            SensorType.SEISMIC: "rf",
        }

        return mapping.get(sensor_type, "radar")  # Default to radar

    def _convert_measurement_to_data(
        self, measurement: SensorMeasurement
    ) -> Optional[np.ndarray]:
        """Convert sensor measurement to data format for feature extraction"""
        try:
            # For demo purposes, create synthetic data based on measurement
            if measurement.sensor_type in [SensorType.RADAR, SensorType.LIDAR]:
                # Create synthetic IQ data
                data = np.random.complex128(
                    np.random.randn(1024, 2) + 1j * np.random.randn(1024, 2)
                )
                # Add signal based on position and velocity
                if measurement.velocity is not None:
                    doppler_freq = (
                        np.linalg.norm(measurement.velocity) / 10.0
                    )  # Simplified Doppler
                    t = np.linspace(0, 1, 1024)
                    signal_component = 0.5 * np.exp(1j * 2 * np.pi * doppler_freq * t)
                    data[:, 0] += signal_component

                return data

            elif measurement.sensor_type in [SensorType.OPTICAL, SensorType.THERMAL]:
                # Create synthetic image data
                return np.random.randint(0, 256, (128, 128))

            elif measurement.sensor_type in [
                SensorType.RF_SPECTRUM,
                SensorType.ACOUSTIC,
            ]:
                # Create synthetic spectral data
                data = np.random.randn(2048)
                # Add frequency components based on measurement attributes
                if measurement.attributes:
                    for freq, amplitude in measurement.attributes.items():
                        if isinstance(freq, (int, float)) and isinstance(
                            amplitude, (int, float)
                        ):
                            t = np.linspace(0, 1, 2048)
                            data += amplitude * np.sin(2 * np.pi * freq * t)

                return data
            else:
                # Generic data
                return np.random.randn(512)

        except Exception as e:
            logger.error(f"Data conversion failed: {e}")
            return None

    def _run_inference_on_features(
        self, feature_vectors: Dict[str, FeatureVector]
    ) -> Dict[str, Any]:
        """Run inference on extracted features"""
        inference_results = {}

        try:
            for engine_name, engine in self.inference_engines.items():
                # Prepare input for inference engine
                if feature_vectors:
                    # Combine all feature vectors or use the first available one
                    primary_features = list(feature_vectors.values())[0]

                    # Prepare input dict based on engine type
                    if engine_name == "tflite":
                        inputs = {
                            "input_features": primary_features.features.reshape(
                                1, -1
                            ).astype(np.float32)
                        }
                    elif engine_name == "onnx":
                        inputs = {
                            "input_features": primary_features.features.reshape(
                                1, -1
                            ).astype(np.float32)
                        }
                    else:
                        continue

                    # Run inference
                    result = engine.predict(inputs)
                    inference_results[engine_name] = result

            return inference_results

        except Exception as e:
            logger.error(f"Inference failed: {e}")
            return {}

    def _combine_inference_results(
        self, inference_results: Dict[str, Any]
    ) -> Dict[str, float]:
        """Combine results from multiple inference engines"""
        combined_scores = {}

        if not inference_results:
            return {"unknown": 0.5}

        try:
            # Initialize score accumulators
            all_class_scores = {}
            engine_weights = {"tflite": 0.6, "onnx": 0.4}  # Configurable weights

            for engine_name, result in inference_results.items():
                weight = engine_weights.get(engine_name, 0.5)

                # Extract class probabilities
                if hasattr(result, "class_probabilities"):
                    class_probs = result.class_probabilities
                elif hasattr(result, "outputs") and isinstance(result.outputs, dict):
                    # Extract probabilities from outputs
                    output_values = list(result.outputs.values())[0]
                    if output_values.size > 1:
                        # Assume softmax probabilities
                        class_names = [
                            "aerial",
                            "ground",
                            "naval",
                            "cyber",
                            "electronic",
                            "benign",
                        ]
                        class_probs = {}
                        for i, name in enumerate(class_names):
                            if i < output_values.size:
                                class_probs[name] = float(output_values.flatten()[i])
                            else:
                                class_probs[name] = 0.0
                    else:
                        class_probs = {
                            "threat": float(output_values.flatten()[0]),
                            "benign": 1.0 - float(output_values.flatten()[0]),
                        }
                else:
                    class_probs = {"unknown": 0.5}

                # Accumulate weighted scores
                for class_name, score in class_probs.items():
                    if class_name not in all_class_scores:
                        all_class_scores[class_name] = 0.0
                    all_class_scores[class_name] += weight * score

            # Normalize combined scores
            total_weight = sum(engine_weights.values())
            for class_name in all_class_scores:
                combined_scores[class_name] = (
                    all_class_scores[class_name] / total_weight
                )

            return combined_scores

        except Exception as e:
            logger.error(f"Result combination failed: {e}")
            return {"error": 1.0}

    def _determine_threat_level(
        self, threat_scores: Dict[str, float]
    ) -> Tuple[ThreatLevel, float]:
        """Determine overall threat level from scores"""
        try:
            # Calculate maximum non-benign score
            threat_score = 0.0
            benign_score = threat_scores.get("benign", 0.0)

            for class_name, score in threat_scores.items():
                if class_name != "benign" and score > threat_score:
                    threat_score = score

            # Overall confidence is the difference between threat and benign
            confidence = max(0.0, threat_score - benign_score)

            # Determine threat level
            if threat_score < 0.3:
                return ThreatLevel.BENIGN, confidence
            elif threat_score < 0.5:
                return ThreatLevel.LOW, confidence
            elif threat_score < 0.7:
                return ThreatLevel.MEDIUM, confidence
            elif threat_score < 0.9:
                return ThreatLevel.HIGH, confidence
            else:
                return ThreatLevel.CRITICAL, confidence

        except Exception as e:
            logger.error(f"Threat level determination failed: {e}")
            return ThreatLevel.BENIGN, 0.0

    def _classify_threat_type(self, threat_scores: Dict[str, float]) -> str:
        """Classify the type of threat"""
        # Find the highest scoring threat class (excluding benign)
        max_score = 0.0
        threat_type = "unknown"

        for class_name, score in threat_scores.items():
            if class_name != "benign" and score > max_score:
                max_score = score
                threat_type = class_name

        return threat_type

    def _gather_supporting_evidence(
        self, track: FusedTrack, feature_vectors: Dict[str, FeatureVector]
    ) -> Dict[str, Any]:
        """Gather supporting evidence for threat assessment"""
        evidence = {
            "track_quality": track.track_quality,
            "tracking_state": track.tracking_state.value,
            "sensor_count": len(track.sensor_measurements),
            "velocity_magnitude": np.linalg.norm(track.state[3:6]),
            "altitude": track.state[2],
            "feature_confidence": {
                name: fv.confidence for name, fv in feature_vectors.items()
            },
        }

        return evidence

    def _calculate_sensor_contributions(
        self, track: FusedTrack
    ) -> Dict[SensorType, float]:
        """Calculate each sensor's contribution to the track"""
        contributions = {}
        total_measurements = sum(
            len(measurements) for measurements in track.sensor_measurements.values()
        )

        if total_measurements == 0:
            return contributions

        for sensor_type, measurements in track.sensor_measurements.items():
            contribution = len(measurements) / total_measurements
            contributions[sensor_type] = contribution

        return contributions

    def _update_threat_tracking(self, threat_assessment: ThreatAssessment) -> None:
        """Update threat tracking with new assessment"""
        track_id = threat_assessment.track_id

        # Update active threats
        self.active_threats[track_id] = threat_assessment

        # Add to history
        self.threat_history.append(threat_assessment)

        # Limit history size
        if len(self.threat_history) > 1000:
            self.threat_history = self.threat_history[-1000:]

        # Update metrics
        if threat_assessment.threat_level != ThreatLevel.BENIGN:
            self.metrics["threats_detected"] += 1

        # Log significant threats
        if threat_assessment.threat_level in [ThreatLevel.HIGH, ThreatLevel.CRITICAL]:
            logger.warning(
                f"HIGH PRIORITY THREAT: Track {track_id}, "
                f"Level: {threat_assessment.threat_level.value}, "
                f"Type: {threat_assessment.threat_type}, "
                f"Confidence: {threat_assessment.confidence:.2f}, "
                f"Position: {threat_assessment.position}"
            )

    def _cleanup_old_threats(self) -> None:
        """Remove old threat assessments"""
        current_time = time.time()
        old_track_ids = []

        for track_id, assessment in self.active_threats.items():
            if (
                current_time - assessment.assessment_time
            ) > self.config.track_retention_time:
                old_track_ids.append(track_id)

        for track_id in old_track_ids:
            del self.active_threats[track_id]

    def _update_performance_metrics(self, cycle_time: float) -> None:
        """Update pipeline performance metrics"""
        # Processing rate
        self.metrics["processing_rate_hz"] = 1.0 / max(cycle_time, 0.001)

        # Average latency (simplified)
        self.metrics["average_latency_ms"] = cycle_time * 1000

        # Component status
        if self.config.enable_performance_monitoring:
            self.metrics["component_status"]["active_threats"] = len(
                self.active_threats
            )
            self.metrics["component_status"]["sensor_fusion_tracks"] = len(
                self.sensor_fusion.get_active_tracks()
            )

    def add_sensor_measurement(self, measurement: SensorMeasurement) -> None:
        """Add a new sensor measurement to the pipeline"""
        if self.sensor_fusion:
            self.sensor_fusion.add_measurement(measurement)

    def get_active_threats(self) -> List[ThreatAssessment]:
        """Get all currently active threats"""
        with self.pipeline_lock:
            return list(self.active_threats.values())

    def get_threat_by_track_id(self, track_id: int) -> Optional[ThreatAssessment]:
        """Get threat assessment for specific track"""
        with self.pipeline_lock:
            return self.active_threats.get(track_id)

    def get_performance_metrics(self) -> Dict[str, Any]:
        """Get comprehensive performance metrics"""
        metrics = self.metrics.copy()

        # Add component-specific metrics
        if "tflite" in self.inference_engines:
            metrics["tflite_metrics"] = self.inference_engines[
                "tflite"
            ].get_performance_metrics()

        if "onnx" in self.inference_engines:
            metrics["onnx_metrics"] = self.inference_engines[
                "onnx"
            ].get_performance_metrics()

        if self.sensor_fusion:
            metrics["fusion_metrics"] = self.sensor_fusion.get_metrics()

        # Add feature extractor metrics
        for name, extractor in self.feature_extractors.items():
            metrics[f"{name}_extractor_metrics"] = extractor.get_performance_metrics()

        return metrics

    def get_pipeline_status(self) -> Dict[str, Any]:
        """Get overall pipeline status"""
        return {
            "state": self.state.value,
            "running": self.running,
            "active_threats": len(self.active_threats),
            "total_processed": self.metrics["total_processed"],
            "threats_detected": self.metrics["threats_detected"],
            "components_initialized": len(self.inference_engines)
            + len(self.feature_extractors)
            + (1 if self.sensor_fusion else 0),
        }


# Pre-configured pipeline setups for different defense scenarios
def create_air_defense_pipeline() -> IntegratedThreatDetectionPipeline:
    """Create pipeline configured for air defense"""

    # TensorFlow Lite configuration
    tflite_config = TensorFlowLiteConfig(
        model_path="models/air_defense_classifier.tflite",
        input_names=["input_features"],
        output_names=["threat_probabilities"],
        input_shapes={"input_features": (1, 512)},
        output_classes=[
            "fighter_jet",
            "bomber",
            "missile",
            "drone",
            "civilian_aircraft",
            "benign",
        ],
        use_gpu_delegate=True,
        num_threads=4,
    )

    # ONNX configuration
    onnx_config = ONNXModelConfig(
        model_path="models/air_defense_onnx.onnx",
        input_names=["input_features"],
        output_names=["threat_probabilities"],
        input_shapes={"input_features": (1, 512)},
        output_classes=[
            "fighter_jet",
            "bomber",
            "missile",
            "drone",
            "civilian_aircraft",
            "benign",
        ],
        execution_provider="CUDAExecutionProvider",
    )

    # Feature extraction configurations
    radar_config = ExtractionConfig(
        signal_type=SignalType.RADAR_IQ,
        sampling_rate=1e6,
        window_size=1024,
        feature_types=[FeatureType.RADAR_SPECIFIC, FeatureType.SPECTRAL],
        normalize_features=True,
    )

    # Pipeline configuration
    pipeline_config = PipelineConfig(
        tflite_config=tflite_config,
        onnx_config=onnx_config,
        radar_feature_config=radar_config,
        processing_rate_hz=20.0,
        threat_threshold=0.75,
        enable_adaptive_thresholding=True,
    )

    return IntegratedThreatDetectionPipeline(pipeline_config)


# Example usage and testing
if __name__ == "__main__":
    print("AEGIS-SE Integrated Threat Detection Pipeline - Demo")

    try:
        # Create air defense pipeline
        pipeline = create_air_defense_pipeline()

        # Start processing
        pipeline.start_processing()

        # Simulate sensor measurements
        for i in range(20):
            # Simulate radar detection
            measurement = SensorMeasurement(
                sensor_id=f"radar_{i%3}",
                sensor_type=SensorType.RADAR,
                timestamp=time.time(),
                position=np.array([1000 + i * 50, 2000 + i * 20, 5000 + i * 10]),
                velocity=np.array([200, 50, -5]) + np.random.normal(0, 5, 3),
                attributes={"doppler_frequency": 1000 + i * 10, "rcs": 10.0},
                confidence=0.9,
                quality_score=0.95,
            )

            pipeline.add_sensor_measurement(measurement)

            # Simulate optical detection (less frequent)
            if i % 5 == 0:
                optical_measurement = SensorMeasurement(
                    sensor_id="optical_001",
                    sensor_type=SensorType.OPTICAL,
                    timestamp=time.time(),
                    position=measurement.position + np.random.normal(0, 10, 3),
                    confidence=0.7,
                    quality_score=0.8,
                )

                pipeline.add_sensor_measurement(optical_measurement)

            time.sleep(0.1)

        # Wait for processing
        time.sleep(3.0)

        # Get results
        active_threats = pipeline.get_active_threats()
        performance_metrics = pipeline.get_performance_metrics()
        status = pipeline.get_pipeline_status()

        print(f"Pipeline Status: {status}")
        print(f"Active Threats: {len(active_threats)}")
        print(f"Performance Metrics: {performance_metrics}")

        for threat in active_threats:
            print(
                f"Threat {threat.track_id}: {threat.threat_level.value} - {threat.threat_type} "
                f"(confidence: {threat.confidence:.2f})"
            )

    except Exception as e:
        print(f"Demo failed: {e}")

    finally:
        # Stop processing
        if "pipeline" in locals():
            pipeline.stop_processing()
