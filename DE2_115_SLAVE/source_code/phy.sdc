create_clock -period 20 [get_ports CLOCK_50]
create_clock -period 40 [get_ports ENET0_RX_CLK]
create_clock -period 40 [get_ports ENET1_RX_CLK]
derive_pll_clocks
derive_clock_uncertainty
