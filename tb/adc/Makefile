include ../Makefile

sim_list = ../../rtl/*.sv ./sigma_delta_adc_tb.sv
sim_tb = sigma_delta_adc_tb

tb_input=tb_input.txt
tb_output=tb_output.txt

sim_params  = OVERSAMPLE_RATE=256
sim_params += CIC_STAGES=2
sim_params += ADC_BITLEN=16
sim_params += USE_FIR_COMP=0
sim_params += FIR_COMP_ALPHA_8=2
sim_params += DUMP_VCD=1
sim_params += USE_DC=0
sim_params += BCLK=12288000
sim_params += NUM_CYCLES=4
sim_params += VCC=3.3
sim_params += FREQUENCY=880.0
sim_params += AMPLITUDE=1.60
sim_params += OFFSET=1.67
sim_params += INPUT_FILE="$(tb_input)"
sim_params += OUTPUT_FILE="$(tb_output)"
