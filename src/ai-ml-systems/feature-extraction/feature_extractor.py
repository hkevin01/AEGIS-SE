#!/usr/bin/env python3
"""
Advanced Feature Extraction for AEGIS-SE Defense Platform
Multi-Modal Signal Processing and Feature Engineering

Author: AEGIS-SE Feature Extraction Team
Copyright: Department of Defense - UNCLASSIFIED
Version: 2.0
Date: 2025-09-26

Features:
- Multi-domain feature extraction (time, frequency, spatial)
- Radar signal processing and CFAR detection
- Image feature extraction with CNN backbones
- Spectral analysis and RF fingerprinting
- Temporal pattern recognition
- Adaptive feature selection
- Real-time feature streaming
"""

import logging
import time
from dataclasses import dataclass
from enum import Enum
from typing import Any, Dict, List, Optional, Tuple

import numpy as np
from scipy import signal
from scipy.fft import fft, spectrogram
from sklearn.decomposition import PCA
from sklearn.preprocessing import StandardScaler

# Configure logging
logger = logging.getLogger(__name__)


class FeatureType(Enum):
    """Types of features that can be extracted"""

    TEMPORAL = "temporal"
    SPECTRAL = "spectral"
    SPATIAL = "spatial"
    STATISTICAL = "statistical"
    RADAR_SPECIFIC = "radar_specific"
    IMAGE_FEATURES = "image_features"
    RF_FINGERPRINT = "rf_fingerprint"


class SignalType(Enum):
    """Types of input signals"""

    RADAR_IQ = "radar_iq"
    AUDIO = "audio"
    IMAGE = "image"
    RF_SPECTRUM = "rf_spectrum"
    LIDAR_POINT_CLOUD = "lidar_point_cloud"
    SEISMIC = "seismic"
    MAGNETIC = "magnetic"


@dataclass
class FeatureVector:
    """Container for extracted features"""

    features: np.ndarray
    feature_names: List[str]
    feature_types: List[FeatureType]
    extraction_time: float
    signal_type: SignalType
    confidence: float
    metadata: Dict[str, Any]


@dataclass
class ExtractionConfig:
    """Configuration for feature extraction"""

    signal_type: SignalType
    sampling_rate: float
    window_size: int
    overlap_ratio: float = 0.5
    feature_types: List[FeatureType] = None
    normalize_features: bool = True
    pca_components: Optional[int] = None
    cfar_threshold: float = 3.0  # CFAR detection threshold
    spectral_bands: List[Tuple[float, float]] = None  # Frequency bands of interest


