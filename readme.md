# Sigma Delta ADCs and DACs for FPGA
A little while ago I stumbled across a research paper describing how an Analog-to-Digital (ADC) 
converter can be implemented almost entirely within an FPGA. The paper illustrated how a 
differential input LVDS pin on the FPGA can be used as part of a Sigma Delta Modulator, which 
enables the analog conversion. This idea became more interesting the more I thought about it, 
so here we are with this short project: creating unsigned ADCs and DACs almost entirely in an FPGA. 

The overall application-use for this project is definitely limited. But, it could be helpful if:
- Your FPGA development board did not have any analog pins broken out but your design requires some
  analog features
- You don't like using IP and prefer to write things yourself

## Design
### Usage
#### Add code to your build script
Include all of the SystemVerilog files under the 'rtl' directory:
```
glob ./rtl/*.sv
```
#### Instantiate the ADC
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
- OVERSAMPLE\_RATE (integer, required)
    - Desired oversampling ratio used on the incoming analog signal. A higher value
      will decrease the noise floor at the cost of more FPGA LUTs.
    - The value here sets the output sampling rate. Eg: For clk = 50 MHz, an OSR of 1024
      produces a signal sampled at 48.8 KHz.
    - Only powers-of-2 were tested.
- CIC\_STAGES (integer, required)
    - Number of integrator and comb stages to instantiate in the decimating CIC filter. A higher
      value produces a sharper frequency response in the transition region at the cost of FPGA
      LUTs.
- ADC\_BITLEN (integer, required)
    - Number of bits for the output signal. Recommended value is: *CIC_STAGES\*$clog2(OVERSAMPLE_RATE)*
- USE\_FIR\_COMP (bit, optional)
    - Enable the compensation FIR filter on the output path for possibly a better balanced
      frequency response on the CIC filter.
- FIR\_COMP\_ALPHA\_8 (integer, optional)
    - Value between 0 and 8 to select the tap value for the compensation filter. 
    - 0 -> alpha = 0
    - 1 -> alpha = 0.125

#### Instantiate the DAC
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
- DAC\_BITLEN (integer, required)
    - Number of bits for the input signal.

# Results

# Demonstration

# Implementation

## Sigma Delta Modulator
## ADC
## DAC
## Hardware Testing
## References

