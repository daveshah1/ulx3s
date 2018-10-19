../prjtrellis/tools/bit_to_svf.py build/ulx3s_0/bld-trellis/ulx3s_0.bit ulx3s_0.svf
/home/david/ulx3s-bin/usb-jtag/linux/openocd -f ../prjtrellis/misc/openocd/ulx3s.cfg -c "transport select jtag; init; svf ulx3s_0.svf; exit"
