##############################################################
# Generic Sim Using Modelsim
# from the command line, eg: make sim sim_list=xyz

sim_list = ../rtl/*.sv ./sigma_delta_adc_tb.sv
sim_tb = sigma_delta_adc_tb

tb_input=tb_input.txt
tb_output=tb_output.txt

sim_params  = OVERSAMPLE_RATE=256
sim_params += CIC_STAGES=2
sim_params += ADC_BITLEN=24
sim_params += USE_FIR_COMP=1
sim_params += FIR_COMP_ALPHA_8=2
sim_params += SIGNED_OUTPUT=0
sim_params += DC_BLOCK_SHIFT=10
sim_params += GLITCHLESS_STARTUP=10
sim_params += DUMP_VCD=1
sim_params += BCLK=12880000
sim_params += NUM_CYCLES=4
sim_params += VCC=3.3
sim_params += FREQUENCY=880.0
sim_params += AMPLITUDE=1.0
sim_params += OFFSET=1.25
sim_params += INPUT_FILE="$(tb_input)"
sim_params += OUTPUT_FILE="$(tb_output)"

.PHONY: sim
sim:
	vlog $(sim_list)
	vsim -c $(addprefix -g, $(sim_params)) -do "run -all" $(sim_tb)

.PHONY: plot
plot:
	./plot.py $(tb_input) $(tb_output)

.PHONY: gui
gui:
	gtkwave -og dump.vcd &

.PHONY: clean
clean:
	rm -rf work
	rm -rf *.vcd *.fst
	rm -rf transcript
	rm -rf $(tb_input) $(tb_output)
##############################################################
