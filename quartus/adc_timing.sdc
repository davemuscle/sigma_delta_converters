set_time_format -unit ns -decimal_places 3
create_clock -name {altera_reserved_tck} -period 100.000 -waveform { 0.000 50.000 } [get_ports {altera_reserved_tck}]
# Don't include this constraint on the DDR3 reference clock pin. The UniPHY handles that
create_clock -name {clk} -period 20.000 -waveform { 0.000 10.000 } [get_ports {clk}]
set_clock_groups -asynchronous -group [get_clocks {altera_reserved_tck}]
derive_pll_clocks
derive_clock_uncertainty
set_false_path -from [get_ports altera_reserved_tdi] -to *
set_false_path -from [get_ports altera_reserved_tms] -to *
set_false_path -from * -to [get_ports altera_reserved_tdo]

