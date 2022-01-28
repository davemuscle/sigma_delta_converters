#include "Vsigma_delta_adc.h"

#include <verilated.h>
#include <verilated_vcd_c.h>

class Harness {
public:
    Vsigma_delta_adc *dut = new Vsigma_delta_adc;
    VerilatedVcdC *m_trace = new VerilatedVcdC;

    //harness parameters for data generation:
    float vcc;
    float scale;
    int bosr;
    int sclk;
    int bclk;
    uint64_t glb_cycles = 0;
    uint64_t events = 0;

    //class init
    Harness(void){
        const char *env_VCC  = std::getenv("VCC");
        const char *env_BOSR = std::getenv("BOSR");
        const char *env_SCLK = std::getenv("SCLK");

        this->vcc = std::stof(env_VCC);
        this->bosr = std::stol(env_BOSR);
        this->sclk = std::stol(env_SCLK);

        printf("\nMaking sure environment variables get parsed correctly:\n");
        printf("  VCC=%f, BOSR=%d, SCLK=%d\n", this->vcc, this->bosr, this->sclk);
        printf("\n");

        this->bclk = this->bosr * this->sclk;
        this->scale = 0.99;
    }

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

    //generate sine input to dut as a pulse density modulated signal
    void generate_input(int freq){
        float analog = cos((2*M_PI*freq*this->glb_cycles)/this->bclk);
        analog = (this->vcc/2) + ((this->scale * this->vcc/2) * analog);
        this->dut->adc_input = analog;
    }


};

const int MAX_SIM_TIME = 50;


//#define BOSR 256
#define TEST 100

int main(int argc, char **argv, char **env){


    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);

    Harness *hns = new Harness;

    hns->trace("start");

    // tb
    
    hns->glb_cycles = 0;

    while(hns->glb_cycles < MAX_SIM_TIME){

        hns->clock();
        hns->reset(5, 10);
        hns->generate_input(440);
        hns->trace();

    } 
    
    hns->glb_cycles = 0;
    hns->trace("finish");

}
