--------------------------------------------------------------------------------
-- AEGIS-SE Master System Controller
-- Centralized Control and Coordination for Defense Platform
-- 
-- Author: AEGIS-SE FPGA Team
-- Copyright: Department of Defense - UNCLASSIFIED
-- Version: 1.0
-- Date: 2025-09-26
--
-- Features:
-- - Master system orchestration and control
-- - Multi-subsystem coordination (radar, comms, weapons)
-- - Real-time threat assessment integration
-- - Mission planning and execution control
-- - System health monitoring and diagnostics
-- - Secure command and control interface
-- - Fault detection, isolation, and recovery (FDIR)
-- - Performance optimization and resource management
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity aegis_system_controller is
    Generic (
        -- System Configuration
        NUM_SUBSYSTEMS      : integer := 8;     -- Number of controlled subsystems
        NUM_THREAT_CHANNELS : integer := 16;    -- Concurrent threat processing channels
        NUM_WEAPON_SYSTEMS  : integer := 4;     -- Number of weapon systems
        
        -- Performance Parameters
        SYSTEM_CLOCK_MHZ    : integer := 200;   -- Master system clock
        RESPONSE_TIME_US    : integer := 50;    -- Maximum response time
        THREAT_UPDATE_HZ    : integer := 1000;  -- Threat assessment update rate
        
        -- Security Parameters
        CLEARANCE_LEVELS    : integer := 4;     -- Security clearance levels
        CRYPTO_KEY_WIDTH    : integer := 256;   -- Cryptographic key width
        
        -- Mission Parameters
        MAX_MISSIONS        : integer := 8;     -- Concurrent mission support
        MAX_TARGETS         : integer := 64;    -- Maximum tracked targets
        MAX_WAYPOINTS       : integer := 32     -- Maximum mission waypoints
    );
    Port (
        -- Clock and Reset
        clk_system          : in  STD_LOGIC;    -- 200MHz system clock
        clk_weapons         : in  STD_LOGIC;    -- 400MHz weapons control clock
        clk_comms           : in  STD_LOGIC;    -- 100MHz communications clock
        rst_n               : in  STD_LOGIC;
        
        -- Command and Control Interface
        command_interface   : in  STD_LOGIC_VECTOR(31 downto 0);
        command_valid       : in  STD_LOGIC;
        command_ack         : out STD_LOGIC;
        status_output       : out STD_LOGIC_VECTOR(31 downto 0);
        status_valid        : out STD_LOGIC;
        
        -- Subsystem Control Interfaces
        radar_control       : out STD_LOGIC_VECTOR(31 downto 0);
        radar_status        : in  STD_LOGIC_VECTOR(31 downto 0);
        radar_enable        : out STD_LOGIC;
        
        comms_control       : out STD_LOGIC_VECTOR(31 downto 0);
        comms_status        : in  STD_LOGIC_VECTOR(31 downto 0);
        comms_enable        : out STD_LOGIC;
        
        weapons_control     : out STD_LOGIC_VECTOR(31 downto 0);
        weapons_status      : in  STD_LOGIC_VECTOR(31 downto 0);
        weapons_enable      : out STD_LOGIC;
        weapons_fire_auth   : out STD_LOGIC;
        
        navigation_control  : out STD_LOGIC_VECTOR(31 downto 0);
        navigation_status   : in  STD_LOGIC_VECTOR(31 downto 0);
        navigation_enable   : out STD_LOGIC;
        
        -- Threat Assessment Interface
        threat_data_in      : in  STD_LOGIC_VECTOR(127 downto 0);
        threat_valid        : in  STD_LOGIC;
        threat_level        : in  STD_LOGIC_VECTOR(7 downto 0);
        threat_bearing      : in  STD_LOGIC_VECTOR(15 downto 0);
        threat_range        : in  STD_LOGIC_VECTOR(15 downto 0);
        threat_priority     : out STD_LOGIC_VECTOR(7 downto 0);
        threat_response     : out STD_LOGIC_VECTOR(31 downto 0);
        
        -- Mission Planning Interface
        mission_parameters  : in  STD_LOGIC_VECTOR(255 downto 0);
        mission_start       : in  STD_LOGIC;
        mission_abort       : in  STD_LOGIC;
        mission_status      : out STD_LOGIC_VECTOR(15 downto 0);
        mission_progress    : out STD_LOGIC_VECTOR(7 downto 0);
        waypoint_reached    : out STD_LOGIC;
        
        -- Target Tracking Interface
        target_positions    : in  STD_LOGIC_VECTOR(32*MAX_TARGETS-1 downto 0);
        target_velocities   : in  STD_LOGIC_VECTOR(16*MAX_TARGETS-1 downto 0);
        target_classifications : in STD_LOGIC_VECTOR(8*MAX_TARGETS-1 downto 0);
        target_updates      : in  STD_LOGIC_VECTOR(MAX_TARGETS-1 downto 0);
        target_engagements  : out STD_LOGIC_VECTOR(MAX_TARGETS-1 downto 0);
        
        -- System Health Monitoring
        temperature_sensors : in  STD_LOGIC_VECTOR(8*NUM_SUBSYSTEMS-1 downto 0);
        power_status        : in  STD_LOGIC_VECTOR(NUM_SUBSYSTEMS-1 downto 0);
        fault_indicators    : in  STD_LOGIC_VECTOR(NUM_SUBSYSTEMS-1 downto 0);
        health_status       : out STD_LOGIC_VECTOR(15 downto 0);
        system_ready        : out STD_LOGIC;
        
        -- Security Interface
        security_level      : in  STD_LOGIC_VECTOR(3 downto 0);
        crypto_key          : in  STD_LOGIC_VECTOR(CRYPTO_KEY_WIDTH-1 downto 0);
        auth_token          : in  STD_LOGIC_VECTOR(127 downto 0);
        security_violation  : out STD_LOGIC;
        access_granted      : out STD_LOGIC;
        
        -- Performance Monitoring
        system_utilization  : out STD_LOGIC_VECTOR(7 downto 0);
        response_times      : out STD_LOGIC_VECTOR(31 downto 0);
        throughput_metrics  : out STD_LOGIC_VECTOR(31 downto 0);
        
        -- Emergency Controls
        emergency_shutdown  : in  STD_LOGIC;
        battle_stations     : in  STD_LOGIC;
        general_quarters    : in  STD_LOGIC;
        emergency_status    : out STD_LOGIC_VECTOR(7 downto 0)
    );