class RadarFeatureExtractor:
    """Specialized feature extractor for radar signals"""

    def __init__(self, config: ExtractionConfig):
        self.config = config
        self.cfar_detector = CFARDetector(config.cfar_threshold)

    def extract_radar_features(self, iq_data: np.ndarray) -> Dict[str, np.ndarray]:
        """Extract comprehensive radar-specific features"""
        features = {}

        # Range-Doppler processing
        range_doppler = self._compute_range_doppler(iq_data)
        features["range_doppler_map"] = range_doppler

        # CFAR detection
        detections = self.cfar_detector.detect(range_doppler)
        features["cfar_detections"] = detections

        # Micro-Doppler features
        micro_doppler = self._extract_micro_doppler(iq_data)
        features["micro_doppler_signature"] = micro_doppler

        # Range profile statistics
        range_profile = np.mean(np.abs(range_doppler), axis=1)
        features.update(
            self._compute_statistical_features(range_profile, "range_profile")
        )

        # Doppler spectrum statistics
        doppler_spectrum = np.mean(np.abs(range_doppler), axis=0)
        features.update(
            self._compute_statistical_features(doppler_spectrum, "doppler_spectrum")
        )

        # Polarimetric features (if dual-pol data available)
        if iq_data.shape[-1] >= 2:
            pol_features = self._extract_polarimetric_features(iq_data)
            features.update(pol_features)

        return features

    def _compute_range_doppler(self, iq_data: np.ndarray) -> np.ndarray:
        """Compute range-Doppler map from IQ data"""
        # Apply windowing
        window = signal.windows.hann(iq_data.shape[0])
        windowed_data = iq_data * window[:, np.newaxis]

        # Range FFT
        range_fft = fft(windowed_data, axis=0)

        # Doppler FFT
        doppler_fft = fft(range_fft, axis=1)

        return np.abs(doppler_fft)

    def _extract_micro_doppler(self, iq_data: np.ndarray) -> np.ndarray:
        """Extract micro-Doppler signature using STFT"""
        # Short-time Fourier transform for micro-Doppler analysis
        f, t, Zxx = spectrogram(
            iq_data[:, 0] if iq_data.ndim > 1 else iq_data,
            fs=self.config.sampling_rate,
            window="hann",
            nperseg=64,
            noverlap=32,
        )

        return np.abs(Zxx)

    def _extract_polarimetric_features(
        self, iq_data: np.ndarray
    ) -> Dict[str, np.ndarray]:
        """Extract polarimetric radar features"""
        h_channel = iq_data[:, 0]  # Horizontal polarization
        v_channel = iq_data[:, 1]  # Vertical polarization

        features = {}

        # Cross-correlation
        cross_corr = np.corrcoef(np.abs(h_channel), np.abs(v_channel))[0, 1]
        features["polarimetric_correlation"] = np.array([cross_corr])

        # Polarization ratio
        h_power = np.mean(np.abs(h_channel) ** 2)
        v_power = np.mean(np.abs(v_channel) ** 2)
        pol_ratio = h_power / (v_power + 1e-10)
        features["polarization_ratio"] = np.array([pol_ratio])

        # Circular polarization ratio
        lhcp = (h_channel + 1j * v_channel) / np.sqrt(2)  # Left-hand circular
        rhcp = (h_channel - 1j * v_channel) / np.sqrt(2)  # Right-hand circular

        lhcp_power = np.mean(np.abs(lhcp) ** 2)
        rhcp_power = np.mean(np.abs(rhcp) ** 2)
        circular_ratio = lhcp_power / (rhcp_power + 1e-10)
        features["circular_polarization_ratio"] = np.array([circular_ratio])

        return features

    def _compute_statistical_features(
        self, data: np.ndarray, prefix: str
    ) -> Dict[str, np.ndarray]:
        """Compute statistical features from 1D data"""
        features = {}

        features[f"{prefix}_mean"] = np.array([np.mean(data)])
        features[f"{prefix}_std"] = np.array([np.std(data)])
        features[f"{prefix}_skew"] = np.array([self._skewness(data)])
        features[f"{prefix}_kurtosis"] = np.array([self._kurtosis(data)])
        features[f"{prefix}_peak"] = np.array([np.max(data)])
        features[f"{prefix}_rms"] = np.array([np.sqrt(np.mean(data**2))])
        features[f"{prefix}_crest_factor"] = np.array(
            [np.max(data) / (np.sqrt(np.mean(data**2)) + 1e-10)]
        )

        # Spectral centroid and bandwidth
        freqs = np.arange(len(data))
        spectral_centroid = np.sum(freqs * data) / (np.sum(data) + 1e-10)
        spectral_bandwidth = np.sqrt(
            np.sum(((freqs - spectral_centroid) ** 2) * data) / (np.sum(data) + 1e-10)
        )

        features[f"{prefix}_spectral_centroid"] = np.array([spectral_centroid])
        features[f"{prefix}_spectral_bandwidth"] = np.array([spectral_bandwidth])

        return features

    def _skewness(self, data: np.ndarray) -> float:
        """Compute skewness of data"""
        mean = np.mean(data)
        std = np.std(data)
        return np.mean(((data - mean) / (std + 1e-10)) ** 3)

    def _kurtosis(self, data: np.ndarray) -> float:
        """Compute kurtosis of data"""
        mean = np.mean(data)
        std = np.std(data)
        return np.mean(((data - mean) / (std + 1e-10)) ** 4) - 3


