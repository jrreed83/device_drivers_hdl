
EXE = dac.exe
VCD = dac_ad5541a.vcd

all:
	iverilog -g2012 dac_ad5541a_tb.sv data_generator.sv dac_ad5541a.sv -o ${EXE}

run:
	vvp ${EXE}

view:
	gtkwave ${VCD} 

clean:
	rm -rf ${EXE} ${VCD}