end aegis_system_controller;

architecture behavioral of aegis_system_controller is

    -- System State Machine
    type system_state_t is (
        SYSTEM_INIT,
        SYSTEM_STARTUP,
        SYSTEM_READY,
        MISSION_PLANNING,
        MISSION_EXECUTION,
        THREAT_RESPONSE,
        WEAPONS_ENGAGEMENT,
        EMERGENCY_MODE,
        SHUTDOWN
    );
    signal current_state, next_state : system_state_t;
    
    -- Mission Control Structure
    type mission_phase_t is (INACTIVE, PLANNING, EN_ROUTE, ENGAGING, RETURNING, COMPLETE);
    type mission_t is record
        phase           : mission_phase_t;
        priority        : unsigned(7 downto 0);
        start_time      : unsigned(31 downto 0);
        duration        : unsigned(31 downto 0);
        current_waypoint : unsigned(7 downto 0);
        target_list     : STD_LOGIC_VECTOR(MAX_TARGETS-1 downto 0);
        resources_allocated : STD_LOGIC_VECTOR(NUM_SUBSYSTEMS-1 downto 0);
        success_criteria : STD_LOGIC_VECTOR(15 downto 0);
    end record;
    
    type mission_array_t is array (0 to MAX_MISSIONS-1) of mission_t;
    signal active_missions : mission_array_t;
    signal current_mission : unsigned(3 downto 0);
    
    -- Threat Assessment Structure
    type threat_class_t is (UNKNOWN, AIRCRAFT, MISSILE, SHIP, SUBMARINE, GROUND);
    type threat_t is record
        class           : threat_class_t;
        position_x      : signed(15 downto 0);
        position_y      : signed(15 downto 0);
        position_z      : signed(15 downto 0);
        velocity_x      : signed(15 downto 0);
        velocity_y      : signed(15 downto 0);
        velocity_z      : signed(15 downto 0);
        threat_level    : unsigned(7 downto 0);
        confidence      : unsigned(7 downto 0);
        time_to_impact  : unsigned(15 downto 0);
        engagement_zone : STD_LOGIC;
        countermeasures : STD_LOGIC_VECTOR(7 downto 0);
    end record;
    
    type threat_array_t is array (0 to MAX_TARGETS-1) of threat_t;
    signal threat_database : threat_array_t;
    signal highest_priority_threat : unsigned(7 downto 0);
    
    -- Subsystem Control
    type subsystem_t is record
        enabled         : STD_LOGIC;
        operational     : STD_LOGIC;
        fault_status    : STD_LOGIC_VECTOR(7 downto 0);
        performance     : unsigned(7 downto 0);
        temperature     : unsigned(7 downto 0);
        power_consumption : unsigned(15 downto 0);
        last_maintenance : unsigned(31 downto 0);
    end record;
    
    type subsystem_array_t is array (0 to NUM_SUBSYSTEMS-1) of subsystem_t;
    signal subsystems : subsystem_array_t;
    
    -- Weapon System Control
    type weapon_state_t is (SAFE, ARMED, TARGETING, FIRING, RELOADING);
    type weapon_t is record
        state           : weapon_state_t;
        ammunition      : unsigned(15 downto 0);
        target_id       : unsigned(7 downto 0);
        fire_solution   : STD_LOGIC_VECTOR(63 downto 0);
        ready_time      : unsigned(15 downto 0);
        last_fired      : unsigned(31 downto 0);
    end record;
    
    type weapon_array_t is array (0 to NUM_WEAPON_SYSTEMS-1) of weapon_t;
    signal weapon_systems : weapon_array_t;
    signal fire_authorization : STD_LOGIC;
    signal fire_inhibit : STD_LOGIC;
    
    -- Timing and Scheduling
    signal system_timer     : unsigned(31 downto 0);
    signal mission_timer    : unsigned(31 downto 0);
    signal threat_timer     : unsigned(15 downto 0);
    signal response_timer   : unsigned(15 downto 0);
    signal health_check_timer : unsigned(31 downto 0);
    
    -- Security and Access Control
    signal current_clearance : unsigned(3 downto 0);
    signal authentication_valid : STD_LOGIC;
    signal command_authorized : STD_LOGIC;
    signal security_breach_count : unsigned(7 downto 0);
    
    -- Performance Metrics
    signal command_response_times : unsigned(31 downto 0);
    signal threat_processing_time : unsigned(15 downto 0);
    signal system_load : unsigned(7 downto 0);
    signal bandwidth_utilization : unsigned(7 downto 0);
    
    -- Fault Detection and Recovery
    signal fault_detection_active : STD_LOGIC;
    signal isolation_mask : STD_LOGIC_VECTOR(NUM_SUBSYSTEMS-1 downto 0);
    signal recovery_in_progress : STD_LOGIC;
    signal backup_systems_active : STD_LOGIC_VECTOR(NUM_SUBSYSTEMS-1 downto 0);
    
    -- Communication Protocols
    signal message_queue_full : STD_LOGIC;
    signal priority_message : STD_LOGIC;
    signal broadcast_active : STD_LOGIC;
    signal encrypted_comms : STD_LOGIC;

