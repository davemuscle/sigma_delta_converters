##############################################################
# Generic Sim Using Modelsim
# from the command line, eg: make sim sim_list=xyz
.PHONY: sim
sim:
	vlog $(sim_list)
	vsim -c $(addprefix -g, $(sim_params)) -do "run -all" $(sim_tb)

.PHONY: plot
plot:
	../plot.py $(tb_input) $(tb_output)

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
