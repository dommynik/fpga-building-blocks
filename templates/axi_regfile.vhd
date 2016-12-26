library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity {{MODULE_NAME}} is
  port (
    -- status ports
    {%- for reg in registers|selectattr("mode", "equalto", "stat") %}
    {{reg.label.ljust(JUST_WIDTH)}} : in  std_logic_vector({{REGISTER_WIDTH-1}} downto 0);
    {%- endfor %}

    -- control ports
    {%- for reg in registers|selectattr("mode", "equalto", "ctrl") %}
    {{reg.label.ljust(JUST_WIDTH)}} : out std_logic_vector({{REGISTER_WIDTH-1}} downto 0);
    {%- endfor %}

    -- trigger ports
    {%- for reg in registers|selectattr("mode", "equalto", "trig") %}
    {{reg.label.ljust(JUST_WIDTH)}} : out std_logic_vector({{REGISTER_WIDTH-1}} downto 0);
    {%- endfor %}

    -- AXI slave
    s_axi_aclk    : in  std_logic;
    s_axi_aresetn : in  std_logic;
    s_axi_awaddr  : in  std_logic_vector({{AXI_ADDR_WIDTH-1}} downto 0);
    s_axi_awprot  : in  std_logic_vector(2 downto 0);
    s_axi_awvalid : in  std_logic;
    s_axi_awready : out std_logic;
    s_axi_wdata   : in  std_logic_vector({{REGISTER_WIDTH-1}} downto 0);
    s_axi_wstrb   : in  std_logic_vector({{REGISTER_BYTE_WIDTH-1}} downto 0);
    s_axi_wvalid  : in  std_logic;
    s_axi_wready  : out std_logic;
    s_axi_bresp   : out std_logic_vector(1 downto 0);
    s_axi_bvalid  : out std_logic;
    s_axi_bready  : in  std_logic;
    s_axi_araddr  : in  std_logic_vector({{AXI_ADDR_WIDTH-1}} downto 0);
    s_axi_arprot  : in  std_logic_vector(2 downto 0);
    s_axi_arvalid : in  std_logic;
    s_axi_arready : out std_logic;
    s_axi_rdata   : out std_logic_vector({{REGISTER_WIDTH-1}} downto 0);
    s_axi_rresp   : out std_logic_vector(1 downto 0);
    s_axi_rvalid  : out std_logic;
    s_axi_rready  : in  std_logic
  );
end entity;

architecture arch of {{MODULE_NAME}} is
  -- register array
  constant NUM_REGISTERS : natural := {{NUM_REGISTERS}};
  type reg_array_t is array(natural range <>) of std_logic_vector({{REGISTER_WIDTH-1}} downto 0);
  signal registers      : reg_array_t(0 to NUM_REGISTERS-1) := (others => (others => '0'));
  signal write_reg_addr : integer range 0 to NUM_REGISTERS-1;
  signal read_reg_addr  : integer range 0 to NUM_REGISTERS-1;

  -- internal AXI signals
  signal axi_awready : std_logic;
  signal axi_wready  : std_logic;
  signal axi_wdata   : std_logic_vector({{REGISTER_WIDTH-1}} downto 0);
  signal axi_wstrb   : std_logic_vector({{REGISTER_BYTE_WIDTH-1}} downto 0);
  signal axi_bvalid  : std_logic;
  signal axi_arready : std_logic;
  signal axi_rvalid  : std_logic;

