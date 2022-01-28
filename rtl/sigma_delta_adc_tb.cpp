#include "Vsigma_delta_adc.h"

#include <verilated.h>
#include <verilated_vcd_c.h>

#include <iostream>
#include <fstream>

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

    //generate sine input to dut
    void generate_input(int freq){
        //cosine wave
        float analog = cos((2*M_PI*freq*this->glb_cycles)/this->bclk);
        //add dc offset and scale to voltage
        analog = (this->vcc/2) + ((this->scale * this->vcc/2) * analog);
        this->dut->adc_input = analog;
    }

    //open file pointer and write into it, data is saved as a float
    void save_stimulus(const char *fp, float val){
        std::ofstream file;
        file.open(fp, std::ios_base::app);
        file << val << "\n";
        file.close();
    }

};

const int MAX_SIM_TIME = 50;

int main(int argc, char **argv, char **env){


    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);

    Harness *hns = new Harness;

    hns->trace("start");

    // put full scale to let integrators build up
    hns->glb_cycles = 0;
    hns->generate_input(1);
    for(uint16_t i = 0; i < 65535; i++){
        hns->clock();
    }
    hns->glb_cycles = 0;

    // tb
    int freq [4] = {440, 880, 1000, 2000}; 
    for(uint8_t i = 0; i < 4; i++){
        int per = hns->bosr * 1 * hns->sclk / freq[i];
        printf("per: %d\n", per);
        hns->glb_cycles = 0;
        while(hns->glb_cycles < per){
            hns->clock();
            hns->generate_input(freq[i]);
            hns->save_stimulus("./tb_dumps/verilator_adc_tb_input.txt", hns->dut->adc_input);
            if(hns->dut->adc_valid){
                hns->save_stimulus("./tb_dumps/verilator_adc_tb_output.txt", (float)hns->dut->adc_output);
            }
            hns->trace();

        } 
    }
    
    hns->trace("finish");

}
