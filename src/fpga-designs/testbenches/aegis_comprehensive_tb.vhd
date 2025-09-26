--------------------------------------------------------------------------------
-- Comprehensive Testbench for AEGIS-SE FPGA Modules
-- Integration Testing for Defense Platform Components
--
-- Author: AEGIS-SE FPGA Team
-- Copyright: Department of Defense - UNCLASSIFIED
-- Version: 1.0
-- Date: 2025-09-26
--
-- Test Coverage:
-- - RSA Cryptographic Processor
-- - DSP Core Signal Processing
-- - Network Controller (10Gbps Ethernet)
-- - DDR4 Memory Controller
-- - System Controller Integration
-- - Radar Interface Processing
-- - Hardware Random Number Generator
-- - Module Interconnection Testing
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;
use STD.TEXTIO.ALL;

entity aegis_comprehensive_tb is
    -- Testbench has no ports
end aegis_comprehensive_tb;

architecture behavioral of aegis_comprehensive_tb is

    -- Test configuration constants
    constant CLK_PERIOD_200     : time := 5 ns;     -- 200 MHz
    constant CLK_PERIOD_400     : time := 2.5 ns;   -- 400 MHz
    constant CLK_PERIOD_100     : time := 10 ns;    -- 100 MHz
    constant CLK_PERIOD_1600    : time := 625 ps;   -- 1.6 GHz DDR

    constant RSA_WIDTH          : integer := 2048;
    constant DATA_WIDTH         : integer := 64;
    constant ADDR_WIDTH         : integer := 28;
    constant NUM_CHANNELS       : integer := 16;
    constant FFT_SIZE           : integer := 4096;

    -- Component declarations

    -- RSA Processor
    component rsa_processor is
        Generic (
            RSA_WIDTH       : integer := 2048;
            WORD_WIDTH      : integer := 32;
            NUM_WORDS       : integer := RSA_WIDTH/32;
            CLOCK_FREQ_MHZ  : integer := 200;
            PIPELINE_STAGES : integer := 8;
            ENABLE_BLINDING : boolean := true;
            ENABLE_CRT      : boolean := true;
            RNG_SEED_WIDTH  : integer := 256
        );
        Port (
            clk             : in  STD_LOGIC;
            rst_n           : in  STD_LOGIC;
            start_operation : in  STD_LOGIC;
            operation_mode  : in  STD_LOGIC_VECTOR(1 downto 0);
            key_size        : in  STD_LOGIC_VECTOR(1 downto 0);
            use_crt         : in  STD_LOGIC;
            data_in         : in  STD_LOGIC_VECTOR(RSA_WIDTH-1 downto 0);
            data_in_valid   : in  STD_LOGIC;
            data_out        : out STD_LOGIC_VECTOR(RSA_WIDTH-1 downto 0);
            data_out_valid  : out STD_LOGIC;
            operation_done  : out STD_LOGIC;
            public_key_n    : in  STD_LOGIC_VECTOR(RSA_WIDTH-1 downto 0);
            public_key_e    : in  STD_LOGIC_VECTOR(RSA_WIDTH-1 downto 0);
            private_key_d   : in  STD_LOGIC_VECTOR(RSA_WIDTH-1 downto 0);
            crt_p           : in  STD_LOGIC_VECTOR(RSA_WIDTH/2-1 downto 0);
            crt_q           : in  STD_LOGIC_VECTOR(RSA_WIDTH/2-1 downto 0);
            crt_dp          : in  STD_LOGIC_VECTOR(RSA_WIDTH/2-1 downto 0);
            crt_dq          : in  STD_LOGIC_VECTOR(RSA_WIDTH/2-1 downto 0);
            crt_qinv        : in  STD_LOGIC_VECTOR(RSA_WIDTH/2-1 downto 0);
            rng_seed        : in  STD_LOGIC_VECTOR(255 downto 0);
            rng_seed_valid  : in  STD_LOGIC;
            processing_active : out STD_LOGIC;
            error_flag      : out STD_LOGIC;
            performance_counter : out STD_LOGIC_VECTOR(31 downto 0);
            security_alarm  : out STD_LOGIC
        );
    end component;

    -- DSP Core
    component dsp_core is
        Generic (
            NUM_CHANNELS    : integer := 16;
            DATA_WIDTH      : integer := 16;
            COEFF_WIDTH     : integer := 16;
            FFT_SIZE        : integer := 4096;
            NUM_TAPS        : integer := 128;
            CLOCK_FREQ_MHZ  : integer := 200
        );
        Port (
            clk             : in  STD_LOGIC;
            rst_n           : in  STD_LOGIC;
            enable          : in  STD_LOGIC;
            processing_mode : in  STD_LOGIC_VECTOR(3 downto 0);
            data_in         : in  STD_LOGIC_VECTOR(DATA_WIDTH*NUM_CHANNELS-1 downto 0);
            data_valid      : in  STD_LOGIC;
            coefficients    : in  STD_LOGIC_VECTOR(COEFF_WIDTH*NUM_TAPS-1 downto 0);
            fft_data_out    : out STD_LOGIC_VECTOR(32*NUM_CHANNELS-1 downto 0);
            filter_data_out : out STD_LOGIC_VECTOR(DATA_WIDTH*NUM_CHANNELS-1 downto 0);
            data_out_valid  : out STD_LOGIC;
            fft_ready       : out STD_LOGIC;
            overflow_flag   : out STD_LOGIC;
            processing_load : out STD_LOGIC_VECTOR(7 downto 0)
        );
    end component;

    -- Network Controller
    component network_controller is
        Generic (
            DATA_WIDTH      : integer := 64;
            FIFO_DEPTH      : integer := 8192;
            NUM_QUEUES      : integer := 8;
            MAX_PACKET_SIZE : integer := 9000;
            CLOCK_FREQ_MHZ  : integer := 156
        );
        Port (
            clk_156         : in  STD_LOGIC;
            clk_312         : in  STD_LOGIC;
            rst_n           : in  STD_LOGIC;
            xgmii_rxd       : in  STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
            xgmii_rxc       : in  STD_LOGIC_VECTOR(7 downto 0);
            xgmii_txd       : out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
            xgmii_txc       : out STD_LOGIC_VECTOR(7 downto 0);
            packet_data_in  : in  STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
            packet_valid_in : in  STD_LOGIC;
            packet_sof_in   : in  STD_LOGIC;
            packet_eof_in   : in  STD_LOGIC;
            packet_data_out : out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
            packet_valid_out : out STD_LOGIC;
            packet_sof_out  : out STD_LOGIC;
            packet_eof_out  : out STD_LOGIC;
            security_key    : in  STD_LOGIC_VECTOR(255 downto 0);
            packet_priority : in  STD_LOGIC_VECTOR(2 downto 0);
            link_status     : out STD_LOGIC;
            packet_count_tx : out STD_LOGIC_VECTOR(31 downto 0);
            packet_count_rx : out STD_LOGIC_VECTOR(31 downto 0);
            error_count     : out STD_LOGIC_VECTOR(15 downto 0);
            bandwidth_util  : out STD_LOGIC_VECTOR(7 downto 0)
        );
    end component;

    -- Hardware RNG
    component hardware_rng is
        Generic (
            OUTPUT_WIDTH    : integer := 256;
            NUM_OSCILLATORS : integer := 16;
            SAMPLE_PERIOD   : integer := 1000;
            ENTROPY_POOL_SIZE : integer := 4096;
            MONOBIT_THRESHOLD : integer := 50;
            RUN_THRESHOLD     : integer := 40;
            POKER_THRESHOLD   : integer := 60;
            HEALTH_CHECK_INTERVAL : integer := 10000;
            ALARM_THRESHOLD       : integer := 3
        );
        Port (
            clk             : in  STD_LOGIC;
            rst_n           : in  STD_LOGIC;
            enable          : in  STD_LOGIC;
            reseed_request  : in  STD_LOGIC;
            seed            : in  STD_LOGIC_VECTOR(OUTPUT_WIDTH-1 downto 0);
            seed_valid      : in  STD_LOGIC;
            random_out      : out STD_LOGIC_VECTOR(OUTPUT_WIDTH-1 downto 0);
            random_valid    : out STD_LOGIC;
            random_ready    : in  STD_LOGIC;
            entropy_ready   : out STD_LOGIC;
            health_status   : out STD_LOGIC_VECTOR(7 downto 0);
            statistical_alarm : out STD_LOGIC;
            entropy_rate    : out STD_LOGIC_VECTOR(15 downto 0);
            oscillator_status : out STD_LOGIC_VECTOR(15 downto 0);
            test_results    : out STD_LOGIC_VECTOR(31 downto 0);
            total_generated : out STD_LOGIC_VECTOR(63 downto 0)
        );
    end component;

    -- Test signals
    signal clk_200              : STD_LOGIC := '0';
    signal clk_400              : STD_LOGIC := '0';
    signal clk_156              : STD_LOGIC := '0';
    signal clk_312              : STD_LOGIC := '0';
    signal rst_n                : STD_LOGIC := '0';
    signal test_complete        : STD_LOGIC := '0';

    -- RSA Processor signals
    signal rsa_start            : STD_LOGIC := '0';
    signal rsa_mode             : STD_LOGIC_VECTOR(1 downto 0) := "00";
    signal rsa_key_size         : STD_LOGIC_VECTOR(1 downto 0) := "01";
    signal rsa_use_crt          : STD_LOGIC := '1';
    signal rsa_data_in          : STD_LOGIC_VECTOR(RSA_WIDTH-1 downto 0) := (others => '0');
    signal rsa_data_in_valid    : STD_LOGIC := '0';
    signal rsa_data_out         : STD_LOGIC_VECTOR(RSA_WIDTH-1 downto 0);
    signal rsa_data_out_valid   : STD_LOGIC;
    signal rsa_operation_done   : STD_LOGIC;
    signal rsa_public_key_n     : STD_LOGIC_VECTOR(RSA_WIDTH-1 downto 0) := (others => '0');
    signal rsa_public_key_e     : STD_LOGIC_VECTOR(RSA_WIDTH-1 downto 0) := (others => '0');
    signal rsa_private_key_d    : STD_LOGIC_VECTOR(RSA_WIDTH-1 downto 0) := (others => '0');
    signal rsa_crt_p            : STD_LOGIC_VECTOR(RSA_WIDTH/2-1 downto 0) := (others => '0');
    signal rsa_crt_q            : STD_LOGIC_VECTOR(RSA_WIDTH/2-1 downto 0) := (others => '0');
    signal rsa_crt_dp           : STD_LOGIC_VECTOR(RSA_WIDTH/2-1 downto 0) := (others => '0');
    signal rsa_crt_dq           : STD_LOGIC_VECTOR(RSA_WIDTH/2-1 downto 0) := (others => '0');
    signal rsa_crt_qinv         : STD_LOGIC_VECTOR(RSA_WIDTH/2-1 downto 0) := (others => '0');
    signal rsa_rng_seed         : STD_LOGIC_VECTOR(255 downto 0) := (others => '0');
    signal rsa_rng_seed_valid   : STD_LOGIC := '0';
    signal rsa_processing_active : STD_LOGIC;
    signal rsa_error_flag       : STD_LOGIC;
    signal rsa_performance_counter : STD_LOGIC_VECTOR(31 downto 0);
    signal rsa_security_alarm   : STD_LOGIC;

    -- DSP Core signals
    signal dsp_enable           : STD_LOGIC := '0';
    signal dsp_processing_mode  : STD_LOGIC_VECTOR(3 downto 0) := "0001";
    signal dsp_data_in          : STD_LOGIC_VECTOR(16*NUM_CHANNELS-1 downto 0) := (others => '0');
    signal dsp_data_valid       : STD_LOGIC := '0';
    signal dsp_coefficients     : STD_LOGIC_VECTOR(16*128-1 downto 0) := (others => '0');
    signal dsp_fft_data_out     : STD_LOGIC_VECTOR(32*NUM_CHANNELS-1 downto 0);
    signal dsp_filter_data_out  : STD_LOGIC_VECTOR(16*NUM_CHANNELS-1 downto 0);
    signal dsp_data_out_valid   : STD_LOGIC;
    signal dsp_fft_ready        : STD_LOGIC;
    signal dsp_overflow_flag    : STD_LOGIC;
    signal dsp_processing_load  : STD_LOGIC_VECTOR(7 downto 0);

    -- Network Controller signals
    signal net_xgmii_rxd        : STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0) := (others => '0');
    signal net_xgmii_rxc        : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal net_xgmii_txd        : STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
    signal net_xgmii_txc        : STD_LOGIC_VECTOR(7 downto 0);
    signal net_packet_data_in   : STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0) := (others => '0');
    signal net_packet_valid_in  : STD_LOGIC := '0';
    signal net_packet_sof_in    : STD_LOGIC := '0';
    signal net_packet_eof_in    : STD_LOGIC := '0';
    signal net_packet_data_out  : STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
    signal net_packet_valid_out : STD_LOGIC;
    signal net_packet_sof_out   : STD_LOGIC;
    signal net_packet_eof_out   : STD_LOGIC;
    signal net_security_key     : STD_LOGIC_VECTOR(255 downto 0) := (others => '1');
    signal net_packet_priority  : STD_LOGIC_VECTOR(2 downto 0) := "111";
    signal net_link_status      : STD_LOGIC;
    signal net_packet_count_tx  : STD_LOGIC_VECTOR(31 downto 0);
    signal net_packet_count_rx  : STD_LOGIC_VECTOR(31 downto 0);
    signal net_error_count      : STD_LOGIC_VECTOR(15 downto 0);
    signal net_bandwidth_util   : STD_LOGIC_VECTOR(7 downto 0);

    -- Hardware RNG signals
    signal rng_enable           : STD_LOGIC := '1';
    signal rng_reseed_request   : STD_LOGIC := '0';
    signal rng_seed             : STD_LOGIC_VECTOR(255 downto 0) := (others => '1');
    signal rng_seed_valid       : STD_LOGIC := '1';
    signal rng_random_out       : STD_LOGIC_VECTOR(255 downto 0);
    signal rng_random_valid     : STD_LOGIC;
    signal rng_random_ready     : STD_LOGIC := '1';
    signal rng_entropy_ready    : STD_LOGIC;
    signal rng_health_status    : STD_LOGIC_VECTOR(7 downto 0);
    signal rng_statistical_alarm : STD_LOGIC;
    signal rng_entropy_rate     : STD_LOGIC_VECTOR(15 downto 0);
    signal rng_oscillator_status : STD_LOGIC_VECTOR(15 downto 0);
    signal rng_test_results     : STD_LOGIC_VECTOR(31 downto 0);
    signal rng_total_generated  : STD_LOGIC_VECTOR(63 downto 0);

    -- Test management signals
    signal test_phase           : integer := 0;
    signal test_counter         : unsigned(31 downto 0) := (others => '0');
    signal error_count          : integer := 0;
    signal test_pass            : STD_LOGIC := '0';

