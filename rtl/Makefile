
.PHONY: sim
sim: clean
	echo "Simulation Target"
	vlog sigma_delta_adc.sv sigma_delta_adc_harness.sv sigma_delta_adc_tb.sv
	vsim -c -do "run -all" sigma_delta_adc_tb
	mkdir -p tb_dumps
	mv *adc_tb*.txt tb_dumps/.
	./plot.py

G_VCC=2.5
G_BOSR=256
G_STGS=2
G_WDTH=24
D_SCLK=44800

.PHONY: freq
freq:
	echo "Verilator Target"
	# BOSR and SCLK are needed to calculate BCLK
	export VCC=$(G_VCC); export BOSR=$(G_BOSR);  export SCLK=$(D_SCLK); \
	verilator --trace -Wall --cc --exe sigma_delta_adc_tb.cpp sigma_delta_adc.sv sigma_delta_adc_harness.sv --build \
	-GVCC=$(G_VCC) \
	-GBOSR=$(G_BOSR) \
	-GSTGS=$(G_STGS) \
	-GWDTH=$(G_WDTH); \
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
