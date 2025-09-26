#!/usr/bin/env python3
"""
Multi-Modal Sensor Fusion for AEGIS-SE Defense Platform
Advanced Data Integration and Threat Correlation

Author: AEGIS-SE Sensor Fusion Team
Copyright: Department of Defense - UNCLASSIFIED
Version: 2.0
Date: 2025-09-26

Features:
- Multi-sensor data fusion (Radar, LIDAR, Thermal, Optical, RF)
- Kalman filtering for state estimation
- Temporal correlation and tracking
- Uncertainty quantification
- Real-time data alignment and synchronization
- Adaptive filtering based on environmental conditions
"""

import logging
import threading
import time
from dataclasses import dataclass
from enum import Enum
from typing import Any, Dict, List, Optional, Tuple

import numpy as np

# Configure logging
logger = logging.getLogger(__name__)


class SensorType(Enum):
    """Enumeration of supported sensor types"""

    RADAR = "radar"
    LIDAR = "lidar"
    THERMAL = "thermal"
    OPTICAL = "optical"
    RF_SPECTRUM = "rf_spectrum"
    ACOUSTIC = "acoustic"
    MAGNETIC = "magnetic"
    SEISMIC = "seismic"


class TrackingState(Enum):
    """Object tracking states"""

    TENTATIVE = "tentative"
    CONFIRMED = "confirmed"
    LOST = "lost"
    DELETED = "deleted"


@dataclass
class SensorMeasurement:
    """Individual sensor measurement"""

    sensor_id: str
    sensor_type: SensorType
    timestamp: float
    position: np.ndarray  # [x, y, z]
    velocity: Optional[np.ndarray] = None  # [vx, vy, vz]
    attributes: Dict[str, float] = None  # Additional sensor-specific data
    covariance: Optional[np.ndarray] = None  # Measurement uncertainty
    confidence: float = 1.0
    quality_score: float = 1.0


@dataclass
class FusedTrack:
    """Fused multi-sensor track"""

    track_id: int
    state: np.ndarray  # [x, y, z, vx, vy, vz]
    covariance: np.ndarray  # State covariance matrix
    last_update: float
    sensor_measurements: Dict[SensorType, List[SensorMeasurement]]
    tracking_state: TrackingState
    track_quality: float
    threat_classification: Dict[str, float]
    attributes: Dict[str, Any]


class KalmanFilter:
    """Extended Kalman Filter for state estimation"""

    def __init__(self, state_dim: int = 6, measurement_dim: int = 3):
        """
        Initialize Kalman filter

        Args:
            state_dim: Dimension of state vector [x, y, z, vx, vy, vz]
            measurement_dim: Dimension of measurement vector [x, y, z]
        """
        self.state_dim = state_dim
        self.measurement_dim = measurement_dim

        # State vector: [x, y, z, vx, vy, vz]
        self.state = np.zeros(state_dim)

        # State covariance matrix
        self.P = np.eye(state_dim) * 1000.0

        # Process noise covariance
        self.Q = np.eye(state_dim) * 0.1

        # Measurement noise covariance
        self.R = np.eye(measurement_dim) * 1.0

        # State transition matrix (constant velocity model)
        self.F = np.eye(state_dim)
        self.F[0:3, 3:6] = np.eye(3)  # Position = position + velocity * dt

        # Measurement matrix (observe position only)
        self.H = np.zeros((measurement_dim, state_dim))
        self.H[0:3, 0:3] = np.eye(3)

        self.last_update = time.time()

    def predict(self, dt: float) -> None:
        """Predict next state"""
        # Update state transition matrix with time step
        self.F[0:3, 3:6] = np.eye(3) * dt

        # Predict state
        self.state = self.F @ self.state

        # Update process noise based on time step
        Q_scaled = self.Q * dt

        # Predict covariance
        self.P = self.F @ self.P @ self.F.T + Q_scaled

    def update(
        self, measurement: np.ndarray, measurement_cov: Optional[np.ndarray] = None
    ) -> None:
        """Update state with new measurement"""
        if measurement_cov is not None:
            R = measurement_cov
        else:
            R = self.R

        # Innovation
        y = measurement - self.H @ self.state

        # Innovation covariance
        S = self.H @ self.P @ self.H.T + R

        # Kalman gain
        K = self.P @ self.H.T @ np.linalg.inv(S)

        # Update state
        self.state = self.state + K @ y

        # Update covariance
        I = np.eye(self.state_dim)
        self.P = (I - K @ self.H) @ self.P

        self.last_update = time.time()

    def get_state(self) -> Tuple[np.ndarray, np.ndarray]:
        """Get current state and covariance"""
        return self.state.copy(), self.P.copy()