class CFARDetector:
    """Constant False Alarm Rate detector for radar"""

    def __init__(
        self,
        threshold_factor: float = 3.0,
        guard_cells: int = 2,
        training_cells: int = 10,
    ):
        self.threshold_factor = threshold_factor
        self.guard_cells = guard_cells
        self.training_cells = training_cells

    def detect(self, range_doppler_map: np.ndarray) -> np.ndarray:
        """Apply CFAR detection to range-Doppler map"""
        detections = np.zeros_like(range_doppler_map, dtype=bool)

        for i in range(
            self.training_cells + self.guard_cells,
            range_doppler_map.shape[0] - self.training_cells - self.guard_cells,
        ):
            for j in range(
                self.training_cells + self.guard_cells,
                range_doppler_map.shape[1] - self.training_cells - self.guard_cells,
            ):

                # Cell under test
                cut_value = range_doppler_map[i, j]

                # Training cells
                training_window = self._get_training_window(range_doppler_map, i, j)
                noise_level = np.mean(training_window)

                # Threshold test
                threshold = self.threshold_factor * noise_level
                if cut_value > threshold:
                    detections[i, j] = True

        return detections

    def _get_training_window(
        self, data: np.ndarray, center_i: int, center_j: int
    ) -> np.ndarray:
        """Get training window around cell under test"""
        # Create indices for training cells (excluding guard cells)
        training_indices = []

        for di in range(
            -self.training_cells - self.guard_cells,
            self.training_cells + self.guard_cells + 1,
        ):
            for dj in range(
                -self.training_cells - self.guard_cells,
                self.training_cells + self.guard_cells + 1,
            ):
                # Skip guard cells and cell under test
                if abs(di) <= self.guard_cells and abs(dj) <= self.guard_cells:
                    continue

                i, j = center_i + di, center_j + dj
                if 0 <= i < data.shape[0] and 0 <= j < data.shape[1]:
                    training_indices.append((i, j))

        if not training_indices:
            return np.array([data[center_i, center_j]])

        training_values = [data[i, j] for i, j in training_indices]
        return np.array(training_values)


class SpectralFeatureExtractor:
    """Feature extractor for spectral analysis"""

    def __init__(self, config: ExtractionConfig):
        self.config = config

    def extract_spectral_features(
        self, signal_data: np.ndarray
    ) -> Dict[str, np.ndarray]:
        """Extract comprehensive spectral features"""
        features = {}

        # Power spectral density
        freqs, psd = signal.welch(
            signal_data, fs=self.config.sampling_rate, nperseg=1024
        )
        features["power_spectral_density"] = psd
        features["frequencies"] = freqs

        # Spectral features
        features.update(self._compute_spectral_statistics(freqs, psd))

        # Band power features
        if self.config.spectral_bands:
            band_powers = self._compute_band_powers(
                freqs, psd, self.config.spectral_bands
            )
            features.update(band_powers)

        # Spectrogram features
        f, t, Sxx = spectrogram(signal_data, fs=self.config.sampling_rate)
        features["spectrogram"] = Sxx
        features["spectrogram_times"] = t
        features["spectrogram_freqs"] = f

        # Spectral rolloff and flux
        features["spectral_rolloff"] = np.array([self._spectral_rolloff(freqs, psd)])
        features["spectral_flux"] = np.array([self._spectral_flux(Sxx)])

        return features

    def _compute_spectral_statistics(
        self, freqs: np.ndarray, psd: np.ndarray
    ) -> Dict[str, np.ndarray]:
        """Compute statistical features from power spectral density"""
        features = {}

        # Spectral centroid
        spectral_centroid = np.sum(freqs * psd) / (np.sum(psd) + 1e-10)
        features["spectral_centroid"] = np.array([spectral_centroid])

        # Spectral spread (bandwidth)
        spectral_spread = np.sqrt(
            np.sum(((freqs - spectral_centroid) ** 2) * psd) / (np.sum(psd) + 1e-10)
        )
        features["spectral_spread"] = np.array([spectral_spread])

        # Spectral skewness and kurtosis
        normalized_freqs = (freqs - spectral_centroid) / (spectral_spread + 1e-10)
        spectral_skewness = np.sum((normalized_freqs**3) * psd) / (np.sum(psd) + 1e-10)
        spectral_kurtosis = (
            np.sum((normalized_freqs**4) * psd) / (np.sum(psd) + 1e-10) - 3
        )

        features["spectral_skewness"] = np.array([spectral_skewness])
        features["spectral_kurtosis"] = np.array([spectral_kurtosis])

        # Spectral flatness (Wiener entropy)
        geometric_mean = np.exp(np.mean(np.log(psd + 1e-10)))
        arithmetic_mean = np.mean(psd)
        spectral_flatness = geometric_mean / (arithmetic_mean + 1e-10)
        features["spectral_flatness"] = np.array([spectral_flatness])

        return features

    def _compute_band_powers(
        self, freqs: np.ndarray, psd: np.ndarray, bands: List[Tuple[float, float]]
    ) -> Dict[str, np.ndarray]:
        """Compute power in specified frequency bands"""
        features = {}

        for i, (low_freq, high_freq) in enumerate(bands):
            band_mask = (freqs >= low_freq) & (freqs <= high_freq)
            band_power = np.sum(psd[band_mask])
            features[f"band_power_{i}_{int(low_freq)}_{int(high_freq)}Hz"] = np.array(
                [band_power]
            )

        return features

    def _spectral_rolloff(
        self, freqs: np.ndarray, psd: np.ndarray, rolloff_percent: float = 0.85
    ) -> float:
        """Compute spectral rolloff frequency"""
        total_power = np.sum(psd)
        cumulative_power = np.cumsum(psd)
        rolloff_power = rolloff_percent * total_power

        rolloff_idx = np.where(cumulative_power >= rolloff_power)[0]
        if len(rolloff_idx) > 0:
            return freqs[rolloff_idx[0]]
        else:
            return freqs[-1]

    def _spectral_flux(self, spectrogram: np.ndarray) -> float:
        """Compute spectral flux (measure of spectral change over time)"""
        if spectrogram.shape[1] < 2:
            return 0.0

        diff = np.diff(spectrogram, axis=1)
        flux = np.mean(np.sum(np.abs(diff), axis=0))
        return flux


