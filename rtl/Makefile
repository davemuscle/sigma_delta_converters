
.PHONY: sim
sim: clean_plot
	echo "Simulation Target"
	vlog sigma_delta_adc.sv sigma_delta_adc_harness.sv sigma_delta_adc_tb.sv
	vsim -c -do "run -all" sigma_delta_adc_tb

# verilator frequency response sim parameters
G_VCC=2.5
G_BOSR=256
G_STGS=2
G_WDTH=24

D_SCLK=48000
D_START_FREQ=220
D_END_FREQ=20000
D_NUM_FREQ=40
D_NUM_PER=32
D_LOG=1

.PHONY: freq
freq: clean_plot
	echo "Verilator Target"
	rm -f ./obj_dir/Vsigma_delta_adc
	export VCC=$(G_VCC); export BOSR=$(G_BOSR); export STGS=$(G_STGS); \
	export SCLK=$(D_SCLK); export START_FREQ=$(D_START_FREQ); export END_FREQ=$(D_END_FREQ); \
	export NUM_FREQ=$(D_NUM_FREQ); export NUM_PER=$(D_NUM_PER); export LOG=$(D_LOG); \
	verilator --trace -Wall --cc --exe sigma_delta_adc_tb.cpp sigma_delta_adc.sv sigma_delta_adc_harness.sv --build \
	-GVCC=$(G_VCC) -GBOSR=$(G_BOSR) -GSTGS=$(G_STGS) -GWDTH=$(G_WDTH); \
	./obj_dir/Vsigma_delta_adc;

.PHONY: plot
plot:
	./plot.py

.PHONY: lint
lint:
	verilator -Wall --lint-only sigma_delta_adc.sv

.PHONY: gui
gui:
	gtkwave -og dump.vcd & 

.PHONY: clean_plot
clean_plot:
	rm -rf tb_dumps/*

.PHONY: clean
clean: clean_plot
	rm -rf obj_dir
	rm -rf work
	rm -rf *.vcd *.fst
	rm -rf transcript
