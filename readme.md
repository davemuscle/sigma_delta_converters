# Sigma Delta ADCs and DACs for FPGA
Recently I stumbled across a research paper describing how an Analog-to-Digital (ADC) 
converter can be implemented almost entirely within an FPGA. The paper illustrated how a 
differential input LVDS pin on the FPGA can be used as part of a Sigma Delta Modulator, which in
part with a few resistors and capacitors enables the analog conversion. 

The idea became more interesting the more I thought about it, 
so here we are with this short project: creating unsigned ADCs and DACs in an FPGA with only a few
resistors and capacitors. 

Potential applications for this design include:
- Projects where your FPGA development board did not have any analog pins broken out but your design requires some
  analog features
- Projects where you don't like using IP and prefer to write things yourself

## Results

The results of the project were successful, resulting in low resource ADC and DAC designs that could
cleanly digitize sound.

System/FPGA Parameters:
- CLK             = 6.25 MHz
- OVERSAMPLE_RATE = 128
- CIC_STAGES      = 2
- ADC_BITLEN      = 14
- USE_FIR_COMP    = 0
- DAC_BITLEN      = 14
- VCC             = 3.3V
- Samplerate      = 48.8 kHz

Measurement Parameters:
- FFT size    = 1024
- Buffer size = 2048
- Bode fstart = 220 Hz
- Bode fend   = 97.6 kHz
- Bode fsteps = 40 

```
Quartus Fitter Report:
+-----------------+-------------+---------------------------+--------------+
; Entity Name     ; Logic Cells ; Dedicated Logic Registers ; Memory Bits  ;
+-------------------------------+---------------------------+--------------+
; sigma_delta_adc ; 126 (26)    ; 121 (25)                  ; 0            ;
; sigma_delta_dac ; 16 (16)     ; 16 (16)                   ; 0            ;
+-----------------+-------------+---------------------------+--------------+
```

Below are measurements gathered using my hardware test script that's described near the end of
the page. The SNR and THDN were calculated spectrally by comparing the value of the fundamental
frequency against the RMS of the other FFT bins. I chose to input a 429 Hz wave so that fundamental
doesn't spread between bins, as this effects my noise comparison methods without some arbitrary fudging.


### ADC Standard Measurement 
```
Input: 429 Hz Sinewave, 1.0V Amplitude, 1.67V Offset
-------------------- Test Results --------------------
* Freq: 429.000
*  Amp:     4757 = 0.958 V
*   DC:     8339 = 1.680 V
*  RMS:     8969 = 1.807 V
*  Max:    13084 = 2.635 V
*  Min:     3569 = 0.719 V
*  SNR: 63.860299 (dB)
* THDN: 0.022596
```
![Image](/hw/measurements/adc_429hz_sine.png)

### ADC Ambient, Clean, and Noisy Measurements
```
Input: None
-------------------- Ambient Results --------------------
*  Amp(V): 0.0317230224609375
*   DC(V): 1.668933302164079
*  RMS(V): 1.668953692975981
*  Max(V): 1.701361083984375
*  Min(V): 1.6379150390625
*  SNR (dB): 8.703418613807651
*  THDN  : 17.123490615657396

Input: 429 Hz Sinewave, 1.0V Amplitude, 1.67V Offset
-------------------- Clean Results --------------------
*  Amp(V): 0.964984130859375
*   DC(V): 1.6809912174940134
*  RMS(V): 1.807885181178018
*  Max(V): 2.63492431640625
*  Min(V): 0.7049560546875
*  SNR (dB): 64.91418976648241
*  THDN  : 0.019623815470622377

Input: 429 Hz Sinewave, 1.0V Amplitude, 1.67V Offset, 100 mV white noise
-------------------- Noisy Results --------------------
*  Amp(V): 0.9859313964843749
*   DC(V): 1.6738809764385225
*  RMS(V): 1.8009232982815166
*  Max(V): 2.6619140624999997
*  Min(V): 0.69005126953125
*  SNR (dB): 48.5305044966696
*  THDN  : 0.02421072339512197

```
![Image](/hw/measurements/adc_429hz_noise.png)

### ADC Bode Plot Measurement

![Image](/hw/measurements/adc_bode_sweep.png)

## Usage
### Add the code to your build script
Include all of the SystemVerilog files under the 'rtl' directory:
```
glob <path to repo>/rtl/*.sv
```
### Instantiate the ADC
```
    // instantiate adc
    sigma_delta_adc #(
        .OVERSAMPLE_RATE (),
        .CIC_STAGES      (),
        .ADC_BITLEN      (),
        .USE_FIR_COMP    (),
        .FIR_COMP_ALPHA_8()
    ) adc (
        .clk          (),
        .rst          (),
        .adc_lvds_pin (),
        .adc_fb_pin   (),
        .adc_output   (),
        .adc_valid    ()
    );
```
- **OVERSAMPLE_RATE** (integer, required)
    - Desired oversampling ratio used on the incoming analog signal. A higher value
      will decrease the noise floor at the cost of more FPGA LUTs.
    - The value here sets the output sampling rate. Eg: For clk = 50 MHz, an OSR of 1024
      produces a signal sampled at 48.8 KHz.
    - Only powers-of-2 were tested.
- **CIC_STAGES** (integer, required)
    - Number of integrator and comb stages to instantiate in the decimating CIC filter. A higher
      value produces a sharper frequency response in the transition region at the cost of FPGA
      LUTs.
- **ADC_BITLEN** (integer, required)
    - Number of bits for the output signal. Recommended value is: *CIC_STAGES\*$clog2(OVERSAMPLE_RATE)*
- **USE_FIR_COMP** (bit, optional)
    - Enable the compensation FIR filter on the output path for possibly a better balanced
      frequency response on the CIC filter.
- **FIR_COMP_ALPHA_8** (integer, optional)
    - Value between 0 and 8 to select the tap value for the compensation filter. 
    - 0 -> alpha = 0
    - 1 -> alpha = 1/8 = 0.125,
    - 2 -> alpha = 2/8 = 0.250, etc...

### Instantiate the DAC
```
    // instantiate dac
    sigma_delta_dac #(
        .DAC_BITLEN()
    ) dac (
        .clk       (),
        .rst       (),
        .dac_input (),
        .dac_pin   ()
    );
```
- **DAC_BITLEN** (integer, required)
    - Number of bits for the input signal.

### Setup Hardware
```
FPGA [ADC LVDS+] <--- R1 [10K] <--- Analog Input

FPGA [ADC LVDS-] <---------------\
FPGA [ADC FDBK ] ---> R2 [10K] --|-- C1 [1nF] -- GND

FPGA [DAC PIN  ] ---> R3 [10K] --|-- C2 [1nF] -- GND
                                 \----> Analog  Output

R1 is optional, but should match R2. It gave me better noise immunity on that pin.
R2 and C1 should form a cutoff near the the sampling rate nyquist frequency.
Same with R3 and C2.
```

# Demonstration

# Implementation

## Sigma Delta Modulator
## ADC
## DAC
## Hardware Testing
## References

