
src_list = sigma_delta_adc.sv
sim_list = $(src_list) adc_tb.sv
sim_tb = adc_tb

.PHONY: sim_and_plot
sim_and_plot: sim plot

.PHONY: sim
sim:
	echo "Simulation Target"
	vlog $(sim_list)
	vsim -c -do "run -all" $(sim_tb)

.PHONY: plot
plot:
	./plot.py

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
