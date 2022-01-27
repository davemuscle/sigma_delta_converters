
src_list = sigma_delta_adc.sv
sim_list = $(src_list) sigma_delta_adc_tb.sv
ver_list = sigma_delta_adc_tb.cpp
sim_tb = sigma_delta_adc_tb

tb_dump_dir = ./tb_dumps

.PHONY: sim
sim: clean
	echo "Simulation Target"
	vlog $(sim_list)
	vsim -c -do "run -all" $(sim_tb)
	mkdir -p tb_dumps
	mv *adc_tb*.txt tb_dumps/.
	./plot.py

VBOSR = 25

.PHONY: freq
freq:
	echo "Verilator Target"
	export BOSR=$(VBOSR); \
	verilator --trace -Wall --cc --exe $(ver_list) $(src_list) -GBOSR=$(VBOSR) --build; \
	./obj_dir/Vsigma_delta_adc;

.PHONY: lint
lint:
	verilator -Wall --lint-only $(src_list)

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
