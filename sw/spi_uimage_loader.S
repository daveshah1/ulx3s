// Dummy program

#define GPIO 0x91000000

boot_init:
	l.movhi r0, 0
	l.movhi r2, 0
	l.movhi r5, 0

	l.movhi r1,     hi(GPIO)
	l.ori   r1, r1, lo(GPIO)
	l.movhi r3, 0
loop:
	l.sb 0(r1), r3
	l.addi r3, r3, 1
	l.lwz r4, 20(r5)
	l.sw 20(r5), r3
	l.j loop
	l.nop
