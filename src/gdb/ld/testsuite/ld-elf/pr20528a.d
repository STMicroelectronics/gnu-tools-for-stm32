#source: pr20528a.s
#source: pr20528b.s
#ld: -r
#readelf: -S --wide
#xfail: d30v-*-* dlx-*-* fr30-*-* frv-*-elf ft32-*-*
#xfail: iq*-*-* mn10200-*-* moxie-*-* msp*-*-* mt-*-* pj*-*-* xgate-*-*

#...
[ 	]*\[.*\][ 	]+\.text.startup[ 	]+PROGBITS.*[ 	]+AX[   ]+.*
#...
[ 	]*\[.*\][ 	]+\.text.startup[ 	]+PROGBITS.*[ 	]+AXE[   ]+.*
#pass