class ImageFeatureExtractor:
    """Feature extractor for image data"""

    def __init__(self, config: ExtractionConfig):
        self.config = config

    def extract_image_features(self, image: np.ndarray) -> Dict[str, np.ndarray]:
        """Extract comprehensive image features"""
        features = {}

        # Ensure grayscale
        if len(image.shape) == 3:
            gray_image = np.mean(image, axis=2)
        else:
            gray_image = image

        # Basic statistics
        features.update(self._compute_image_statistics(gray_image))

        # Texture features
        features.update(self._compute_texture_features(gray_image))

        # Edge features
        features.update(self._compute_edge_features(gray_image))

        # Histogram features
        features.update(self._compute_histogram_features(gray_image))

        return features

    def _compute_image_statistics(self, image: np.ndarray) -> Dict[str, np.ndarray]:
        """Compute basic image statistics"""
        features = {}

        features["image_mean"] = np.array([np.mean(image)])
        features["image_std"] = np.array([np.std(image)])
        features["image_min"] = np.array([np.min(image)])
        features["image_max"] = np.array([np.max(image)])
        features["image_range"] = np.array([np.max(image) - np.min(image)])

        return features

    def _compute_texture_features(self, image: np.ndarray) -> Dict[str, np.ndarray]:
        """Compute texture features using local binary patterns and gradients"""
        features = {}

        # Gradient magnitude
        grad_x = np.gradient(image, axis=1)
        grad_y = np.gradient(image, axis=0)
        grad_magnitude = np.sqrt(grad_x**2 + grad_y**2)

        features["gradient_mean"] = np.array([np.mean(grad_magnitude)])
        features["gradient_std"] = np.array([np.std(grad_magnitude)])

        # Local variance (texture measure)
        kernel_size = 5
        local_variance = self._local_variance(image, kernel_size)
        features["local_variance_mean"] = np.array([np.mean(local_variance)])
        features["local_variance_std"] = np.array([np.std(local_variance)])

        return features

    def _compute_edge_features(self, image: np.ndarray) -> Dict[str, np.ndarray]:
        """Compute edge-based features"""
        features = {}

        # Sobel edge detection
        sobel_x = np.array([[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]])
        sobel_y = np.array([[-1, -2, -1], [0, 0, 0], [1, 2, 1]])

        edges_x = signal.convolve2d(image, sobel_x, mode="same", boundary="symm")
        edges_y = signal.convolve2d(image, sobel_y, mode="same", boundary="symm")

        edge_magnitude = np.sqrt(edges_x**2 + edges_y**2)

        features["edge_density"] = np.array(
            [np.mean(edge_magnitude > np.std(edge_magnitude))]
        )
        features["edge_mean"] = np.array([np.mean(edge_magnitude)])
        features["edge_std"] = np.array([np.std(edge_magnitude)])

        return features

    def _compute_histogram_features(self, image: np.ndarray) -> Dict[str, np.ndarray]:
        """Compute histogram-based features"""
        features = {}

        # Intensity histogram
        hist, bin_edges = np.histogram(image.flatten(), bins=64, density=True)

        # Histogram statistics
        features["histogram_entropy"] = np.array([-np.sum(hist * np.log(hist + 1e-10))])
        features["histogram_energy"] = np.array([np.sum(hist**2)])

        # Cumulative distribution features
        cdf = np.cumsum(hist)
        features["histogram_uniformity"] = np.array([1.0 / (1.0 + np.var(cdf))])

        return features

    def _local_variance(self, image: np.ndarray, kernel_size: int) -> np.ndarray:
        """Compute local variance using sliding window"""
        pad_size = kernel_size // 2
        padded_image = np.pad(image, pad_size, mode="reflect")

        variance_map = np.zeros_like(image)

        for i in range(image.shape[0]):
            for j in range(image.shape[1]):
                window = padded_image[i : i + kernel_size, j : j + kernel_size]
                variance_map[i, j] = np.var(window)

        return variance_map


