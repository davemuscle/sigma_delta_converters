#include "Vsigma_delta_adc.h"
#include <verilated.h>
#include <verilated_vcd_c.h>

class Harness {
public:
    Vsigma_delta_adc *dut = new Vsigma_delta_adc;
    VerilatedVcdC *m_trace = new VerilatedVcdC;
    int glb_cycles = 0;
    int events = 0;

    void trace(std::string cmd = "dump"){
        //open vcd file 
        if(!cmd.compare("start")){
            this->dut->trace(this->m_trace, 1);
            this->m_trace->open("dump.vcd");
        //close vcd file
        } else if(!cmd.compare("finish")){
            this->m_trace->close();
        //log sim event to file
        } else if(!cmd.compare("dump")){
            this->m_trace->dump(this->events);
            this->events++;
        }
    }

    void clock(void){
        this->dut->clk ^= 1;
        this->dut->eval();
        if(this->dut->clk == 1){
            this->glb_cycles++;
        }
    }

    void reset(){
        //temp
        if(this->dut->clk == 1){
            if(this->glb_cycles > 4 && this->glb_cycles < 11){
                this->dut->rst = 1;
            } else {
                this->dut->rst = 0;
            }
        }
    }
        
};

const int MAX_SIM_TIME = 50;

int main(int argc, char **argv, char **env){

    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);

    Harness *hns = new Harness;

    hns->trace("start");

    // tb
    
    while(hns->glb_cycles < MAX_SIM_TIME){

        hns->clock();
        hns->reset();
        hns->trace();

    } 
    
    hns->glb_cycles = 0;

    while(hns->glb_cycles < MAX_SIM_TIME){
        hns->clock();
        hns->reset();
        hns->trace();
    }


    hns->trace("finish");

}
