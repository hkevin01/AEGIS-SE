--------------------------------------------------------------------------------
-- Comprehensive Cryptographic Modules Testbench for AEGIS-SE Defense Platform
-- Validates All Phase 10 Advanced Cryptographic Components
-- Performance and Security Testing Suite
-- 
-- Author: AEGIS-SE Verification Team
-- Copyright: Department of Defense - UNCLASSIFIED
-- Version: 1.0
-- Date: 2025-09-26
--
-- Test Coverage:
-- - Enhanced AES-256 Crypto Accelerator with Side-Channel Protection
-- - Hardware Security Module (HSM) with Tamper Detection
-- - Post-Quantum Cryptography Engine (Kyber/Dilithium)
-- - High-Throughput Encryption Pipeline (10+ Gbps)
-- - Secure Key Management and Certificate Handler
-- - Performance benchmarking and compliance verification
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use STD.TEXTIO.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;

-- Testbench entity
entity crypto_comprehensive_tb is
end crypto_comprehensive_tb;

architecture Behavioral of crypto_comprehensive_tb is

    -- Test Configuration Constants
    constant CLK_PERIOD         : time := 2.5 ns;  -- 400 MHz
    constant SYS_CLK_PERIOD     : time := 5 ns;    -- 200 MHz
    constant TEST_TIMEOUT       : time := 1 ms;
    constant AES_KEY_WIDTH      : integer := 256;
    constant DATA_WIDTH         : integer := 512;
    constant PERFORMANCE_TARGET : integer := 10000; -- 10 Gbps in Mbps

    -- Clock and Reset Signals
    signal crypto_clk           : STD_LOGIC := '0';
    signal system_clk           : STD_LOGIC := '0';
    signal rst_n                : STD_LOGIC := '0';
    
    -- Test Control Signals
    signal test_complete        : STD_LOGIC := '0';
    signal test_pass            : STD_LOGIC := '0';
    signal current_test         : integer := 0;
    signal error_count          : integer := 0;

    -- AES Crypto Accelerator Signals
    signal aes_enable           : STD_LOGIC := '0';
    signal aes_key              : STD_LOGIC_VECTOR(AES_KEY_WIDTH-1 downto 0);
    signal aes_iv               : STD_LOGIC_VECTOR(127 downto 0);
    signal aes_data_in          : STD_LOGIC_VECTOR(127 downto 0);
    signal aes_data_out         : STD_LOGIC_VECTOR(127 downto 0);
    signal aes_valid_in         : STD_LOGIC := '0';
    signal aes_valid_out        : STD_LOGIC;
    signal aes_encrypt          : STD_LOGIC := '1';
    signal aes_mode             : STD_LOGIC_VECTOR(2 downto 0) := "000";

    -- HSM Signals
    signal hsm_tamper_sensors   : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal hsm_temperature      : STD_LOGIC_VECTOR(11 downto 0) := x"800"; -- Normal temp
    signal hsm_vcc_core         : STD_LOGIC_VECTOR(11 downto 0) := x"555"; -- Normal voltage
    signal hsm_vcc_aux          : STD_LOGIC_VECTOR(11 downto 0) := x"555";
    signal hsm_mesh_integrity   : STD_LOGIC := '1';
    signal hsm_case_switch      : STD_LOGIC := '0';
    signal hsm_auth_request     : STD_LOGIC := '0';
    signal hsm_auth_challenge   : STD_LOGIC_VECTOR(127 downto 0);
    signal hsm_auth_response    : STD_LOGIC_VECTOR(255 downto 0);
    signal hsm_auth_valid       : STD_LOGIC;
    signal hsm_security_state   : STD_LOGIC_VECTOR(3 downto 0);
    signal hsm_tamper_detected  : STD_LOGIC;
    signal hsm_key_request      : STD_LOGIC := '0';
    signal hsm_key_id           : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal hsm_key_data         : STD_LOGIC_VECTOR(255 downto 0);
    signal hsm_key_valid        : STD_LOGIC;

    -- Post-Quantum Crypto Signals
    signal pqc_operation_mode   : STD_LOGIC_VECTOR(3 downto 0) := "0000";
    signal pqc_start_operation  : STD_LOGIC := '0';
    signal pqc_operation_done   : STD_LOGIC;
    signal pqc_operation_valid  : STD_LOGIC;
    signal pqc_kyber_public_key : STD_LOGIC_VECTOR(1567*8-1 downto 0);
    signal pqc_kyber_secret_key : STD_LOGIC_VECTOR(3167*8-1 downto 0);
    signal pqc_kyber_shared_secret : STD_LOGIC_VECTOR(255 downto 0);
    signal pqc_random_request   : STD_LOGIC;
    signal pqc_random_data      : STD_LOGIC_VECTOR(255 downto 0) := (others => '0');
    signal pqc_random_valid     : STD_LOGIC := '0';
    signal pqc_error_flags      : STD_LOGIC_VECTOR(7 downto 0);

    -- High-Throughput Pipeline Signals
    signal pipeline_enable      : STD_LOGIC := '0';
    signal pipeline_algorithm   : STD_LOGIC_VECTOR(2 downto 0) := "000";
    signal pipeline_operation   : STD_LOGIC_VECTOR(1 downto 0) := "01";
    signal pipeline_s_tdata     : STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
    signal pipeline_s_tvalid    : STD_LOGIC := '0';
    signal pipeline_s_tready    : STD_LOGIC;
    signal pipeline_s_tlast     : STD_LOGIC := '0';
    signal pipeline_s_tkeep     : STD_LOGIC_VECTOR(DATA_WIDTH/8-1 downto 0) := (others => '1');
    signal pipeline_m_tdata     : STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
    signal pipeline_m_tvalid    : STD_LOGIC;
    signal pipeline_m_tready    : STD_LOGIC := '1';
    signal pipeline_m_tlast     : STD_LOGIC;
    signal pipeline_throughput  : STD_LOGIC_VECTOR(31 downto 0);
    signal pipeline_ready       : STD_LOGIC;
    signal pipeline_busy        : STD_LOGIC;

    -- Key Manager Signals
    signal km_security_level    : STD_LOGIC_VECTOR(1 downto 0) := "11";
    signal km_user_credentials  : STD_LOGIC_VECTOR(255 downto 0);
    signal km_auth_token        : STD_LOGIC_VECTOR(127 downto 0);
    signal km_access_granted    : STD_LOGIC;
    signal km_key_operation     : STD_LOGIC_VECTOR(3 downto 0) := "0000";
    signal km_key_id            : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
    signal km_key_data_in       : STD_LOGIC_VECTOR(255 downto 0);
    signal km_key_data_out      : STD_LOGIC_VECTOR(255 downto 0);
    signal km_key_valid         : STD_LOGIC;
    signal km_operation_complete: STD_LOGIC;
    signal km_system_status     : STD_LOGIC_VECTOR(7 downto 0);

    -- Performance Measurement
    signal throughput_start_time : time;
    signal throughput_data_count : integer := 0;
    signal measured_throughput   : real := 0.0;

    -- Test Data Arrays
    type test_data_array is array (0 to 15) of STD_LOGIC_VECTOR(127 downto 0);
    constant AES_TEST_VECTORS : test_data_array := (
        x"00112233445566778899aabbccddeeff",
        x"112233445566778899aabbccddeeff00",
        x"2233445566778899aabbccddeeff0011",
        x"33445566778899aabbccddeeff001122",
        x"445566778899aabbccddeeff00112233",
        x"5566778899aabbccddeeff0011223344",
        x"66778899aabbccddeeff001122334455",
        x"778899aabbccddeeff00112233445566",
        x"8899aabbccddeeff0011223344556677",
        x"99aabbccddeeff001122334455667788",
        x"aabbccddeeff00112233445566778899",
        x"bbccddeeff00112233445566778899aa",
        x"ccddeeff00112233445566778899aabb",
        x"ddeeff00112233445566778899aabbcc",
        x"eeff00112233445566778899aabbccdd",
        x"ff00112233445566778899aabbccddee"
    );

    -- Component Declarations
    component aes_crypto_accelerator
        Generic (
            KEY_WIDTH       : integer := 256;
            BLOCK_WIDTH     : integer := 128;
            NUM_ROUNDS      : integer := 14;
            PIPELINE_STAGES : integer := 16
        );
        Port (
            clk           : in  STD_LOGIC;
            rst_n         : in  STD_LOGIC;
            enable        : in  STD_LOGIC;
            key           : in  STD_LOGIC_VECTOR(KEY_WIDTH-1 downto 0);
            iv            : in  STD_LOGIC_VECTOR(BLOCK_WIDTH-1 downto 0);
            data_in       : in  STD_LOGIC_VECTOR(BLOCK_WIDTH-1 downto 0);
            data_out      : out STD_LOGIC_VECTOR(BLOCK_WIDTH-1 downto 0);
            data_valid_in : in  STD_LOGIC;
            data_valid_out: out STD_LOGIC;
            encrypt       : in  STD_LOGIC;
            mode          : in  STD_LOGIC_VECTOR(2 downto 0)
        );
    end component;

    component hardware_security_module
        Generic (
            KEY_STORAGE_SIZE   : integer := 4096;
            TAMPER_SENSORS     : integer := 8;
            TEMP_THRESHOLD_HIGH: integer := 85;
            TEMP_THRESHOLD_LOW : integer := -40;
            CLOCK_FREQ_MHZ     : integer := 200
        );
        Port (
            clk                 : in  STD_LOGIC;
            rst_n               : in  STD_LOGIC;
            vcc_core            : in  STD_LOGIC_VECTOR(11 downto 0);
            vcc_aux             : in  STD_LOGIC_VECTOR(11 downto 0);
            temperature         : in  STD_LOGIC_VECTOR(11 downto 0);
            tamper_sensors      : in  STD_LOGIC_VECTOR(TAMPER_SENSORS-1 downto 0);
            mesh_integrity      : in  STD_LOGIC;
            case_switch         : in  STD_LOGIC;
            auth_request        : in  STD_LOGIC;
            auth_challenge      : in  STD_LOGIC_VECTOR(127 downto 0);
            auth_response       : out STD_LOGIC_VECTOR(255 downto 0);
            auth_valid          : out STD_LOGIC;
            key_request         : in  STD_LOGIC;
            key_id              : in  STD_LOGIC_VECTOR(7 downto 0);
            key_data            : out STD_LOGIC_VECTOR(255 downto 0);
            key_valid           : out STD_LOGIC;
            security_state      : out STD_LOGIC_VECTOR(3 downto 0);
            tamper_detected     : out STD_LOGIC;
            zeroization_complete: out STD_LOGIC
        );
    end component;

    component post_quantum_crypto
        Generic (
            KYBER_N        : integer := 256;
            KYBER_Q        : integer := 3329;
            KYBER_K        : integer := 4;
            PARALLEL_UNITS : integer := 4;
            DATA_WIDTH     : integer := 32
        );
        Port (
            clk                : in  STD_LOGIC;
            rst_n              : in  STD_LOGIC;
            operation_mode     : in  STD_LOGIC_VECTOR(3 downto 0);
            start_operation    : in  STD_LOGIC;
            operation_done     : out STD_LOGIC;
            operation_valid    : out STD_LOGIC;
            kyber_public_key   : in  STD_LOGIC_VECTOR(1567*8-1 downto 0);
            kyber_secret_key   : in  STD_LOGIC_VECTOR(3167*8-1 downto 0);
            kyber_shared_secret: out STD_LOGIC_VECTOR(255 downto 0);
            random_request     : out STD_LOGIC;
            random_data        : in  STD_LOGIC_VECTOR(255 downto 0);
            random_valid       : in  STD_LOGIC;
            error_flags        : out STD_LOGIC_VECTOR(7 downto 0)
        );
    end component;

    component high_throughput_pipeline
        Generic (
            TARGET_THROUGHPUT_GBPS : integer := 12;
            PARALLEL_ENGINES       : integer := 8;
            PIPELINE_DEPTH         : integer := 16;
            DATA_WIDTH             : integer := 512
        );
        Port (
            crypto_clk          : in  STD_LOGIC;
            system_clk          : in  STD_LOGIC;
            rst_n               : in  STD_LOGIC;
            algorithm_select    : in  STD_LOGIC_VECTOR(2 downto 0);
            operation_mode      : in  STD_LOGIC_VECTOR(1 downto 0);
            enable_pipeline     : in  STD_LOGIC;
            s_axis_tdata        : in  STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
            s_axis_tvalid       : in  STD_LOGIC;
            s_axis_tready       : out STD_LOGIC;
            s_axis_tlast        : in  STD_LOGIC;
            s_axis_tkeep        : in  STD_LOGIC_VECTOR(DATA_WIDTH/8-1 downto 0);
            m_axis_tdata        : out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
            m_axis_tvalid       : out STD_LOGIC;
            m_axis_tready       : in  STD_LOGIC;
            m_axis_tlast        : out STD_LOGIC;
            throughput_mbps     : out STD_LOGIC_VECTOR(31 downto 0);
            pipeline_ready      : out STD_LOGIC;
            pipeline_busy       : out STD_LOGIC
        );
    end component;

    component secure_key_manager
        Generic (
            MAX_KEYS           : integer := 1024;
            ACCESS_LEVELS      : integer := 4;
            DATA_WIDTH         : integer := 256
        );
        Port (
            clk                    : in  STD_LOGIC;
            rst_n                  : in  STD_LOGIC;
            security_level         : in  STD_LOGIC_VECTOR(1 downto 0);
            user_credentials       : in  STD_LOGIC_VECTOR(255 downto 0);
            authentication_token   : in  STD_LOGIC_VECTOR(127 downto 0);
            access_granted         : out STD_LOGIC;
            key_operation          : in  STD_LOGIC_VECTOR(3 downto 0);
            key_id                 : in  STD_LOGIC_VECTOR(15 downto 0);
            key_data_in            : in  STD_LOGIC_VECTOR(255 downto 0);
            key_data_out           : out STD_LOGIC_VECTOR(255 downto 0);
            key_valid              : out STD_LOGIC;
            key_operation_complete : out STD_LOGIC;
            system_status          : out STD_LOGIC_VECTOR(7 downto 0)
        );
    end component;