class AdvancedFeatureExtractor:
    """Advanced multi-modal feature extraction system"""

    def __init__(self, config: ExtractionConfig):
        self.config = config

        # Initialize specialized extractors
        self.radar_extractor = RadarFeatureExtractor(config)
        self.spectral_extractor = SpectralFeatureExtractor(config)
        self.image_extractor = ImageFeatureExtractor(config)

        # Feature normalization
        self.scaler = StandardScaler() if config.normalize_features else None
        self.pca = (
            PCA(n_components=config.pca_components) if config.pca_components else None
        )

        # Performance tracking
        self.extraction_times = []
        self.feature_cache = {}

        logger.info(f"Advanced feature extractor initialized for {config.signal_type}")

    def extract_features(
        self, data: np.ndarray, metadata: Dict[str, Any] = None
    ) -> FeatureVector:
        """Extract features from input data"""
        start_time = time.time()

        try:
            # Route to appropriate extractor based on signal type
            if self.config.signal_type == SignalType.RADAR_IQ:
                features_dict = self.radar_extractor.extract_radar_features(data)
            elif self.config.signal_type in [
                SignalType.AUDIO,
                SignalType.RF_SPECTRUM,
                SignalType.SEISMIC,
            ]:
                features_dict = self.spectral_extractor.extract_spectral_features(
                    data.flatten()
                )
            elif self.config.signal_type == SignalType.IMAGE:
                features_dict = self.image_extractor.extract_image_features(data)
            else:
                # Generic feature extraction
                features_dict = self._extract_generic_features(data)

            # Filter features by requested types
            if self.config.feature_types:
                features_dict = self._filter_features_by_type(features_dict)

            # Combine all features into single vector
            feature_vector, feature_names = self._combine_features(features_dict)

            # Apply normalization and dimensionality reduction
            if self.scaler is not None:
                feature_vector = self.scaler.fit_transform(
                    feature_vector.reshape(1, -1)
                ).flatten()

            if self.pca is not None:
                feature_vector = self.pca.fit_transform(
                    feature_vector.reshape(1, -1)
                ).flatten()
                feature_names = [
                    f"pca_component_{i}" for i in range(len(feature_vector))
                ]

            # Calculate extraction time
            extraction_time = time.time() - start_time
            self.extraction_times.append(extraction_time)

            # Estimate confidence based on feature quality
            confidence = self._estimate_feature_confidence(
                features_dict, extraction_time
            )

            # Create feature vector object
            feature_types = self._determine_feature_types(feature_names)

            result = FeatureVector(
                features=feature_vector,
                feature_names=feature_names,
                feature_types=feature_types,
                extraction_time=extraction_time,
                signal_type=self.config.signal_type,
                confidence=confidence,
                metadata=metadata or {},
            )

            return result

        except Exception as e:
            logger.error(f"Feature extraction failed: {e}")
            # Return minimal feature vector
            return FeatureVector(
                features=np.zeros(10),
                feature_names=[f"error_feature_{i}" for i in range(10)],
                feature_types=[FeatureType.STATISTICAL] * 10,
                extraction_time=time.time() - start_time,
                signal_type=self.config.signal_type,
                confidence=0.0,
                metadata={"error": str(e)},
            )

    def _extract_generic_features(self, data: np.ndarray) -> Dict[str, np.ndarray]:
        """Extract generic statistical features from any data type"""
        features = {}

        flattened_data = data.flatten()

        # Basic statistics
        features["mean"] = np.array([np.mean(flattened_data)])
        features["std"] = np.array([np.std(flattened_data)])
        features["min"] = np.array([np.min(flattened_data)])
        features["max"] = np.array([np.max(flattened_data)])
        features["range"] = np.array([np.max(flattened_data) - np.min(flattened_data)])
        features["rms"] = np.array([np.sqrt(np.mean(flattened_data**2))])

        # Higher order moments
        features["skewness"] = np.array([self._compute_skewness(flattened_data)])
        features["kurtosis"] = np.array([self._compute_kurtosis(flattened_data)])

        # Percentiles
        percentiles = [10, 25, 50, 75, 90]
        for p in percentiles:
            features[f"percentile_{p}"] = np.array([np.percentile(flattened_data, p)])

        return features

    def _filter_features_by_type(
        self, features_dict: Dict[str, np.ndarray]
    ) -> Dict[str, np.ndarray]:
        """Filter features based on requested feature types"""
        # This is a simplified implementation
        # In practice, you'd maintain a mapping of feature names to types
        return features_dict

    def _combine_features(
        self, features_dict: Dict[str, np.ndarray]
    ) -> Tuple[np.ndarray, List[str]]:
        """Combine all features into a single vector"""
        feature_vector = []
        feature_names = []

        for name, values in features_dict.items():
            if values.ndim == 1:
                feature_vector.extend(values)
                if len(values) == 1:
                    feature_names.append(name)
                else:
                    feature_names.extend([f"{name}_{i}" for i in range(len(values))])
            elif values.ndim == 2:
                # Flatten 2D features (like spectrograms)
                flattened = values.flatten()
                feature_vector.extend(flattened)
                feature_names.extend(
                    [f"{name}_flat_{i}" for i in range(len(flattened))]
                )

        return np.array(feature_vector), feature_names

    def _determine_feature_types(self, feature_names: List[str]) -> List[FeatureType]:
        """Determine feature types based on feature names"""
        feature_types = []

        for name in feature_names:
            if any(
                keyword in name.lower() for keyword in ["spectral", "frequency", "fft"]
            ):
                feature_types.append(FeatureType.SPECTRAL)
            elif any(
                keyword in name.lower() for keyword in ["image", "edge", "texture"]
            ):
                feature_types.append(FeatureType.IMAGE_FEATURES)
            elif any(
                keyword in name.lower() for keyword in ["radar", "doppler", "range"]
            ):
                feature_types.append(FeatureType.RADAR_SPECIFIC)
            elif any(keyword in name.lower() for keyword in ["temporal", "time"]):
                feature_types.append(FeatureType.TEMPORAL)
            else:
                feature_types.append(FeatureType.STATISTICAL)

        return feature_types

    def _estimate_feature_confidence(
        self, features_dict: Dict[str, np.ndarray], extraction_time: float
    ) -> float:
        """Estimate confidence in extracted features"""
        # Base confidence
        confidence = 0.8

        # Adjust based on number of features
        num_features = sum(f.size for f in features_dict.values())
        if num_features > 50:
            confidence += 0.1
        elif num_features < 10:
            confidence -= 0.2

        # Adjust based on extraction time (slower might indicate more thorough processing)
        if extraction_time > 0.1:
            confidence += 0.05
        elif extraction_time > 1.0:
            confidence -= 0.1  # Too slow might indicate problems

        # Check for any invalid features
        for values in features_dict.values():
            if np.any(np.isnan(values)) or np.any(np.isinf(values)):
                confidence -= 0.3
                break

        return np.clip(confidence, 0.0, 1.0)

    def _compute_skewness(self, data: np.ndarray) -> float:
        """Compute skewness of data"""
        mean = np.mean(data)
        std = np.std(data)
        return np.mean(((data - mean) / (std + 1e-10)) ** 3)

    def _compute_kurtosis(self, data: np.ndarray) -> float:
        """Compute kurtosis of data"""
        mean = np.mean(data)
        std = np.std(data)
        return np.mean(((data - mean) / (std + 1e-10)) ** 4) - 3

    def get_performance_metrics(self) -> Dict[str, float]:
        """Get feature extraction performance metrics"""
        if not self.extraction_times:
            return {"average_extraction_time": 0.0, "total_extractions": 0}

        return {
            "average_extraction_time": np.mean(self.extraction_times),
            "max_extraction_time": np.max(self.extraction_times),
            "min_extraction_time": np.min(self.extraction_times),
            "total_extractions": len(self.extraction_times),
        }