class MultiSensorFusion:
    """
    Advanced multi-sensor fusion system for defense applications
    """

    def __init__(self, fusion_config: Dict[str, Any] = None):
        """Initialize the sensor fusion system"""
        self.config = fusion_config or self._get_default_config()

        # Active tracks
        self.tracks: Dict[int, FusedTrack] = {}
        self.next_track_id = 1

        # Sensor measurements buffer
        self.measurement_buffer: Dict[SensorType, List[SensorMeasurement]] = {
            sensor_type: [] for sensor_type in SensorType
        }

        # Kalman filters for each track
        self.kalman_filters: Dict[int, KalmanFilter] = {}

        # Performance metrics
        self.metrics = {
            "total_measurements": 0,
            "active_tracks": 0,
            "fusion_rate_hz": 0.0,
            "track_accuracy": 0.0,
            "sensor_health": {sensor_type.value: 1.0 for sensor_type in SensorType},
        }

        # Thread safety
        self.fusion_lock = threading.Lock()

        # Background processing
        self.running = True
        self.fusion_thread = threading.Thread(target=self._fusion_loop, daemon=True)
        self.fusion_thread.start()

        logger.info("Multi-sensor fusion system initialized")

    def _get_default_config(self) -> Dict[str, Any]:
        """Get default fusion configuration"""
        return {
            "association_threshold": 10.0,  # Maximum distance for track association
            "track_confirmation_threshold": 3,  # Minimum detections to confirm track
            "track_deletion_threshold": 10,  # Time (seconds) before deleting lost track
            "fusion_rate_hz": 10.0,  # Fusion processing rate
            "max_measurement_age": 5.0,  # Maximum age of measurements to consider
            "sensor_weights": {  # Sensor reliability weights
                SensorType.RADAR: 0.9,
                SensorType.LIDAR: 0.85,
                SensorType.THERMAL: 0.7,
                SensorType.OPTICAL: 0.6,
                SensorType.RF_SPECTRUM: 0.8,
                SensorType.ACOUSTIC: 0.5,
                SensorType.MAGNETIC: 0.4,
                SensorType.SEISMIC: 0.3,
            },
            "environmental_factors": {
                "weather_condition": "clear",  # clear, rain, fog, snow
                "time_of_day": "day",  # day, night, dawn, dusk
                "terrain_type": "open",  # open, urban, forest, mountain
            },
        }

    def add_measurement(self, measurement: SensorMeasurement) -> None:
        """Add a new sensor measurement"""
        with self.fusion_lock:
            # Add to buffer
            self.measurement_buffer[measurement.sensor_type].append(measurement)

            # Limit buffer size
            max_buffer_size = 100
            if len(self.measurement_buffer[measurement.sensor_type]) > max_buffer_size:
                self.measurement_buffer[measurement.sensor_type] = (
                    self.measurement_buffer[measurement.sensor_type][-max_buffer_size:]
                )

            self.metrics["total_measurements"] += 1

    def _fusion_loop(self) -> None:
        """Main fusion processing loop"""
        while self.running:
            start_time = time.time()

            try:
                self._process_fusion_cycle()

                # Calculate processing rate
                cycle_time = time.time() - start_time
                self.metrics["fusion_rate_hz"] = 1.0 / max(cycle_time, 0.001)

                # Sleep to maintain target rate
                target_period = 1.0 / self.config["fusion_rate_hz"]
                sleep_time = max(0, target_period - cycle_time)
                time.sleep(sleep_time)

            except Exception as e:
                logger.error(f"Fusion loop error: {e}")
                time.sleep(0.1)

    def _process_fusion_cycle(self) -> None:
        """Process one fusion cycle"""
        with self.fusion_lock:
            current_time = time.time()

            # 1. Clean old measurements
            self._clean_old_measurements(current_time)

            # 2. Predict existing tracks
            self._predict_tracks(current_time)

            # 3. Associate measurements with tracks
            associated_measurements = self._associate_measurements()

            # 4. Update tracks with associated measurements
            self._update_tracks(associated_measurements)

            # 5. Initialize new tracks from unassociated measurements
            self._initialize_new_tracks(associated_measurements)

            # 6. Manage track lifecycle
            self._manage_track_lifecycle(current_time)

            # 7. Update metrics
            self._update_metrics()

    def _clean_old_measurements(self, current_time: float) -> None:
        """Remove old measurements from buffer"""
        max_age = self.config["max_measurement_age"]

        for sensor_type in SensorType:
            measurements = self.measurement_buffer[sensor_type]
            self.measurement_buffer[sensor_type] = [
                m for m in measurements if (current_time - m.timestamp) < max_age
            ]

    def _predict_tracks(self, current_time: float) -> None:
        """Predict all active tracks forward in time"""
        for track_id, track in self.tracks.items():
            if track_id in self.kalman_filters:
                dt = current_time - track.last_update
                if dt > 0:
                    self.kalman_filters[track_id].predict(dt)

                    # Update track state
                    state, covariance = self.kalman_filters[track_id].get_state()
                    track.state = state
                    track.covariance = covariance

    def _associate_measurements(self) -> Dict[int, List[SensorMeasurement]]:
        """Associate measurements with existing tracks"""
        associations = {track_id: [] for track_id in self.tracks.keys()}
        unassociated = []

        # Collect all current measurements
        all_measurements = []
        for sensor_type in SensorType:
            all_measurements.extend(self.measurement_buffer[sensor_type])

        # Associate each measurement
        for measurement in all_measurements:
            best_track_id = None
            best_distance = float("inf")

            # Find closest track
            for track_id, track in self.tracks.items():
                distance = self._calculate_association_distance(measurement, track)

                if (
                    distance < self.config["association_threshold"]
                    and distance < best_distance
                ):
                    best_distance = distance
                    best_track_id = track_id

            # Associate or mark as unassociated
            if best_track_id is not None:
                associations[best_track_id].append(measurement)
            else:
                unassociated.append(measurement)

        # Store unassociated measurements for new track initialization
        associations[-1] = unassociated

        return associations

    def _calculate_association_distance(
        self, measurement: SensorMeasurement, track: FusedTrack
    ) -> float:
        """Calculate distance between measurement and track for association"""
        # Mahalanobis distance considering uncertainty
        predicted_position = track.state[:3]
        position_cov = track.covariance[:3, :3]

        innovation = measurement.position - predicted_position

        try:
            # Add measurement covariance if available
            if measurement.covariance is not None:
                total_cov = position_cov + measurement.covariance
            else:
                total_cov = position_cov + np.eye(3) * 1.0

            # Mahalanobis distance
            distance = np.sqrt(innovation.T @ np.linalg.inv(total_cov) @ innovation)
        except np.linalg.LinAlgError:
            # Fallback to Euclidean distance
            distance = np.linalg.norm(innovation)

        # Weight by sensor reliability and measurement quality
        sensor_weight = self.config["sensor_weights"].get(measurement.sensor_type, 0.5)
        quality_factor = measurement.quality_score * measurement.confidence

        return distance / (sensor_weight * quality_factor)

    def _update_tracks(self, associations: Dict[int, List[SensorMeasurement]]) -> None:
        """Update tracks with associated measurements"""
        current_time = time.time()

        for track_id, measurements in associations.items():
            if track_id == -1:  # Skip unassociated measurements
                continue

            if track_id not in self.tracks or not measurements:
                continue

            track = self.tracks[track_id]
            kf = self.kalman_filters[track_id]

            # Fuse multiple measurements
            if len(measurements) == 1:
                # Single measurement update
                measurement = measurements[0]
                measurement_cov = (
                    measurement.covariance
                    if measurement.covariance is not None
                    else np.eye(3)
                )
                kf.update(measurement.position, measurement_cov)
            else:
                # Multi-measurement fusion
                fused_measurement, fused_covariance = self._fuse_measurements(
                    measurements
                )
                kf.update(fused_measurement, fused_covariance)

            # Update track
            state, covariance = kf.get_state()
            track.state = state
            track.covariance = covariance
            track.last_update = current_time

            # Store sensor measurements
            for measurement in measurements:
                if measurement.sensor_type not in track.sensor_measurements:
                    track.sensor_measurements[measurement.sensor_type] = []
                track.sensor_measurements[measurement.sensor_type].append(measurement)

                # Limit history
                if len(track.sensor_measurements[measurement.sensor_type]) > 10:
                    track.sensor_measurements[measurement.sensor_type] = (
                        track.sensor_measurements[measurement.sensor_type][-10:]
                    )

            # Update track quality and threat classification
            self._update_track_attributes(track, measurements)

    def _fuse_measurements(
        self, measurements: List[SensorMeasurement]
    ) -> Tuple[np.ndarray, np.ndarray]:
        """Fuse multiple simultaneous measurements"""
        if len(measurements) == 1:
            measurement = measurements[0]
            cov = (
                measurement.covariance
                if measurement.covariance is not None
                else np.eye(3)
            )
            return measurement.position, cov

        # Weighted fusion based on sensor reliability and measurement quality
        positions = []
        weights = []
        covariances = []

        for measurement in measurements:
            positions.append(measurement.position)

            # Calculate weight
            sensor_weight = self.config["sensor_weights"].get(
                measurement.sensor_type, 0.5
            )
            quality_weight = measurement.quality_score * measurement.confidence
            weights.append(sensor_weight * quality_weight)

            # Get covariance
            if measurement.covariance is not None:
                covariances.append(measurement.covariance)
            else:
                covariances.append(np.eye(3))

        positions = np.array(positions)
        weights = np.array(weights)
        weights = weights / np.sum(weights)  # Normalize

        # Weighted average position
        fused_position = np.sum(positions * weights[:, np.newaxis], axis=0)

        # Uncertainty propagation (simplified)
        fused_covariance = np.zeros((3, 3))
        for i, (weight, cov) in enumerate(zip(weights, covariances)):
            fused_covariance += weight * weight * cov

        return fused_position, fused_covariance

    def _initialize_new_tracks(
        self, associations: Dict[int, List[SensorMeasurement]]
    ) -> None:
        """Initialize new tracks from unassociated measurements"""
        unassociated = associations.get(-1, [])

        # Group nearby measurements
        measurement_groups = self._group_measurements(unassociated)

        for group in measurement_groups:
            if len(group) >= 1:  # At least one measurement to start track
                self._create_new_track(group)

    def _group_measurements(
        self, measurements: List[SensorMeasurement]
    ) -> List[List[SensorMeasurement]]:
        """Group nearby measurements that likely belong to the same object"""
        if not measurements:
            return []

        # Simple clustering based on distance
        groups = []
        used = set()

        for i, measurement in enumerate(measurements):
            if i in used:
                continue

            group = [measurement]
            used.add(i)

            # Find nearby measurements
            for j, other_measurement in enumerate(measurements):
                if j in used:
                    continue

                distance = np.linalg.norm(
                    measurement.position - other_measurement.position
                )
                if distance < self.config["association_threshold"] / 2:
                    group.append(other_measurement)
                    used.add(j)

            groups.append(group)

        return groups

    def _create_new_track(self, measurements: List[SensorMeasurement]) -> None:
        """Create a new track from initial measurements"""
        track_id = self.next_track_id
        self.next_track_id += 1

        # Initialize state from measurements
        if len(measurements) == 1:
            initial_position = measurements[0].position
            initial_velocity = (
                measurements[0].velocity
                if measurements[0].velocity is not None
                else np.zeros(3)
            )
        else:
            # Fuse initial measurements
            initial_position, _ = self._fuse_measurements(measurements)
            initial_velocity = np.zeros(3)  # No velocity information initially

        # Create Kalman filter
        kf = KalmanFilter()
        kf.state[:3] = initial_position
        kf.state[3:6] = initial_velocity
        self.kalman_filters[track_id] = kf

        # Create track
        track = FusedTrack(
            track_id=track_id,
            state=kf.state.copy(),
            covariance=kf.P.copy(),
            last_update=time.time(),
            sensor_measurements={},
            tracking_state=TrackingState.TENTATIVE,
            track_quality=0.5,
            threat_classification={},
            attributes={},
        )

        # Add measurements to track
        for measurement in measurements:
            if measurement.sensor_type not in track.sensor_measurements:
                track.sensor_measurements[measurement.sensor_type] = []
            track.sensor_measurements[measurement.sensor_type].append(measurement)

        self.tracks[track_id] = track

        logger.info(
            f"Created new track {track_id} with {len(measurements)} initial measurements"
        )

    def _manage_track_lifecycle(self, current_time: float) -> None:
        """Manage track confirmation, loss, and deletion"""
        tracks_to_delete = []

        for track_id, track in self.tracks.items():
            time_since_update = current_time - track.last_update

            # Confirm tentative tracks
            if track.tracking_state == TrackingState.TENTATIVE:
                total_measurements = sum(
                    len(measurements)
                    for measurements in track.sensor_measurements.values()
                )
                if total_measurements >= self.config["track_confirmation_threshold"]:
                    track.tracking_state = TrackingState.CONFIRMED
                    logger.info(f"Track {track_id} confirmed")

            # Mark tracks as lost
            if (
                track.tracking_state == TrackingState.CONFIRMED
                and time_since_update > 2.0
            ):
                track.tracking_state = TrackingState.LOST
                logger.info(f"Track {track_id} marked as lost")

            # Delete old lost tracks
            if (
                track.tracking_state == TrackingState.LOST
                and time_since_update > self.config["track_deletion_threshold"]
            ):
                tracks_to_delete.append(track_id)

            # Delete tentative tracks that haven't been confirmed
            if (
                track.tracking_state == TrackingState.TENTATIVE
                and time_since_update > 5.0
            ):
                tracks_to_delete.append(track_id)

        # Delete tracks
        for track_id in tracks_to_delete:
            del self.tracks[track_id]
            if track_id in self.kalman_filters:
                del self.kalman_filters[track_id]
            logger.info(f"Track {track_id} deleted")

    def _update_track_attributes(
        self, track: FusedTrack, measurements: List[SensorMeasurement]
    ) -> None:
        """Update track quality and threat classification"""
        # Update track quality based on sensor diversity and measurement quality
        sensor_types = set(m.sensor_type for m in measurements)
        sensor_diversity = len(sensor_types) / len(SensorType)

        avg_quality = np.mean([m.quality_score * m.confidence for m in measurements])
        track.track_quality = 0.7 * track.track_quality + 0.3 * (
            sensor_diversity * avg_quality
        )

        # Update threat classification (simplified)
        # In practice, this would use ML models for classification
        speed = np.linalg.norm(track.state[3:6])
        altitude = track.state[2]

        track.threat_classification = {
            "aerial": min(1.0, max(0.0, altitude / 1000.0)),
            "ground": max(0.0, 1.0 - altitude / 100.0) if altitude < 100 else 0.0,
            "naval": 0.1 if altitude < 10 else 0.0,
            "high_speed": min(1.0, speed / 100.0),
            "stationary": max(0.0, 1.0 - speed / 10.0),
        }

    def _update_metrics(self) -> None:
        """Update performance metrics"""
        self.metrics["active_tracks"] = len(
            [
                t
                for t in self.tracks.values()
                if t.tracking_state
                in [TrackingState.TENTATIVE, TrackingState.CONFIRMED]
            ]
        )

        # Calculate track accuracy (simplified metric)
        confirmed_tracks = [
            t
            for t in self.tracks.values()
            if t.tracking_state == TrackingState.CONFIRMED
        ]
        if confirmed_tracks:
            avg_quality = np.mean([t.track_quality for t in confirmed_tracks])
            self.metrics["track_accuracy"] = avg_quality

        # Update sensor health
        current_time = time.time()
        for sensor_type in SensorType:
            recent_measurements = [
                m
                for m in self.measurement_buffer[sensor_type]
                if (current_time - m.timestamp) < 5.0
            ]

            if recent_measurements:
                avg_quality = np.mean(
                    [m.quality_score * m.confidence for m in recent_measurements]
                )
                self.metrics["sensor_health"][sensor_type.value] = avg_quality
            else:
                # Decay health if no recent measurements
                self.metrics["sensor_health"][sensor_type.value] *= 0.9

    def get_active_tracks(self) -> List[FusedTrack]:
        """Get all active tracks"""
        with self.fusion_lock:
            return [
                track
                for track in self.tracks.values()
                if track.tracking_state
                in [TrackingState.TENTATIVE, TrackingState.CONFIRMED]
            ]

    def get_track_by_id(self, track_id: int) -> Optional[FusedTrack]:
        """Get specific track by ID"""
        with self.fusion_lock:
            return self.tracks.get(track_id)

    def get_metrics(self) -> Dict[str, Any]:
        """Get current fusion metrics"""
        return self.metrics.copy()

    def stop(self) -> None:
        """Stop the fusion system"""
        self.running = False
        if self.fusion_thread.is_alive():
            self.fusion_thread.join(timeout=1.0)
        logger.info("Sensor fusion system stopped")


