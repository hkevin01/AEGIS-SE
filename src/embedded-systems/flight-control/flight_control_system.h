/**
 * @file flight_control_system.h
 * @brief Advanced Flight Control System Header for AEGIS-SE Defense Platform
 * @version 1.0
 * @date 2024-09-26
 * 
 * @author AEGIS-SE Development Team
 * @copyright Department of Defense - UNCLASSIFIED
 * 
 * MISRA C:2012 Compliant
 * DO-178C Level A Ready
 * External API for flight control subsystem
 */

#ifndef FLIGHT_CONTROL_SYSTEM_H
#define FLIGHT_CONTROL_SYSTEM_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Version information */
#define FLIGHT_CONTROL_VERSION_MAJOR  (1U)
#define FLIGHT_CONTROL_VERSION_MINOR  (0U)

/**
 * @brief System error codes for comprehensive error handling
 */
typedef enum
{
  FLIGHT_CTRL_SUCCESS = 0,                       /**< Operation successful */
  FLIGHT_CTRL_ERROR_INVALID_PARAM,               /**< Invalid parameter passed */
  FLIGHT_CTRL_ERROR_SENSOR_TIMEOUT,              /**< Sensor data timeout */
  FLIGHT_CTRL_ERROR_BOUNDARY_VIOLATION,          /**< Safety boundary exceeded */
  FLIGHT_CTRL_ERROR_MEMORY_ALLOCATION,           /**< Memory allocation failed */
  FLIGHT_CTRL_ERROR_SYSTEM_FAULT,                /**< General system fault */
  FLIGHT_CTRL_ERROR_REAL_TIME_VIOLATION,         /**< Real-time constraint violated */
  FLIGHT_CTRL_ERROR_HARDWARE_FAILURE,            /**< Hardware component failed */
  FLIGHT_CTRL_ERROR_COMMUNICATION_LOST,          /**< Communication link lost */
  FLIGHT_CTRL_ERROR_CRITICAL_SYSTEM_FAILURE      /**< Critical system failure */
} flight_control_error_t;

/**
 * @brief System states for state machine management
 */
typedef enum
{
  FLIGHT_STATE_INITIALIZE = 0,  /**< System initializing */
  FLIGHT_STATE_STANDBY,         /**< System ready, not armed */
  FLIGHT_STATE_ARMED,           /**< System armed, ready for flight */
  FLIGHT_STATE_ACTIVE,          /**< Active flight control mode */
  FLIGHT_STATE_EMERGENCY,       /**< Emergency mode engaged */
  FLIGHT_STATE_SHUTDOWN,        /**< System shutting down */
  FLIGHT_STATE_FAULT            /**< System fault detected */
} flight_system_state_t;

/**
 * @brief High-precision timestamp structure
 */
typedef struct
{
  uint64_t seconds;      /**< Seconds since epoch */
  uint32_t nanoseconds;  /**< Nanosecond precision */
} precise_timestamp_t;

/**
 * @brief 3D vector structure for sensor data
 */
typedef struct
{
  float x;  /**< X-axis component */
  float y;  /**< Y-axis component */ 
  float z;  /**< Z-axis component */
  precise_timestamp_t timestamp;  /**< Data timestamp */
  bool valid;  /**< Data validity flag */
} vector3d_t;

/**
 * @brief Comprehensive sensor data structure
 */
typedef struct
{
  vector3d_t accelerometer;      /**< Acceleration in m/s² */
  vector3d_t gyroscope;          /**< Angular velocity in rad/s */
  vector3d_t magnetometer;       /**< Magnetic field in μT */
  float barometric_pressure;     /**< Pressure in Pa */
  float temperature;             /**< Temperature in °C */
  precise_timestamp_t timestamp; /**< Sensor reading timestamp */
  uint32_t sequence_number;      /**< Sequence for data integrity */
  bool sensor_health;            /**< Overall sensor health */
} sensor_data_t;

/**
 * @brief Control surface commands
 */