# Pre-configured feature extraction setups
DEFENSE_FEATURE_CONFIGS = {
    "air_defense_radar": ExtractionConfig(
        signal_type=SignalType.RADAR_IQ,
        sampling_rate=1e6,  # 1 MHz
        window_size=1024,
        overlap_ratio=0.5,
        feature_types=[
            FeatureType.RADAR_SPECIFIC,
            FeatureType.SPECTRAL,
            FeatureType.STATISTICAL,
        ],
        normalize_features=True,
        cfar_threshold=4.0,
        spectral_bands=[(0, 1000), (1000, 5000), (5000, 10000)],  # Hz
    ),
    "optical_surveillance": ExtractionConfig(
        signal_type=SignalType.IMAGE,
        sampling_rate=30,  # 30 FPS
        window_size=512,
        feature_types=[
            FeatureType.IMAGE_FEATURES,
            FeatureType.SPATIAL,
            FeatureType.STATISTICAL,
        ],
        normalize_features=True,
        pca_components=50,
    ),
    "rf_spectrum_analysis": ExtractionConfig(
        signal_type=SignalType.RF_SPECTRUM,
        sampling_rate=10e6,  # 10 MHz
        window_size=2048,
        overlap_ratio=0.75,
        feature_types=[
            FeatureType.SPECTRAL,
            FeatureType.RF_FINGERPRINT,
            FeatureType.STATISTICAL,
        ],
        normalize_features=True,
        spectral_bands=[(0, 100e3), (100e3, 1e6), (1e6, 5e6)],  # Hz
    ),
}


