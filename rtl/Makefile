
src_list = sigma_delta_adc.sv
sim_list = $(src_list) adc_tb.sv
sim_tb = adc_tb

.PHONY: sim
sim:
	echo "Simulation Target"
	vlog $(sim_list)
	vsim -c -do "run -all" $(sim_tb)
	./plot.py

.PHONY: freq
freq:


.PHONY: lint
lint:
	verilator --lint-only $(src_list)

.PHONY: gui
gui:
	gtkwave -og dump.vcd & 

.PHONY: clean
clean:
	rm -rf work
	rm -rf *.vcd *.fst
	rm -rf transcript
	rm -rf tb_signals/*
