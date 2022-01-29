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
        const char *env_OVERSAMPLE_RATE = std::getenv("OVERSAMPLE_RATE");
        const char *env_SCLK = std::getenv("SCLK");
        const char *env_CIC_STAGES = std::getenv("CIC_STAGES");

        this->vcc = std::stof(env_VCC);
        this->bosr = std::stol(env_OVERSAMPLE_RATE);
        this->sclk = std::stol(env_SCLK);
        this->stgs = std::stol(env_CIC_STAGES);

        printf("\nMaking sure environment variables get parsed correctly:\n");
        printf("  VCC=%f, OVERSAMPLE_RATE=%d, SCLK=%d, CIC_STAGES=%d\n", this->vcc, this->bosr, this->sclk, this->stgs);
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
void save_stimulus(const char *fp, float x, float y){
    std::ofstream file;
    file.open(fp, std::ios_base::app);
    file << x << "," << y << "\n";
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
void run_freqz(Harness *hns, int start_freq, int end_freq, int num_steps, int num_per, bool log, bool is_signed){
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

    //open files and write units
    std::ofstream file;
    const char * input_file  = "./tb_dumps/verilator_adc_tb_0_input.txt";
    const char * output_file = "./tb_dumps/verilator_adc_tb_1_output.txt";
    const char * gain_file   = "./tb_dumps/verilator_adc_tb_2_gain.txt";
    const char * phase_file  = "./tb_dumps/verilator_adc_tb_3_phase.txt";

    int input_idx = 0;
    int output_idx = 0;

    file.open(input_file, std::ios_base::app);
    file << "index,voltage(V)\n";
    file.close();

    file.open(output_file, std::ios_base::app);
    file << "index,voltage(V)\n";
    file.close();

    file.open(gain_file, std::ios_base::app);
    file << "frequency (Hz), Gain(dB)\n";
    file.close();

    //file.open(phase_file, std::ios_base::app);
    //file << "frequency (Hz), Phase(deg)\n";
    //file.close();

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
                        //choose between signed or unsigned output from the adc
                        float adc_result;
                        if(is_signed){
                            adc_result = hns->dut->adc_s_output;
                        }else{
                            adc_result = hns->dut->adc_u_output;
                        }
                        //convert to output voltage to match input
                        adc_result = hns->vcc * adc_result / pow(hns->bosr, hns->stgs);
                        //record the amplitude for the input and scaled output at this frequency
                        record_amplitude(hns->dut->adc_input, &in_amp);
                        record_amplitude(adc_result, &out_amp);
                        //write the current value to files for visual comparison
                        save_stimulus(input_file, input_idx++, hns->dut->adc_input);
                        save_stimulus(output_file, output_idx++, adc_result);
                    }
                    hns->trace();
                }
            }
            //update loading bar
            print_load_bar(i, num_steps, per, num_per);
        }
        //continually subtract perlen down from the phase offset to remove 2pi wraparound
        //the phase last-low-idx can be in any period
        float sclk_per_len = per_len / hns->bosr;
        while(out_amp.lli > 0 && out_amp.lli > sclk_per_len){
            out_amp.lli -= sclk_per_len;
        }
        while(in_amp.lli > 0 && in_amp.lli > sclk_per_len){
            in_amp.lli -= sclk_per_len;
        }
        //convert gain to db = 20 log10(gain)
        float gain = out_amp.res / in_amp.res;
        gain = 20.0f*log10(gain);
        //convert phase to degress, deg = diff * 360 / sclk_per_len
        float phase = out_amp.lli - in_amp.lli;
        phase = phase * 360.0f / sclk_per_len; 
        //write amplitude and phase to a file
        save_stimulus(gain_file, freq[i], gain);
        //save_stimulus(phase_file, freq[i], phase);
    }
    print_load_bar(num_steps, num_steps, 0, num_per);
    printf("\n");
}

int main(int argc, char **argv, char **env){

    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);

    Harness *hns = new Harness;

    hns->trace("start");

    int START_FREQ = std::stof(std::getenv("START_FREQ"));
    int END_FREQ   = std::stol(std::getenv("END_FREQ"));
    int NUM_FREQ   = std::stol(std::getenv("NUM_FREQ"));
    int NUM_PER    = std::stol(std::getenv("NUM_PER"));
    bool DLOG      = std::stol(std::getenv("LOG"));
    bool DSIGNED   = std::stol(std::getenv("SIGNED"));

    printf("Making sure env variables for main got parsed too:\n");
    printf("  ");
    printf("START_FREQ = %d, ", START_FREQ);
    printf("END_FREQ = %d, ", END_FREQ);
    printf("NUM_FREQ = %d, ", NUM_FREQ);
    printf("NUM_PER = %d, ", NUM_PER);
    printf("LOG=%d, ", DLOG);
    printf("SIGNED=%d\n", DSIGNED);
    printf("\n");

    run_freqz(hns, START_FREQ, END_FREQ, NUM_FREQ, NUM_PER, DLOG, DSIGNED);

    hns->trace("finish");

}