# Pre-configured sensor setups for defense scenarios
DEFENSE_SENSOR_CONFIGS = {
    "air_defense": {
        "association_threshold": 15.0,
        "track_confirmation_threshold": 2,
        "fusion_rate_hz": 20.0,
        "sensor_weights": {
            SensorType.RADAR: 0.95,
            SensorType.OPTICAL: 0.8,
            SensorType.THERMAL: 0.85,
            SensorType.RF_SPECTRUM: 0.9,
        },
    },
    "ground_surveillance": {
        "association_threshold": 5.0,
        "track_confirmation_threshold": 3,
        "fusion_rate_hz": 10.0,
        "sensor_weights": {
            SensorType.LIDAR: 0.9,
            SensorType.OPTICAL: 0.85,
            SensorType.THERMAL: 0.8,
            SensorType.SEISMIC: 0.7,
            SensorType.ACOUSTIC: 0.6,
        },
    },
    "maritime_patrol": {
        "association_threshold": 25.0,
        "track_confirmation_threshold": 2,
        "fusion_rate_hz": 5.0,
        "sensor_weights": {
            SensorType.RADAR: 0.9,
            SensorType.OPTICAL: 0.7,
            SensorType.RF_SPECTRUM: 0.85,
            SensorType.ACOUSTIC: 0.8,
        },
    },
}