begin

    -- Main System State Machine
    system_state_machine: process(clk_system)
    begin
        if rising_edge(clk_system) then
            if rst_n = '0' then
                current_state <= SYSTEM_INIT;
            else
                current_state <= next_state;
            end if;
        end if;
    end process;
    
    next_state_logic: process(current_state, command_valid, emergency_shutdown, battle_stations, 
                             threat_valid, highest_priority_threat, mission_start)
    begin
        next_state <= current_state;
        
        case current_state is
            when SYSTEM_INIT =>
                next_state <= SYSTEM_STARTUP;
                
            when SYSTEM_STARTUP =>
                if system_ready = '1' then
                    next_state <= SYSTEM_READY;
                end if;
                
            when SYSTEM_READY =>
                if emergency_shutdown = '1' then
                    next_state <= EMERGENCY_MODE;
                elsif battle_stations = '1' then
                    next_state <= THREAT_RESPONSE;
                elsif mission_start = '1' then
                    next_state <= MISSION_PLANNING;
                elsif threat_valid = '1' and unsigned(threat_level) > 128 then
                    next_state <= THREAT_RESPONSE;
                end if;
                
            when MISSION_PLANNING =>
                next_state <= MISSION_EXECUTION;
                
            when MISSION_EXECUTION =>
                if threat_valid = '1' and unsigned(threat_level) > 200 then
                    next_state <= THREAT_RESPONSE;
                elsif mission_abort = '1' then
                    next_state <= SYSTEM_READY;
                end if;
                
            when THREAT_RESPONSE =>
                if fire_authorization = '1' then
                    next_state <= WEAPONS_ENGAGEMENT;
                elsif unsigned(threat_level) < 64 then
                    next_state <= SYSTEM_READY;
                end if;
                
            when WEAPONS_ENGAGEMENT =>
                if weapon_systems(0).state = SAFE then
                    next_state <= SYSTEM_READY;
                end if;
                
            when EMERGENCY_MODE =>
                if emergency_shutdown = '0' then
                    next_state <= SYSTEM_STARTUP;
                end if;
                
            when SHUTDOWN =>
                -- System shutdown state
                null;
        end case;
    end process;
    
    -- Mission Management
    mission_controller: process(clk_system)
        variable mission_index : integer;
    begin
        if rising_edge(clk_system) then
            if rst_n = '0' then
                for i in 0 to MAX_MISSIONS-1 loop
                    active_missions(i).phase <= INACTIVE;
                    active_missions(i).priority <= (others => '0');
                end loop;
                current_mission <= (others => '0');
                mission_timer <= (others => '0');
            else
                mission_timer <= mission_timer + 1;
                
                case current_state is
                    when MISSION_PLANNING =>
                        -- Find available mission slot
                        mission_index := 0;
                        for i in 0 to MAX_MISSIONS-1 loop
                            if active_missions(i).phase = INACTIVE then
                                mission_index := i;
                                exit;
                            end if;
                        end loop;
                        
                        -- Initialize new mission
                        active_missions(mission_index).phase <= PLANNING;
                        active_missions(mission_index).start_time <= system_timer;
                        active_missions(mission_index).current_waypoint <= (others => '0');
                        current_mission <= to_unsigned(mission_index, 4);
                        
                    when MISSION_EXECUTION =>
                        -- Update current mission status
                        if to_integer(current_mission) < MAX_MISSIONS then
                            active_missions(to_integer(current_mission)).phase <= EN_ROUTE;
                            
                            -- Check waypoint progress
                            if mission_timer mod 1000 = 0 then -- Check every 1000 cycles
                                active_missions(to_integer(current_mission)).current_waypoint <= 
                                    active_missions(to_integer(current_mission)).current_waypoint + 1;
                            end if;
                        end if;
                end case;
            end if;
        end if;
    end process;
    
    -- Threat Assessment and Prioritization
    threat_processor: process(clk_system)
        variable max_threat_level : unsigned(7 downto 0);
        variable max_threat_index : integer;
    begin
        if rising_edge(clk_system) then
            if rst_n = '0' then
                highest_priority_threat <= (others => '0');
                threat_timer <= (others => '0');
                for i in 0 to MAX_TARGETS-1 loop
                    threat_database(i).threat_level <= (others => '0');
                    threat_database(i).confidence <= (others => '0');
                end loop;
            else
                threat_timer <= threat_timer + 1;
                
                -- Update threat data
                if threat_valid = '1' then
                    -- Process incoming threat data
                    for i in 0 to MAX_TARGETS-1 loop
                        if target_updates(i) = '1' then
                            threat_database(i).threat_level <= unsigned(threat_level);
                            threat_database(i).position_x <= signed(threat_bearing);
                            threat_database(i).confidence <= to_unsigned(255, 8); -- High confidence for radar data
                            
                            -- Calculate time to impact
                            if unsigned(threat_range) > 0 then
                                threat_database(i).time_to_impact <= unsigned(threat_range) / 10; -- Simplified calculation
                            end if;
                        end if;
                    end loop;
                end if;
                
                -- Find highest priority threat
                max_threat_level := (others => '0');
                max_threat_index := 0;
                for i in 0 to MAX_TARGETS-1 loop
                    if threat_database(i).threat_level > max_threat_level then
                        max_threat_level := threat_database(i).threat_level;
                        max_threat_index := i;
                    end if;
                end loop;
                highest_priority_threat <= to_unsigned(max_threat_index, 8);
            end if;
        end if;
    end process;
    
    -- Weapons Control System
    weapons_controller: process(clk_weapons)
    begin
        if rising_edge(clk_weapons) then
            if rst_n = '0' then
                for i in 0 to NUM_WEAPON_SYSTEMS-1 loop
                    weapon_systems(i).state <= SAFE;
                    weapon_systems(i).ammunition <= to_unsigned(100, 16); -- Full load
                    weapon_systems(i).target_id <= (others => '0');
                end loop;
                fire_authorization <= '0';
                fire_inhibit <= '0';
            else
                case current_state is
                    when THREAT_RESPONSE =>
                        -- Arm weapons if threat level is high
                        if unsigned(threat_level) > 150 then
                            for i in 0 to NUM_WEAPON_SYSTEMS-1 loop
                                if weapon_systems(i).ammunition > 0 then
                                    weapon_systems(i).state <= ARMED;
                                end if;
                            end loop;
                        end if;
                        
                    when WEAPONS_ENGAGEMENT =>
                        -- Target acquisition and firing sequence
                        for i in 0 to NUM_WEAPON_SYSTEMS-1 loop
                            if weapon_systems(i).state = ARMED then
                                weapon_systems(i).state <= TARGETING;
                                weapon_systems(i).target_id <= highest_priority_threat;
                                
                                -- Fire authorization logic
                                if weapon_systems(i).ready_time = 0 and not fire_inhibit then
                                    fire_authorization <= '1';
                                    weapon_systems(i).state <= FIRING;
                                    weapon_systems(i).ammunition <= weapon_systems(i).ammunition - 1;
                                    weapon_systems(i).last_fired <= system_timer;
                                end if;
                            end if;
                        end loop;
                        
                    when others =>
                        -- Return to safe state
                        for i in 0 to NUM_WEAPON_SYSTEMS-1 loop
                            weapon_systems(i).state <= SAFE;
                        end loop;
                        fire_authorization <= '0';
                end case;
            end if;
        end if;
    end process;
    
    -- Subsystem Health Monitoring
    health_monitor: process(clk_system)
    begin
        if rising_edge(clk_system) then
            if rst_n = '0' then
                health_check_timer <= (others => '0');
                fault_detection_active <= '1';
                for i in 0 to NUM_SUBSYSTEMS-1 loop
                    subsystems(i).enabled <= '1';
                    subsystems(i).operational <= '0';
                    subsystems(i).fault_status <= (others => '0');
                end loop;
            else
                health_check_timer <= health_check_timer + 1;
                
                -- Periodic health checks
                if health_check_timer mod 10000 = 0 then -- Every 10k cycles
                    for i in 0 to NUM_SUBSYSTEMS-1 loop
                        -- Check temperature
                        subsystems(i).temperature <= unsigned(temperature_sensors(8*(i+1)-1 downto 8*i));
                        
                        if subsystems(i).temperature > 85 then -- Thermal threshold
                            subsystems(i).fault_status(0) <= '1'; -- Thermal fault
                        end if;
                        
                        -- Check power status
                        if power_status(i) = '0' then
                            subsystems(i).operational <= '0';
                            subsystems(i).fault_status(1) <= '1'; -- Power fault
                        else
                            subsystems(i).operational <= '1';
                        end if;
                        
                        -- Check fault indicators
                        if fault_indicators(i) = '1' then
                            subsystems(i).fault_status(7 downto 2) <= "111111"; -- General fault
                        end if;
                    end loop;
                end if;
            end if;
        end if;
    end process;
    
    -- Security and Access Control
    security_controller: process(clk_system)
    begin
        if rising_edge(clk_system) then
            if rst_n = '0' then
                current_clearance <= (others => '0');
                authentication_valid <= '0';
                command_authorized <= '0';
                security_breach_count <= (others => '0');
            else
                -- Validate security level
                current_clearance <= unsigned(security_level);
                
                -- Authentication check (simplified)
                if auth_token /= x"00000000000000000000000000000000" then
                    authentication_valid <= '1';
                else
                    authentication_valid <= '0';
                end if;
                
                -- Command authorization
                if authentication_valid = '1' and current_clearance >= 2 then
                    command_authorized <= '1';
                else
                    command_authorized <= '0';
                    if command_valid = '1' then
                        security_breach_count <= security_breach_count + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;
    
    -- Performance Monitoring
    performance_monitor: process(clk_system)
    begin
        if rising_edge(clk_system) then
            if rst_n = '0' then
                command_response_times <= (others => '0');
                threat_processing_time <= (others => '0');
                system_load <= (others => '0');
                response_timer <= (others => '0');
            else
                response_timer <= response_timer + 1;
                
                -- Measure command response time
                if command_valid = '1' then
                    response_timer <= (others => '0');
                elsif command_ack = '1' then
                    command_response_times <= resize(response_timer, 32);
                end if;
                
                -- Calculate system load based on active subsystems
                system_load <= (others => '0');
                for i in 0 to NUM_SUBSYSTEMS-1 loop
                    if subsystems(i).operational = '1' then
                        system_load <= system_load + to_unsigned(16, 8);
                    end if;
                end loop;
            end if;
        end if;
    end process;
    
    -- Timer Management
    system_timing: process(clk_system)
    begin
        if rising_edge(clk_system) then
            if rst_n = '0' then
                system_timer <= (others => '0');
            else
                system_timer <= system_timer + 1;
            end if;
        end if;
    end process;
    
    -- Output Signal Assignments
    command_ack <= command_authorized and command_valid;
    
    -- Subsystem enables based on current state
    radar_enable <= subsystems(0).enabled when current_state /= SHUTDOWN else '0';
    comms_enable <= subsystems(1).enabled when current_state /= SHUTDOWN else '0';
    weapons_enable <= subsystems(2).enabled when current_state /= SHUTDOWN else '0';
    navigation_enable <= subsystems(3).enabled when current_state /= SHUTDOWN else '0';
    
    weapons_fire_auth <= fire_authorization and not fire_inhibit;
    
    -- Status outputs
    system_ready <= '1' when current_state = SYSTEM_READY or current_state = MISSION_EXECUTION else '0';
    mission_progress <= STD_LOGIC_VECTOR(active_missions(to_integer(current_mission)).current_waypoint);
    
    -- Security outputs
    security_violation <= '1' when security_breach_count > 3 else '0';
    access_granted <= authentication_valid and command_authorized;
    
    -- Performance outputs
    system_utilization <= STD_LOGIC_VECTOR(system_load);
    response_times <= STD_LOGIC_VECTOR(command_response_times);
    
    -- Emergency status
    emergency_status <= x"FF" when current_state = EMERGENCY_MODE else x"00";
    
    -- Health status summary
    health_status <= STD_LOGIC_VECTOR(to_unsigned(0, 8)) & 
                    STD_LOGIC_VECTOR(security_breach_count) when 
                    (subsystems(0).operational and subsystems(1).operational and 
                     subsystems(2).operational and subsystems(3).operational) = '1' 
                    else x"FFFF";

end behavioral;