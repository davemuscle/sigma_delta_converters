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
    int stgs;
    uint64_t glb_cycles = 0;
    uint64_t events = 0;

    //class init
    Harness(void){
        const char *env_VCC  = std::getenv("VCC");
        const char *env_BOSR = std::getenv("BOSR");
        const char *env_SCLK = std::getenv("SCLK");
        const char *env_STGS = std::getenv("STGS");

        this->vcc = std::stof(env_VCC);
        this->bosr = std::stol(env_BOSR);
        this->sclk = std::stol(env_SCLK);
        this->stgs = std::stol(env_STGS);

        printf("\nMaking sure environment variables get parsed correctly:\n");
        printf("  VCC=%f, BOSR=%d, SCLK=%d, STGS=%d\n", this->vcc, this->bosr, this->sclk, this->stgs);
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

    int rising_edge(void){
        return this->dut->clk;
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

};

//open file pointer and write into it, data is saved as a float
void save_stimulus(const char *fp, float val){
    std::ofstream file;
    file.open(fp, std::ios_base::app);
    file << val << "\n";
    file.close();
}

struct amp_data {
    float low;
    float high;
    float res;
    float d1;
    float d2;
    float d3;
    float idx;
    float lli;
};

void reset_amplitude(struct amp_data *amp_stru){
    amp_stru->idx = 0;
    amp_stru->lli = 0;
    amp_stru->low = 0x7FFFFFFF;
    amp_stru->high = 0;
    amp_stru->res = 0;
}

void record_amplitude(float sample, struct amp_data *amp_stru){
    //update low value
    if(sample < amp_stru->low){
        amp_stru->low = sample;
        amp_stru->lli = amp_stru->idx;
    }
    //update high value
    if(sample > amp_stru->high){
        amp_stru->high = sample;
    }
    //record result
    amp_stru->res = amp_stru->high - amp_stru->low;
    //idx for phase calculation
    amp_stru->idx++;
}

// print fun loading screen
void print_load_bar(int freq_num, int freq_total, int per_num, int per_total){
    float load_percent = 100*((float)((freq_num*per_total)+(per_num)) / (float)(freq_total*per_total));
    printf("\rLOADING: [%d%%]", (int)load_percent);
    fflush(stdout);
}

//sweep frequency and generate amplitude/phase plot for freq response
void run_freqz(Harness *hns, int start_freq, int end_freq, int num_steps, int num_per, bool log){
    int freq[num_steps];
    freq[0] = start_freq;
    freq[num_steps-1] = end_freq;
    //arithmetic: next_freq = start_freq + step
    int arithmetic_step = (end_freq - start_freq) / num_steps;
    //geogrmetic: next_freq = start_freq * step = start_freq * ( k ^ (x / num_steps) )
    //  k = end_freq / start_freq
    //  x = 1 for just calculating the next frequency
    //used piano key spacing as a reference
    float geometric_step = pow(((float)end_freq / (float)start_freq), 1.0/(float)num_steps);
    for(int i = 1; i < num_steps-1; i++){
        if(log){
            freq[i] = freq[i-1] * geometric_step;
        } else {
            freq[i] = freq[i-1] + arithmetic_step;
        }
    }

    //printf("geo step: %f\n", geometric_step);
    //printf("arith step: %d\n", arithmetic_step);
    //for(int i = 0; i < num_steps; i++){
    //    printf("freq[%d]: %d\n", i, freq[i]);
    //}

    // put dc on to let the integrators build up the output before starting
    hns->glb_cycles = 0;
    hns->generate_input(1);
    for(uint16_t i = 0; i < 32768; i++){
        hns->clock();
    }
    hns->glb_cycles = 0;

    amp_data out_amp;
    amp_data in_amp;

    //loop through frequencies to plot
    for(int i = 0; i < num_steps; i++){
        //calculate how many bclk samples are needed for 1 period
        int per_len = hns->bosr * hns->sclk / freq[i];
        hns->glb_cycles = 0;
        //clear the amplitude structs
        reset_amplitude(&in_amp);
        reset_amplitude(&out_amp);
        //loop through how many periods to plot for each frequency
        for(int per = 0; per < num_per; per++){
            //loading bar, will kill other prints probably
            print_load_bar(i, num_steps, per, num_per);
            //loop through output samples for 1 period
            for(int tick = 0; tick < per_len; tick++){
                hns->clock();
                if(hns->rising_edge()){
                    //calculate next analog input
                    hns->generate_input(freq[i]);
                    //when output is ready
                    if(hns->dut->adc_valid){
                        //convert to output voltage to match input
                        float adc_result = hns->vcc * hns->dut->adc_output / pow(hns->bosr, hns->stgs);
                        //record the amplitude for the input and scaled output at this frequency
                        record_amplitude(hns->dut->adc_input, &in_amp);
                        record_amplitude(adc_result, &out_amp);
                        //write the current value to files for visual comparison
                        save_stimulus("./tb_dumps/verilator_adc_tb_input.txt", hns->dut->adc_input);
                        save_stimulus("./tb_dumps/verilator_adc_tb_output.txt",adc_result);
                    }
                    hns->trace();
                }
            }
            //update loading bar
            print_load_bar(i, num_steps, per, num_per);
        }
        //write amplitude and phase to a file
        save_stimulus("./tb_dumps/verilator_adc_tb_z_amp.txt", out_amp.res/in_amp.res);
        save_stimulus("./tb_dumps/verilator_adc_tb_z_pha.txt", out_amp.lli - in_amp.lli);
    }
    print_load_bar(num_steps, num_steps, 0, num_per);
    printf("\n");
}

int main(int argc, char **argv, char **env){

    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);

    Harness *hns = new Harness;

    hns->trace("start");

    run_freqz(hns, 220, 20000, 40, 32, true);

    hns->trace("finish");

}