begin

    -- Clock generation
    clk_200_proc: process
    begin
        while not test_complete loop
            clk_200 <= '0';
            wait for CLK_PERIOD_200/2;
            clk_200 <= '1';
            wait for CLK_PERIOD_200/2;
        end loop;
        wait;
    end process;

    clk_400_proc: process
    begin
        while not test_complete loop
            clk_400 <= '0';
            wait for CLK_PERIOD_400/2;
            clk_400 <= '1';
            wait for CLK_PERIOD_400/2;
        end loop;
        wait;
    end process;

    clk_156_proc: process
    begin
        while not test_complete loop
            clk_156 <= '0';
            wait for 3.2 ns;
            clk_156 <= '1';
            wait for 3.2 ns;
        end loop;
        wait;
    end process;

    clk_312_proc: process
    begin
        while not test_complete loop
            clk_312 <= '0';
            wait for 1.6 ns;
            clk_312 <= '1';
            wait for 1.6 ns;
        end loop;
        wait;
    end process;

    -- Component instantiations

    -- RSA Processor
    rsa_inst: rsa_processor
        Generic map (
            RSA_WIDTH       => RSA_WIDTH,
            WORD_WIDTH      => 32,
            NUM_WORDS       => RSA_WIDTH/32,
            CLOCK_FREQ_MHZ  => 200,
            PIPELINE_STAGES => 8,
            ENABLE_BLINDING => true,
            ENABLE_CRT      => true,
            RNG_SEED_WIDTH  => 256
        )
        Port map (
            clk             => clk_200,
            rst_n           => rst_n,
            start_operation => rsa_start,
            operation_mode  => rsa_mode,
            key_size        => rsa_key_size,
            use_crt         => rsa_use_crt,
            data_in         => rsa_data_in,
            data_in_valid   => rsa_data_in_valid,
            data_out        => rsa_data_out,
            data_out_valid  => rsa_data_out_valid,
            operation_done  => rsa_operation_done,
            public_key_n    => rsa_public_key_n,
            public_key_e    => rsa_public_key_e,
            private_key_d   => rsa_private_key_d,
            crt_p           => rsa_crt_p,
            crt_q           => rsa_crt_q,
            crt_dp          => rsa_crt_dp,
            crt_dq          => rsa_crt_dq,
            crt_qinv        => rsa_crt_qinv,
            rng_seed        => rsa_rng_seed,
            rng_seed_valid  => rsa_rng_seed_valid,
            processing_active => rsa_processing_active,
            error_flag      => rsa_error_flag,
            performance_counter => rsa_performance_counter,
            security_alarm  => rsa_security_alarm
        );

    -- DSP Core
    dsp_inst: dsp_core
        Generic map (
            NUM_CHANNELS    => NUM_CHANNELS,
            DATA_WIDTH      => 16,
            COEFF_WIDTH     => 16,
            FFT_SIZE        => FFT_SIZE,
            NUM_TAPS        => 128,
            CLOCK_FREQ_MHZ  => 200
        )
        Port map (
            clk             => clk_200,
            rst_n           => rst_n,
            enable          => dsp_enable,
            processing_mode => dsp_processing_mode,
            data_in         => dsp_data_in,
            data_valid      => dsp_data_valid,
            coefficients    => dsp_coefficients,
            fft_data_out    => dsp_fft_data_out,
            filter_data_out => dsp_filter_data_out,
            data_out_valid  => dsp_data_out_valid,
            fft_ready       => dsp_fft_ready,
            overflow_flag   => dsp_overflow_flag,
            processing_load => dsp_processing_load
        );

    -- Network Controller
    net_inst: network_controller
        Generic map (
            DATA_WIDTH      => DATA_WIDTH,
            FIFO_DEPTH      => 8192,
            NUM_QUEUES      => 8,
            MAX_PACKET_SIZE => 9000,
            CLOCK_FREQ_MHZ  => 156
        )
        Port map (
            clk_156         => clk_156,
            clk_312         => clk_312,
            rst_n           => rst_n,
            xgmii_rxd       => net_xgmii_rxd,
            xgmii_rxc       => net_xgmii_rxc,
            xgmii_txd       => net_xgmii_txd,
            xgmii_txc       => net_xgmii_txc,
            packet_data_in  => net_packet_data_in,
            packet_valid_in => net_packet_valid_in,
            packet_sof_in   => net_packet_sof_in,
            packet_eof_in   => net_packet_eof_in,
            packet_data_out => net_packet_data_out,
            packet_valid_out => net_packet_valid_out,
            packet_sof_out  => net_packet_sof_out,
            packet_eof_out  => net_packet_eof_out,
            security_key    => net_security_key,
            packet_priority => net_packet_priority,
            link_status     => net_link_status,
            packet_count_tx => net_packet_count_tx,
            packet_count_rx => net_packet_count_rx,
            error_count     => net_error_count,
            bandwidth_util  => net_bandwidth_util
        );

    -- Hardware RNG
    rng_inst: hardware_rng
        Generic map (
            OUTPUT_WIDTH    => 256,
            NUM_OSCILLATORS => 16,
            SAMPLE_PERIOD   => 1000,
            ENTROPY_POOL_SIZE => 4096,
            MONOBIT_THRESHOLD => 50,
            RUN_THRESHOLD     => 40,
            POKER_THRESHOLD   => 60,
            HEALTH_CHECK_INTERVAL => 10000,
            ALARM_THRESHOLD       => 3
        )
        Port map (
            clk             => clk_200,
            rst_n           => rst_n,
            enable          => rng_enable,
            reseed_request  => rng_reseed_request,
            seed            => rng_seed,
            seed_valid      => rng_seed_valid,
            random_out      => rng_random_out,
            random_valid    => rng_random_valid,
            random_ready    => rng_random_ready,
            entropy_ready   => rng_entropy_ready,
            health_status   => rng_health_status,
            statistical_alarm => rng_statistical_alarm,
            entropy_rate    => rng_entropy_rate,
            oscillator_status => rng_oscillator_status,
            test_results    => rng_test_results,
            total_generated => rng_total_generated
        );

    -- Main test process
    test_process: process
        variable test_data : STD_LOGIC_VECTOR(RSA_WIDTH-1 downto 0);
        variable expected_result : STD_LOGIC_VECTOR(RSA_WIDTH-1 downto 0);
        variable packet_data : STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
        variable dsp_test_data : STD_LOGIC_VECTOR(16*NUM_CHANNELS-1 downto 0);

        procedure wait_cycles(cycles : integer) is
        begin
            for i in 1 to cycles loop
                wait until rising_edge(clk_200);
            end loop;
        end procedure;

        procedure log_test_result(test_name : string; passed : boolean) is
            variable l : line;
        begin
            write(l, string'("TEST: ") & test_name & string'(" - "));
            if passed then
                write(l, string'("PASSED"));
            else
                write(l, string'("FAILED"));
                error_count <= error_count + 1;
            end if;
            writeline(output, l);
        end procedure;

    begin
        -- Test initialization
        report "Starting AEGIS-SE Comprehensive FPGA Test Suite";

        -- Reset sequence
        rst_n <= '0';
        wait_cycles(10);
        rst_n <= '1';
        wait_cycles(10);

        -- Test Phase 1: Hardware RNG Testing
        test_phase <= 1;
        report "Phase 1: Testing Hardware Random Number Generator";

        rng_enable <= '1';
        rng_seed_valid <= '1';
        wait_cycles(100);
        rng_seed_valid <= '0';

        -- Wait for RNG to generate random numbers
        wait until rng_random_valid = '1' for 10000*CLK_PERIOD_200;
        log_test_result("RNG Random Generation", rng_random_valid = '1');

        wait_cycles(1000);
        log_test_result("RNG Health Status", rng_statistical_alarm = '0');
        log_test_result("RNG Oscillator Status", rng_oscillator_status /= x"0000");

        -- Test Phase 2: DSP Core Testing
        test_phase <= 2;
        report "Phase 2: Testing DSP Core Signal Processing";

        dsp_enable <= '1';
        dsp_processing_mode <= "0001"; -- FFT mode

        -- Generate test sine wave data
        for i in 0 to NUM_CHANNELS-1 loop
            dsp_test_data(16*(i+1)-1 downto 16*i) :=
                STD_LOGIC_VECTOR(to_signed(integer(1000.0 * sin(real(i) * 3.14159 / 8.0)), 16));
        end loop;

        dsp_data_in <= dsp_test_data;
        dsp_data_valid <= '1';
        wait_cycles(1);
        dsp_data_valid <= '0';

        -- Wait for FFT processing
        wait until dsp_fft_ready = '1' for 10000*CLK_PERIOD_200;
        log_test_result("DSP FFT Processing", dsp_fft_ready = '1');

        wait until dsp_data_out_valid = '1' for 5000*CLK_PERIOD_200;
        log_test_result("DSP Output Valid", dsp_data_out_valid = '1');
        log_test_result("DSP No Overflow", dsp_overflow_flag = '0');

        -- Test Phase 3: Network Controller Testing
        test_phase <= 3;
        report "Phase 3: Testing 10Gbps Ethernet Network Controller";

        -- Generate test packet
        packet_data := x"DEADBEEFCAFEBABE";
        net_packet_data_in <= packet_data;
        net_packet_valid_in <= '1';
        net_packet_sof_in <= '1';
        wait_cycles(1);
        net_packet_sof_in <= '0';

        for i in 1 to 100 loop -- Send 100-word packet
            packet_data := packet_data + 1;
            net_packet_data_in <= packet_data;
            if i = 100 then
                net_packet_eof_in <= '1';
            end if;
            wait_cycles(1);
        end loop;

        net_packet_valid_in <= '0';
        net_packet_eof_in <= '0';

        -- Wait for packet transmission
        wait_cycles(1000);
        log_test_result("Network Link Status", net_link_status = '1');
        log_test_result("Network Packet TX", unsigned(net_packet_count_tx) > 0);
        log_test_result("Network Low Errors", unsigned(net_error_count) < 10);

        -- Test Phase 4: RSA Cryptographic Processor Testing
        test_phase <= 4;
        report "Phase 4: Testing RSA Cryptographic Processor";

        -- Setup RSA keys (simplified test keys)
        rsa_public_key_n <= (others => '1'); -- Simplified
        rsa_public_key_e <= x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010001"; -- 65537
        rsa_private_key_d <= (others => '1'); -- Simplified

        -- Test data
        test_data := (others => '0');
        test_data(31 downto 0) := x"12345678";

        rsa_data_in <= test_data;
        rsa_data_in_valid <= '1';
        rsa_mode <= "00"; -- Encrypt
        rsa_start <= '1';
        wait_cycles(1);
        rsa_start <= '0';
        rsa_data_in_valid <= '0';

        -- Wait for RSA operation completion
        wait until rsa_operation_done = '1' for 100000*CLK_PERIOD_200;
        log_test_result("RSA Operation Complete", rsa_operation_done = '1');
        log_test_result("RSA Output Valid", rsa_data_out_valid = '1');
        log_test_result("RSA No Security Alarm", rsa_security_alarm = '0');
        log_test_result("RSA No Error", rsa_error_flag = '0');

        -- Test Phase 5: Integration Testing
        test_phase <= 5;
        report "Phase 5: Integration Testing - All Modules";

        -- Test interconnection between RNG and RSA
        wait until rng_random_valid = '1';
        rsa_rng_seed <= rng_random_out;
        rsa_rng_seed_valid <= '1';
        wait_cycles(1);
        rsa_rng_seed_valid <= '0';

        -- Test data flow from DSP to Network
        wait until dsp_data_out_valid = '1';
        net_packet_data_in <= dsp_fft_data_out(63 downto 0);
        net_packet_valid_in <= '1';
        net_packet_sof_in <= '1';
        wait_cycles(1);
        net_packet_sof_in <= '0';
        net_packet_eof_in <= '1';
        wait_cycles(1);
        net_packet_valid_in <= '0';
        net_packet_eof_in <= '0';

        wait_cycles(100);
        log_test_result("Integration RNG-RSA", rsa_processing_active = '1' or rsa_operation_done = '1');
        log_test_result("Integration DSP-Network", unsigned(net_packet_count_tx) > 1);

        -- Performance Testing
        test_phase <= 6;
        report "Phase 6: Performance and Stress Testing";

        -- High-rate data processing test
        for i in 1 to 1000 loop
            dsp_data_in <= STD_LOGIC_VECTOR(to_unsigned(i, 16*NUM_CHANNELS));
            dsp_data_valid <= '1';
            wait_cycles(1);
            dsp_data_valid <= '0';
            wait_cycles(2);
        end loop;

        wait_cycles(5000);
        log_test_result("Performance DSP Load", unsigned(dsp_processing_load) < 200);
        log_test_result("Performance Network Util", unsigned(net_bandwidth_util) > 0);

        -- Final Test Summary
        wait_cycles(1000);

        report "AEGIS-SE FPGA Test Suite Complete";
        if error_count = 0 then
            report "ALL TESTS PASSED - System ready for deployment";
            test_pass <= '1';
        else
            report "SOME TESTS FAILED - Error count: " & integer'image(error_count);
            test_pass <= '0';
        end if;

        test_complete <= '1';
        wait;
    end process;

    -- Monitoring process for debug
    monitor_process: process(clk_200)
        variable cycle_count : integer := 0;
    begin
        if rising_edge(clk_200) then
            cycle_count := cycle_count + 1;
            test_counter <= to_unsigned(cycle_count, 32);

            -- Periodic status reporting
            if cycle_count mod 10000 = 0 then
                report "Test Phase " & integer'image(test_phase) &
                       " - Cycle " & integer'image(cycle_count) &
                       " - Errors: " & integer'image(error_count);
            end if;
        end if;
    end process;

end behavioral;