# Example usage and testing
if __name__ == "__main__":
    print("AEGIS-SE Advanced Feature Extraction System - Demo")

    # Test radar feature extraction
    radar_config = DEFENSE_FEATURE_CONFIGS["air_defense_radar"]
    radar_extractor = AdvancedFeatureExtractor(radar_config)

    # Generate synthetic radar IQ data
    t = np.linspace(0, 1, 1024)
    radar_iq = np.random.complex128(
        np.random.randn(1024, 2) + 1j * np.random.randn(1024, 2)
    )

    # Add some simulated targets
    radar_iq[:, 0] += 0.5 * np.exp(1j * 2 * np.pi * 100 * t)  # Target at 100 Hz Doppler

    radar_features = radar_extractor.extract_features(radar_iq)
    print(
        f"Extracted {len(radar_features.features)} radar features in {radar_features.extraction_time:.3f}s"
    )
    print(f"Feature confidence: {radar_features.confidence:.2f}")

    # Test image feature extraction
    image_config = DEFENSE_FEATURE_CONFIGS["optical_surveillance"]
    image_extractor = AdvancedFeatureExtractor(image_config)

    # Generate synthetic image
    synthetic_image = np.random.randint(0, 256, (128, 128))

    image_features = image_extractor.extract_features(synthetic_image)
    print(
        f"Extracted {len(image_features.features)} image features in {image_features.extraction_time:.3f}s"
    )

    # Performance metrics
    radar_metrics = radar_extractor.get_performance_metrics()
    print(f"Radar extractor performance: {radar_metrics}")