begin

    -- Clock Generation
    crypto_clk <= not crypto_clk after CLK_PERIOD/2;
    system_clk <= not system_clk after SYS_CLK_PERIOD/2;

    -- Reset Generation
    process
    begin
        rst_n <= '0';
        wait for 100 ns;
        rst_n <= '1';
        wait;
    end process;

    -- Component Instantiations
    uut_aes: aes_crypto_accelerator
        generic map (
            KEY_WIDTH       => AES_KEY_WIDTH,
            BLOCK_WIDTH     => 128,
            NUM_ROUNDS      => 14,
            PIPELINE_STAGES => 16
        )
        port map (
            clk             => crypto_clk,
            rst_n           => rst_n,
            enable          => aes_enable,
            key             => aes_key,
            iv              => aes_iv,
            data_in         => aes_data_in,
            data_out        => aes_data_out,
            data_valid_in   => aes_valid_in,
            data_valid_out  => aes_valid_out,
            encrypt         => aes_encrypt,
            mode            => aes_mode
        );

    uut_hsm: hardware_security_module
        generic map (
            KEY_STORAGE_SIZE    => 4096,
            TAMPER_SENSORS      => 8,
            TEMP_THRESHOLD_HIGH => 85,
            TEMP_THRESHOLD_LOW  => -40,
            CLOCK_FREQ_MHZ      => 200
        )
        port map (
            clk                 => system_clk,
            rst_n               => rst_n,
            vcc_core            => hsm_vcc_core,
            vcc_aux             => hsm_vcc_aux,
            temperature         => hsm_temperature,
            tamper_sensors      => hsm_tamper_sensors,
            mesh_integrity      => hsm_mesh_integrity,
            case_switch         => hsm_case_switch,
            auth_request        => hsm_auth_request,
            auth_challenge      => hsm_auth_challenge,
            auth_response       => hsm_auth_response,
            auth_valid          => hsm_auth_valid,
            key_request         => hsm_key_request,
            key_id              => hsm_key_id,
            key_data            => hsm_key_data,
            key_valid           => hsm_key_valid,
            security_state      => hsm_security_state,
            tamper_detected     => hsm_tamper_detected,
            zeroization_complete=> open
        );

    uut_pqc: post_quantum_crypto
        generic map (
            KYBER_N        => 256,
            KYBER_Q        => 3329,
            KYBER_K        => 4,
            PARALLEL_UNITS => 4,
            DATA_WIDTH     => 32
        )
        port map (
            clk                => crypto_clk,
            rst_n              => rst_n,
            operation_mode     => pqc_operation_mode,
            start_operation    => pqc_start_operation,
            operation_done     => pqc_operation_done,
            operation_valid    => pqc_operation_valid,
            kyber_public_key   => pqc_kyber_public_key,
            kyber_secret_key   => pqc_kyber_secret_key,
            kyber_shared_secret=> pqc_kyber_shared_secret,
            random_request     => pqc_random_request,
            random_data        => pqc_random_data,
            random_valid       => pqc_random_valid,
            error_flags        => pqc_error_flags
        );

    uut_pipeline: high_throughput_pipeline
        generic map (
            TARGET_THROUGHPUT_GBPS => 12,
            PARALLEL_ENGINES       => 8,
            PIPELINE_DEPTH         => 16,
            DATA_WIDTH             => DATA_WIDTH
        )
        port map (
            crypto_clk         => crypto_clk,
            system_clk         => system_clk,
            rst_n              => rst_n,
            algorithm_select   => pipeline_algorithm,
            operation_mode     => pipeline_operation,
            enable_pipeline    => pipeline_enable,
            s_axis_tdata       => pipeline_s_tdata,
            s_axis_tvalid      => pipeline_s_tvalid,
            s_axis_tready      => pipeline_s_tready,
            s_axis_tlast       => pipeline_s_tlast,
            s_axis_tkeep       => pipeline_s_tkeep,
            m_axis_tdata       => pipeline_m_tdata,
            m_axis_tvalid      => pipeline_m_tvalid,
            m_axis_tready      => pipeline_m_tready,
            m_axis_tlast       => pipeline_m_tlast,
            throughput_mbps    => pipeline_throughput,
            pipeline_ready     => pipeline_ready,
            pipeline_busy      => pipeline_busy
        );

    uut_keymgr: secure_key_manager
        generic map (
            MAX_KEYS      => 1024,
            ACCESS_LEVELS => 4,
            DATA_WIDTH    => 256
        )
        port map (
            clk                    => system_clk,
            rst_n                  => rst_n,
            security_level         => km_security_level,
            user_credentials       => km_user_credentials,
            authentication_token   => km_auth_token,
            access_granted         => km_access_granted,
            key_operation          => km_key_operation,
            key_id                 => km_key_id,
            key_data_in            => km_key_data_in,
            key_data_out           => km_key_data_out,
            key_valid              => km_key_valid,
            key_operation_complete => km_operation_complete,
            system_status          => km_system_status
        );

    -- Main Test Process
    test_process: process
        variable test_data    : STD_LOGIC_VECTOR(127 downto 0);
        variable expected_data: STD_LOGIC_VECTOR(127 downto 0);
        variable test_start   : time;
        variable test_end     : time;
        variable line_out     : line;
        
        -- Test procedure for AES functionality
        procedure test_aes_basic is
        begin
            report "Starting AES Basic Functionality Test";
            current_test <= 1;
            
            -- Setup test key and IV
            aes_key <= x"603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4";
            aes_iv  <= x"000102030405060708090a0b0c0d0e0f";
            aes_enable <= '1';
            aes_encrypt <= '1';
            aes_mode <= "000"; -- AES-256-CBC
            
            wait for 10 ns;
            
            -- Test encryption of multiple blocks
            for i in 0 to 7 loop
                aes_data_in <= AES_TEST_VECTORS(i);
                aes_valid_in <= '1';
                wait until rising_edge(crypto_clk);
                aes_valid_in <= '0';
                
                -- Wait for output
                wait until aes_valid_out = '1';
                wait for 5 ns;
                
                -- Basic validation (output should be different from input)
                if aes_data_out = aes_data_in then
                    report "ERROR: AES output equals input for test vector " & integer'image(i);
                    error_count <= error_count + 1;
                else
                    report "AES encryption test " & integer'image(i) & " passed";
                end if;
            end loop;
            
            aes_enable <= '0';
            report "AES Basic Functionality Test Complete";
        end procedure;

        -- Test procedure for HSM functionality
        procedure test_hsm_security is
        begin
            report "Starting HSM Security Test";
            current_test <= 2;
            
            -- Test normal operation
            hsm_tamper_sensors <= (others => '0');
            hsm_temperature <= x"800"; -- Normal temperature
            hsm_vcc_core <= x"555";    -- Normal voltage
            hsm_mesh_integrity <= '1';
            hsm_case_switch <= '0';
            
            wait for 100 ns;
            
            -- Check security state
            if hsm_security_state /= "0001" then -- Should be in SECURE_READY
                report "ERROR: HSM not in secure ready state";
                error_count <= error_count + 1;
            end if;
            
            -- Test authentication
            hsm_auth_challenge <= x"0123456789abcdef0123456789abcdef";
            hsm_auth_request <= '1';
            wait until rising_edge(system_clk);
            hsm_auth_request <= '0';
            
            wait until hsm_auth_valid = '1';
            if hsm_auth_response = (hsm_auth_response'range => '0') then
                report "ERROR: HSM authentication response is zero";
                error_count <= error_count + 1;
            else
                report "HSM authentication test passed";
            end if;
            
            -- Test tamper detection
            hsm_tamper_sensors(0) <= '1'; -- Trigger tamper
            wait for 50 ns;
            
            if hsm_tamper_detected /= '1' then
                report "ERROR: HSM tamper detection failed";
                error_count <= error_count + 1;
            else
                report "HSM tamper detection test passed";
            end if;
            
            -- Reset tamper
            hsm_tamper_sensors <= (others => '0');
            wait for 100 ns;
            
            report "HSM Security Test Complete";
        end procedure;

        -- Test procedure for Post-Quantum Crypto
        procedure test_post_quantum is
        begin
            report "Starting Post-Quantum Cryptography Test";
            current_test <= 3;
            
            -- Setup test keys (simplified)
            pqc_kyber_public_key <= (others => '1');
            pqc_kyber_secret_key <= (others => '0');
            
            -- Provide random data
            pqc_random_data <= x"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
            pqc_random_valid <= '1';
            
            -- Test Kyber key generation
            pqc_operation_mode <= "0001"; -- OP_KYBER_KEYGEN
            pqc_start_operation <= '1';
            wait until rising_edge(crypto_clk);
            pqc_start_operation <= '0';
            
            wait until pqc_operation_done = '1' or now > test_start + 10 us;
            
            if pqc_operation_done = '1' and pqc_operation_valid = '1' then
                report "Post-quantum key generation test passed";
            else
                report "ERROR: Post-quantum key generation failed";
                error_count <= error_count + 1;
            end if;
            
            wait for 100 ns;
            
            -- Test Kyber decryption
            pqc_operation_mode <= "0011"; -- OP_KYBER_DECRYPT
            pqc_start_operation <= '1';
            wait until rising_edge(crypto_clk);
            pqc_start_operation <= '0';
            
            wait until pqc_operation_done = '1' or now > test_start + 20 us;
            
            if pqc_operation_done = '1' and pqc_operation_valid = '1' then
                report "Post-quantum decryption test passed";
            else
                report "ERROR: Post-quantum decryption failed";
                error_count <= error_count + 1;
            end if;
            
            pqc_random_valid <= '0';
            report "Post-Quantum Cryptography Test Complete";
        end procedure;

        -- Test procedure for High-Throughput Pipeline
        procedure test_high_throughput is
        begin
            report "Starting High-Throughput Pipeline Test";
            current_test <= 4;
            
            pipeline_enable <= '1';
            pipeline_algorithm <= "000"; -- AES-GCM
            pipeline_operation <= "01";  -- Encrypt
            pipeline_m_tready <= '1';
            
            wait until pipeline_ready = '1';
            
            throughput_start_time <= now;
            throughput_data_count <= 0;
            
            -- Send continuous data stream for throughput test
            for i in 0 to 999 loop
                pipeline_s_tdata <= std_logic_vector(to_unsigned(i, DATA_WIDTH));
                pipeline_s_tvalid <= '1';
                if i = 999 then
                    pipeline_s_tlast <= '1';
                end if;
                
                wait until rising_edge(crypto_clk) and pipeline_s_tready = '1';
                
                if pipeline_m_tvalid = '1' then
                    throughput_data_count <= throughput_data_count + 1;
                end if;
            end loop;
            
            pipeline_s_tvalid <= '0';
            pipeline_s_tlast <= '0';
            
            -- Wait for pipeline to complete
            wait until pipeline_busy = '0';
            
            -- Calculate throughput
            measured_throughput <= real(throughput_data_count * DATA_WIDTH) / 
                                 real((now - throughput_start_time) / 1 ns) * 1000.0;
            
            if measured_throughput >= real(PERFORMANCE_TARGET) then
                report "High-throughput pipeline test passed: " & 
                       real'image(measured_throughput) & " Mbps";
            else
                report "ERROR: Throughput below target: " & 
                       real'image(measured_throughput) & " Mbps";
                error_count <= error_count + 1;
            end if;
            
            pipeline_enable <= '0';
            report "High-Throughput Pipeline Test Complete";
        end procedure;

        -- Test procedure for Key Manager
        procedure test_key_manager is
        begin
            report "Starting Key Manager Test";
            current_test <= 5;
            
            -- Setup authentication
            km_user_credentials <= x"deadbeefcafeba00deadbeefcafeba00deadbeefcafeba00deadbeefcafeba00";
            km_auth_token <= x"deadbeefcafeba00deadbeefcafeba00";
            
            wait for 100 ns;
            
            -- Test key storage
            km_key_operation <= "0010"; -- OP_KEY_STORE
            km_key_id <= x"0001";
            km_key_data_in <= x"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
            
            wait until rising_edge(system_clk);
            km_key_operation <= "0000";
            
            wait until km_operation_complete = '1';
            
            if km_access_granted = '1' then
                report "Key storage authentication passed";
            else
                report "ERROR: Key storage authentication failed";
                error_count <= error_count + 1;
            end if;
            
            wait for 50 ns;
            
            -- Test key retrieval
            km_key_operation <= "0011"; -- OP_KEY_RETRIEVE
            km_key_id <= x"0001";
            
            wait until rising_edge(system_clk);
            km_key_operation <= "0000";
            
            wait until km_operation_complete = '1';
            
            if km_key_valid = '1' and 
               km_key_data_out = x"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" then
                report "Key retrieval test passed";
            else
                report "ERROR: Key retrieval failed";
                error_count <= error_count + 1;
            end if;
            
            report "Key Manager Test Complete";
        end procedure;

    begin
        -- Wait for reset
        wait until rst_n = '1';
        wait for 100 ns;
        
        test_start := now;
        
        -- Run all tests
        test_aes_basic;
        wait for 1 us;
        
        test_hsm_security;
        wait for 1 us;
        
        test_post_quantum;
        wait for 5 us;
        
        test_high_throughput;
        wait for 2 us;
        
        test_key_manager;
        wait for 1 us;
        
        test_end := now;
        
        -- Final Results
        report "=== AEGIS-SE Phase 10 Cryptographic Modules Test Results ===";
        report "Total test time: " & time'image(test_end - test_start);
        report "Total errors: " & integer'image(error_count);
        
        if error_count = 0 then
            report "*** ALL TESTS PASSED ***";
            test_pass <= '1';
        else
            report "*** SOME TESTS FAILED ***";
            test_pass <= '0';
        end if;
        
        test_complete <= '1';
        wait;
    end process;

    -- Timeout Process
    timeout_process: process
    begin
        wait for TEST_TIMEOUT;
        if test_complete = '0' then
            report "ERROR: Test timeout reached";
            error_count <= error_count + 1;
            test_complete <= '1';
        end if;
        wait;
    end process;

    -- Random Data Generator for PQC
    random_gen_process: process(crypto_clk)
        variable seed1, seed2 : positive := 1;
        variable rand_val : real;
    begin
        if rising_edge(crypto_clk) then
            if pqc_random_request = '1' then
                -- Simple LFSR-based random number generation
                pqc_random_data <= pqc_random_data(254 downto 0) & 
                                  (pqc_random_data(255) xor pqc_random_data(253) xor 
                                   pqc_random_data(251) xor pqc_random_data(248));
                pqc_random_valid <= '1';
            else
                pqc_random_valid <= '0';
            end if;
        end if;
    end process;

end Behavioral;