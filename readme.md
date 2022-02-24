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
cleanly process sound.

Here is my implemented ADC digitizing a 500 Hz 1.0V sinewave, passing it through a frequency shifting effect, then
back out the DAC. 

![Gif](/doc/shifter.gif)

System/FPGA Parameters:
- CLK             = 6.25 MHz
- OVERSAMPLE_RATE = 128
- CIC_STAGES      = 2
- ADC_BITLEN      = 14
- USE_FIR_COMP    = 0
- DAC_BITLEN      = 14

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

Measurement Parameters:
- VCC             = 3.3V
- Samplerate      = 48.8 kHz
- FFT size    = 1024
- Buffer size = 2048
- Bode fstart = 220 Hz
- Bode fend   = 2\*nyquist
- Bode fsteps = 40 

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
![Image](/doc/measurements/adc_429hz_sine.png)

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
![Image](/doc/measurements/adc_429hz_noise.png)

### ADC Bode Plot Measurement
```
Input: Variable frequency sinewave, 1.0V Amplitude, 1.67V Offset
```
![Image](/doc/measurements/adc_bode_sweep.png)

### DAC SineLUT Measurement
```
Input: 429 Hz Sinewave from ROM, Fullscale 14-bit unsigned
-------------------- Test Result --------------------
*  Amp: 1.638 V
*   DC: 1.558 V
*  RMS: 1.929 V
*  Max: 3.210 V
*  Min: -0.065 V
*  SNR: 38.490428 (dB)
* THDN: 0.141774
```
![Image](/doc/measurements/dac_429hz_lut.png)

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

### Setup the Analog Hardware
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

### Simulate (Modelsim)
```
cd tb/adc 
make clean sim plot

cd tb/dac
make clean sim plot
```

### Build (Quartus)
```
cd quartus
make
```

### Hardware Test
```
// requirements:
//     https://github.com/davemuscle/fpga_tooling
//     https://digilent.com/reference/test-and-measurement/analog-discovery-2/start

cd quartus; make prog 
cd hw
./hw.py -h
```

## Demonstration

For demonstrating sound in / sound out, I decided to port a portion of a school project from my
Junior year of college: a crude octave up / down pitch shifter. I added the effect into the same
hardware test design and made it controllable with a few tactile switches. 

On the analog side, an AUX cable was hooked up from the breadboard to the function generator and a
class-AB amplifier was added to the DAC for driving an 8ohm speaker. Finally, a .wav file of some
dialogue was played, and the effect was successfully tested.

![Image](/doc/amp.png)

I was pretty happy with my result, and surprised that I had a decent demonstration of digitizing
sound with only three resistors and two capacitors.

CTRL+click the video thumbnails to open in a new tab

| Youtube Videos |
| :--: |
| *Sigma-Delta A/D Converters in FPGA* |
| [![Image](/doc/vid01_tb.png)](https://youtu.be/dKhM7zcvpbM) |

## Implementation

Below are my notes and ramblings about how the design was implemented.

### Sigma Delta Modulator

The Sigma Delta Modulator is the core of realizing digital ADCs and DACs. Input data is driven into
the modulator and has the feedback path immediately subtracted from it. It’s then integrated into an
accumulator and passed into a comparator, with the output creating a train of pulses. The data has
now been modulated such that the number of high pulses will be proportional to the input value,
which can then be filtered.

![Image](/doc/modulator.png)

### ADC

The Sigma Delta ADC is composed of only a few subblocks: a CIC filter and an optional FIR
compensator. CIC (Cascaded Integrator Comb) filters are efficient implementations of a moving
average filter. They have a frequency response similar to a low-pass filter. Both the integrator and
the comb stages can be repeated (cascaded) multiple times to achieve even better results. 

The main benefit of a CIC filter is its use in multirate systems as you can achieve large
downsampling ratios with just adders and subtractors. 



![Image](/doc/adc.png)

The FIR compensator is an optional parameterized step in the ADC design to balance the roll-off
portion of the CIC filter. For my implementation I decided to reduce the available taps to only
fractions of 8, then implement the multiplies as shifts and adds. I wanted a multiplier-less final
design for the ADC.

The typical and best way to use the CIC decimator would be to only decimate a factor one less than
your desired rate, then use a separate FIR filter that decimates by two. For example, to get 
a 48.8 KHz signal from a 50 MHz clock source, downsample by 512 (CIC) then by 2 (FIR). As can be seen below, 
the CIC filter starts to roll-off at Fs/4. By limiting the decimation rate then adding the extra FIR
stage, we can ultimately achieve a flatter, cleaner passband.

![Image](/doc/filter_compare.png)

### DAC

The DAC design is much simpler than the ADC. For this project I decided to implement just a classic
first order PWM DAC. It consists of an accumulator padded with an extra overflow bit. The extra bit
is used as the output of the DAC that gets filtered on the analog side.

### Hardware Testing

To verify my ADC and DAC worked outside of simulation, I used my digital oscilloscope/function
generator from Digilent. They provide a Python API for interfacing with the tool that I wrapped in
my own class to make using it easier.

I added a small design to the FPGA build for sending data over UART. When the FPGA receives an ‘s’
or ‘S’ character from the serial port, it samples data from the ADC until a buffer is filled. The
buffer is then converted to ASCII text and sent back over the serial port for the Python script to
read into a list for processing and plotting.

![Image](/doc/setup.png)

My hardware test script has a few modes:

- sine:
    - setup the function generator to a desired voltage / amplitude / frequency
    - record samples, then plot digital data and perform an FFT
    - measure SNR + THDN
- measure
    - record ambient data, record clean sinewave data, record noisy data
    - perform FFT and compare results
- bode
    - sweep frequency and generate a logarithmic bode plot
- read
    - read data from the oscilloscope and perform FFT analysis for plotting


### References
1. [New Mexico Tech, Taking Advantage of LVDS Input Buffers To Implement Sigma-Delta A/D Converters in FPGAs](http://www.ee.nmt.edu/~erives/531_14/Sigma-Delta.pdf)
2. [Analog Devices, Sigma-Delta ADCs and DACs](https://www.analog.com/media/en/technical-documentation/application-notes/292524291525717245054923680458171AN283.pdf)
3. [Wikipedia, Delta-Sigma Modulation](https://en.wikipedia.org/wiki/Delta-sigma_modulation)
4. [Maxim Integrated Tutorial: Sigma-Delta ADCs](https://www.maximintegrated.com/en/design/technical-documents/tutorials/1/1870.html)
5. [Tom Verbeure, Moving Average and CIC Filters](https://tomverbeure.github.io/2020/09/30/Moving-Average-and-CIC-Filters.html)
6. [Rick Lyons, A Beginner's Guide to Cascaded Integrator-Comb (CIC) Filters](https://www.dsprelated.com/showarticle/1337.php)
7. [Embedded, DSP Tricks: DC Removal](https://www.embedded.com/dsp-tricks-dc-removal/)
8. [Dan Boschen, FIR Compensator Design](https://dsp.stackexchange.com/a/31596)
