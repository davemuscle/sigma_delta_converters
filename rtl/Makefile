
.PHONY: sim
sim: clean
	echo "Simulation Target"
	vlog sigma_delta_adc.sv sigma_delta_adc_harness.sv sigma_delta_adc_tb.sv
	vsim -c -do "run -all" sigma_delta_adc_tb
	mkdir -p tb_dumps
	mv *adc_tb*.txt tb_dumps/.
	./plot.py

VBOSR=25

.PHONY: freq
freq:
	echo "Verilator Target"
	export BOSR=$(VBOSR); \
	verilator --trace -Wall --cc --exe sigma_delta_adc_tb.cpp sigma_delta_adc.sv sigma_delta_adc_harness.sv -GBOSR=$(VBOSR) --build; \
	./obj_dir/Vsigma_delta_adc;

.PHONY: lint
lint:
	verilator -Wall --lint-only sigma_delta_adc.sv

.PHONY: gui
gui:
	gtkwave -og dump.vcd & 

.PHONY: clean
clean:
	rm -rf obj_dir
	rm -rf work
	rm -rf *.vcd *.fst
	rm -rf transcript
	rm -rf tb_dumps
