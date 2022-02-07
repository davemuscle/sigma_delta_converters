##############################################################
# Generic Sim Using Modelsim
# from the command line, eg: make sim sim_list=xyz

sim_list = ../rtl/sigma_delta_adc.sv ./sigma_delta_adc_tb.sv
sim_tb = sigma_delta_adc_tb
sim_params  = OVERSAMPLE_RATE=256
sim_params += CIC_STAGES=2
sim_params += ADC_BITLEN=24
sim_params += SIGNED_OUTPUT=1
sim_params += DC_BLOCK_SHIFT=10
sim_params += DUMP_VCD=1
sim_params += BCLK=12880000
sim_params += NUM_CYCLES=2
sim_params += VCC=2.5
sim_params += FREQUENCY=440.0
sim_params += AMPLITUDE=1.0
sim_params += OFFSET=1.25
sim_params += INPUT_FILE="test_input.txt"
sim_params += OUTPUT_FILE="test_output.txt"

.PHONY: sim
sim:
	vlog $(sim_list)
	vsim -c $(addprefix -g, $(sim_params)) -do "run -all" $(sim_tb)

.PHONY: gui
gui:
	gtkwave -og dump.vcd &

.PHONY: clean
clean:
	rm -rf work
	rm -rf *.vcd *.fst
	rm -rf transcript
##############################################################