# Example usage and testing
if __name__ == "__main__":
    print("AEGIS-SE Multi-Sensor Fusion System - Demo")

    # Initialize fusion system
    fusion_system = MultiSensorFusion(DEFENSE_SENSOR_CONFIGS["air_defense"])

    try:
        # Simulate sensor measurements
        for i in range(20):
            # Simulate moving object
            t = i * 0.1
            base_position = np.array([100 + t * 50, 200 + t * 20, 1000 + t * 5])
            noise = np.random.normal(0, 2, 3)

            # Radar measurement
            radar_measurement = SensorMeasurement(
                sensor_id="radar_001",
                sensor_type=SensorType.RADAR,
                timestamp=time.time(),
                position=base_position + noise,
                velocity=np.array([50, 20, 5]) + np.random.normal(0, 1, 3),
                confidence=0.9,
                quality_score=0.95,
            )
            fusion_system.add_measurement(radar_measurement)

            # Optical measurement (less frequent, more noise)
            if i % 3 == 0:
                optical_noise = np.random.normal(0, 5, 3)
                optical_measurement = SensorMeasurement(
                    sensor_id="optical_001",
                    sensor_type=SensorType.OPTICAL,
                    timestamp=time.time(),
                    position=base_position + optical_noise,
                    confidence=0.7,
                    quality_score=0.8,
                )
                fusion_system.add_measurement(optical_measurement)

            time.sleep(0.1)

        # Wait for processing
        time.sleep(2.0)

        # Get results
        active_tracks = fusion_system.get_active_tracks()
        metrics = fusion_system.get_metrics()

        print(f"Active tracks: {len(active_tracks)}")
        print(f"Fusion metrics: {metrics}")

        for track in active_tracks:
            print(
                f"Track {track.track_id}: state={track.state[:3]}, quality={track.track_quality:.2f}"
            )
            print(f"  Threat classification: {track.threat_classification}")

    finally:
        fusion_system.stop()