typedef struct
{
  float aileron_left;   /**< Left aileron angle in degrees */
  float aileron_right;  /**< Right aileron angle in degrees */
  float elevator;       /**< Elevator angle in degrees */
  float rudder;         /**< Rudder angle in degrees */
  float throttle;       /**< Throttle position 0.0-1.0 */
  precise_timestamp_t timestamp;  /**< Command timestamp */
  bool emergency_mode;  /**< Emergency override flag */
} control_commands_t;

/**
 * @brief Performance monitoring structure
 */
typedef struct
{
  uint64_t loop_count;               /**< Total control loops executed */
  uint64_t max_loop_time_ns;         /**< Maximum loop execution time */
  uint64_t avg_loop_time_ns;         /**< Average loop execution time */
  uint32_t sensor_timeout_count;     /**< Number of sensor timeouts */
  uint32_t boundary_violation_count; /**< Control limit violations */
  uint32_t error_count;              /**< Total error count */
  float cpu_utilization_percent;     /**< CPU usage percentage */
  size_t memory_usage_bytes;         /**< Current memory usage */
} performance_metrics_t;

/* Public API Functions */

/**
 * @brief Initialize the flight control system
 * @return Error code indicating initialization result
 * @retval FLIGHT_CTRL_SUCCESS System initialized successfully
 * @retval FLIGHT_CTRL_ERROR_SYSTEM_FAULT Initialization failed
 * 
 * @pre System must be in uninitialized state
 * @post System transitions to FLIGHT_STATE_STANDBY if successful
 */
flight_control_error_t flight_control_initialize(void);

/**
 * @brief Execute main control loop with real-time constraints
 * @param sensor_input Pointer to current sensor readings (must not be NULL)
 * @param control_output Pointer to store control commands (must not be NULL)
 * @return Error code indicating loop execution result
 * @retval FLIGHT_CTRL_SUCCESS Control loop executed successfully
 * @retval FLIGHT_CTRL_ERROR_INVALID_PARAM NULL pointer passed
 * @retval FLIGHT_CTRL_ERROR_SENSOR_TIMEOUT Sensor data too old
 * @retval FLIGHT_CTRL_ERROR_BOUNDARY_VIOLATION Safety limits exceeded
 * @retval FLIGHT_CTRL_ERROR_REAL_TIME_VIOLATION Loop time exceeded 1ms
 * 
 * @pre System must be initialized
 * @post Control commands updated with latest calculations
 * 
 * @note This function must be called at 1kHz for proper operation
 * @note Execution time guaranteed < 1ms for real-time compliance
 */
flight_control_error_t flight_control_execute_loop(const sensor_data_t* sensor_input,
                                                   control_commands_t* control_output);

/**
 * @brief Get current system performance metrics
 * @param metrics Pointer to store performance data (must not be NULL)
 * @return Error code indicating success or failure
 * @retval FLIGHT_CTRL_SUCCESS Metrics retrieved successfully
 * @retval FLIGHT_CTRL_ERROR_INVALID_PARAM NULL pointer passed
 * 
 * @pre System must be initialized
 * @post Metrics structure populated with current data
 */
flight_control_error_t flight_control_get_metrics(performance_metrics_t* metrics);

/**
 * @brief Shutdown flight control system gracefully
 * @return Error code indicating shutdown result
 * @retval FLIGHT_CTRL_SUCCESS System shutdown successfully
 * 
 * @pre System can be in any state
 * @post System transitions to FLIGHT_STATE_SHUTDOWN
 * @post All control outputs set to safe neutral positions
 * @post Sensitive data cleared from memory
 */
flight_control_error_t flight_control_shutdown(void);

/**
 * @brief Get current system state
 * @return Current flight system state
 * 
 * @note This function is always safe to call
 * @note Returns current state without side effects
 */
flight_system_state_t flight_control_get_state(void);

/**
 * @brief Check if system is in emergency mode
 * @return True if in emergency mode, false otherwise
 * @retval true System is in emergency state
 * @retval false System is in normal operation
 * 
 * @note This function is always safe to call
 * @note Can be used for external system coordination
 */
bool flight_control_is_emergency_mode(void);

#ifdef __cplusplus
}
#endif

#endif /* FLIGHT_CONTROL_SYSTEM_H */