begin

  -- wire ports to internal registers
  {%- for reg in registers|selectattr("mode", "equalto", "ctrl") %}
  {{reg.label.ljust(JUST_WIDTH)}} <= registers({{reg.addr}});
  {%- endfor %}

  {%- for reg in registers|selectattr("mode", "equalto", "trig") %}
  {{reg.label.ljust(JUST_WIDTH)}} <= registers({{reg.addr}});
  {%- endfor %}

  register_read: process (s_axi_aclk)
  begin
    if rising_edge(s_axi_aclk) then
      {%- for reg in registers|selectattr("mode", "equalto", "stat") %}
      registers({{reg.addr}}) <= {{reg.label}};
      {%- endfor %}
    end if;
  end process;

  -- connect internal AXI signals
  s_axi_awready <= axi_awready;
  s_axi_wready  <= axi_wready;
  s_axi_bvalid  <= axi_bvalid;
  s_axi_arready <= axi_arready;
  s_axi_rvalid  <= axi_rvalid;

  -- always respond with OK
  s_axi_bresp   <= "00";
  s_axi_rresp   <= "00";

  wready: process (s_axi_aclk)
  begin
    if rising_edge(s_axi_aclk) then
      if s_axi_aresetn = '0' then
        axi_awready <= '0';
        axi_wready  <= '0';
        axi_bvalid  <= '0';
      else
        if (axi_awready = '0' and axi_wready = '0' and s_axi_awvalid = '1' and s_axi_wvalid = '1') then
          axi_awready <= '1';
          axi_wready  <= '1';
        else
          axi_awready <= '0';
          axi_wready  <= '0';
        end if;

        if axi_wready = '1' then
          axi_bvalid <= '1';
        elsif axi_bvalid = '1' and s_axi_bready = '1' then
          axi_bvalid <= '0';
        end if;
      end if;
    end if;
  end process;

  axi_reg_write: process (s_axi_aclk)
  begin
    if rising_edge(s_axi_aclk) then
      -- decode register address
      write_reg_addr <= to_integer(unsigned(s_axi_awaddr(s_axi_awaddr'high downto {{LOG2_REGISTER_BYTE_WIDTH}})));

      -- register data and byte enables
      axi_wdata <= s_axi_wdata;
      axi_wstrb <= s_axi_wstrb;

      -- trig register
      {%- for reg in registers|selectattr("mode", "equalto", "trig") %}
      registers({{reg.addr}}) <= x"{{"{:08x}".format(reg.initval)}}"; -- {{reg.label}}
      {%- endfor %}

      if s_axi_aresetn = '0' then
        -- ctrl register
        {%- for reg in registers|selectattr("mode", "equalto", "ctrl") %}
        registers({{reg.addr}}) <= x"{{"{:08x}".format(reg.initval)}}"; -- {{reg.label}}
        {%- endfor %}
      else
        for byte in 0 to {{REGISTER_BYTE_WIDTH-1}} loop
          if axi_wstrb(byte) = '1' and axi_wready = '1' then
            {%- for reg in registers|selectattr("mode", "equalto", "ctrl") %}
            -- {{reg.label}}
            if write_reg_addr = {{reg.addr}} then
              registers({{reg.addr}})(byte*8+7 downto byte*8) <= axi_wdata(byte*8+7 downto byte*8);
            end if;
            {%- endfor %}

            {%- for reg in registers|selectattr("mode", "equalto", "trig") %}
            -- {{reg.label}}
            if write_reg_addr = {{reg.addr}} then
              registers({{reg.addr}})(byte*8+7 downto byte*8) <= axi_wdata(byte*8+7 downto byte*8);
            end if;
            {%- endfor %}
          end if;
        end loop;
      end if;
    end if;
  end process;

  axi_reg_read: process (s_axi_aclk)
  begin
    if rising_edge(s_axi_aclk) then
      if s_axi_aresetn = '0' then
        axi_arready   <= '0';
        axi_rvalid    <= '0';
        read_reg_addr <= 0;
        s_axi_rdata   <= (others => '0');
      else
        if (axi_arready = '0' and s_axi_arvalid = '1') then
          axi_arready   <= '1';
          read_reg_addr <= to_integer(unsigned(s_axi_araddr(s_axi_araddr'high downto {{LOG2_REGISTER_BYTE_WIDTH}})));
        else
          axi_arready   <= '0';
        end if;

        if axi_arready = '1' then
          axi_rvalid <= '1';
        elsif axi_rvalid = '1' and s_axi_rready = '1' then
          axi_rvalid <= '0';
        end if;

        s_axi_rdata <= registers(read_reg_addr);
      end if;
    end if;
  end process;
end architecture;

--  component {{MODULE_NAME}} is
--    port (
--      -- status ports
       {%- for reg in registers|selectattr("mode", "equalto", "stat") %}
--      {{reg.label.ljust(JUST_WIDTH)}} : in  std_logic_vector({{REGISTER_WIDTH-1}} downto 0);
       {%- endfor %}
--
--      -- control ports
       {%- for reg in registers|selectattr("mode", "equalto", "ctrl") %}
--      {{reg.label.ljust(JUST_WIDTH)}} : out std_logic_vector({{REGISTER_WIDTH-1}} downto 0);
       {%- endfor %}
--
--      -- trigger ports
       {%- for reg in registers|selectattr("mode", "equalto", "trig") %}
--      {{reg.label.ljust(JUST_WIDTH)}} : out std_logic_vector({{REGISTER_WIDTH-1}} downto 0);
       {%- endfor %}
--
--      -- AXI slave
--      s_axi_aclk    : in  std_logic;
--      s_axi_aresetn : in  std_logic;
--      s_axi_awaddr  : in  std_logic_vector({{AXI_ADDR_WIDTH-1}} downto 0);
--      s_axi_awprot  : in  std_logic_vector(2 downto 0);
--      s_axi_awvalid : in  std_logic;
--      s_axi_awready : out std_logic;
--      s_axi_wdata   : in  std_logic_vector({{REGISTER_WIDTH-1}} downto 0);
--      s_axi_wstrb   : in  std_logic_vector({{REGISTER_BYTE_WIDTH-1}} downto 0);
--      s_axi_wvalid  : in  std_logic;
--      s_axi_wready  : out std_logic;
--      s_axi_bresp   : out std_logic_vector(1 downto 0);
--      s_axi_bvalid  : out std_logic;
--      s_axi_bready  : in  std_logic;
--      s_axi_araddr  : in  std_logic_vector({{AXI_ADDR_WIDTH-1}} downto 0);
--      s_axi_arprot  : in  std_logic_vector(2 downto 0);
--      s_axi_arvalid : in  std_logic;
--      s_axi_arready : out std_logic;
--      s_axi_rdata   : out std_logic_vector({{REGISTER_WIDTH-1}} downto 0);
--      s_axi_rresp   : out std_logic_vector(1 downto 0);
--      s_axi_rvalid  : out std_logic;
--      s_axi_rready  : in  std_logic
--    );
--  end component;