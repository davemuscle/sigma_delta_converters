#include "Vsigma_delta_adc.h"

#include <verilated.h>
#include <verilated_vcd_c.h>

class Harness {
public:
    Vsigma_delta_adc *dut = new Vsigma_delta_adc;
    VerilatedVcdC *m_trace = new VerilatedVcdC;
    uint64_t glb_cycles = 0;
    uint64_t events = 0;

    //handler for waveform tracing
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

    //clk stim
    void clock(void){
        this->dut->clk ^= 1;
        this->dut->eval();
        if(this->dut->clk == 1){
            this->glb_cycles++;
        }
    }

    //reset dut
    void reset(int start, int end){
        if(this->dut->clk == 1){
            if(this->glb_cycles >= start && this->glb_cycles <= end){
                this->dut->rst = 1;
            } else {
                this->dut->rst = 0;
            }
        }
    }
    float vcc;
    float scale;
    //generate sine input to dut as a pulse density modulated signal
    int generate_input(int start, int freq){
        //float analog = cos((2*M_PI*freq*glb->cycles)/);
        return 0;
    }


};

const int MAX_SIM_TIME = 50;


//#define BOSR 256
#define TEST 100

int main(int argc, char **argv, char **env){


    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);

    Harness *hns = new Harness;
    //printf("CPP BOSR: %d\n", hns->dut->var_BOSR);
    //printf("CPP BOSR: %d\n", hns->dut->VCC);
    const char *p = std::getenv("BOSR");
    printf("\n\n\n");
    printf("got BOSR: %s\n", p);
    hns->trace("start");

    // tb
    
    hns->glb_cycles = 0;

    while(hns->glb_cycles < MAX_SIM_TIME){

        hns->clock();
        hns->reset(5, 10);
        hns->generate_input(0, 1);
        hns->trace();

    } 
    
    hns->glb_cycles = 0;

    while(hns->glb_cycles < MAX_SIM_TIME){
        hns->clock();
        hns->reset(5, 10);
        hns->trace();
    }


    hns->trace("finish");

}
